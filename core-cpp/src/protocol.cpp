#include "protocol.h"

#include "log.h"
#include "pystr.h"

#include <QSocketNotifier>
#include <QTimer>

#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <stdexcept>
#include <sys/socket.h>
#include <unistd.h>

namespace fart {

namespace {

// Ops that answer the core rather than ask it (fire-and-forget, no id): they skip the client's request queue, so
// a request of the view's that waits on a host call can be answered on the same connection (protocol.py ANSWERS).
const std::set<std::string, std::less<>> kAnswers = {"host.done"};

// Runs fn on the next turn of the event loop: a client is never released from inside its own callbacks.
void later(std::function<void()> fn) { QTimer::singleShot(0, std::move(fn)); }

void retire(std::unique_ptr<QSocketNotifier>& notifier) {
    if (!notifier) return;
    notifier->setEnabled(false);
    notifier.release()->deleteLater();
}

json::Value error_reply(const json::Value& id, const OpError& error) {
    return json::Object{{"id", id}, {"ok", false}, {"error", json::Object{{"code", error.code}, {"message", error.message}}}};
}

bool unhashable(const json::Value& v) { return v.is_array() || v.is_object(); }

}  // namespace

// --- Args ------------------------------------------------------------------------------------------------------

const json::Value& Args::operator[](std::string_view name) const {
    static const json::Value null;
    const json::Value* v = named_.find(name);
    return v ? *v : null;
}

bool Args::given(std::string_view name) const { return given_.contains(name); }

// --- Client ----------------------------------------------------------------------------------------------------

Client::Client(Server& server, int fd) : server_(server), fd_(fd) {
    ucred cred{};
    socklen_t len = sizeof cred;
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &len) == 0) {
        pid = cred.pid;
        uid = static_cast<int>(cred.uid);
    }
}

Client::~Client() { release_fd(); }

void Client::start() {
    std::weak_ptr<Client> weak = weak_from_this();
    read_ = std::make_unique<QSocketNotifier>(fd_, QSocketNotifier::Read);
    QObject::connect(read_.get(), &QSocketNotifier::activated, [weak] {
        if (auto self = weak.lock()) self->on_readable();
    });
    write_ = std::make_unique<QSocketNotifier>(fd_, QSocketNotifier::Write);
    write_->setEnabled(false);
    QObject::connect(write_.get(), &QSocketNotifier::activated, [weak] {
        if (auto self = weak.lock()) self->on_writable();
    });
}

void Client::on_readable() {
    if (!reading_) return;
    char buf[65536];
    size_t total = 0;
    bool eof = false;
    while (total < 4 * MAX_LINE) {  // then let other clients run; the notifier fires again
        ssize_t n = ::read(fd_, buf, sizeof buf);
        if (n > 0) {
            in_.append(buf, static_cast<size_t>(n));
            total += static_cast<size_t>(n);
        } else if (n == 0) {
            eof = true;
            break;
        } else if (errno == EINTR) {
            continue;
        } else {
            eof = errno != EAGAIN && errno != EWOULDBLOCK;  // a reset ends the connection like EOF
            break;
        }
    }
    size_t head = 0;
    while (reading_) {
        size_t pos = in_.find('\n', std::max(head, scanned_));
        if (pos == std::string::npos) {
            scanned_ = in_.size();
            if (in_.size() - head > MAX_LINE) {
                log::warning("fart.protocol", "closing a client that sent a line over " + std::to_string(MAX_LINE) + " bytes");
                stop_reading();
            }
            break;
        }
        if (pos - head > MAX_LINE) {
            log::warning("fart.protocol", "closing a client that sent a line over " + std::to_string(MAX_LINE) + " bytes");
            stop_reading();
            break;
        }
        std::string line = in_.substr(head, pos + 1 - head);
        head = pos + 1;
        if (Server::is_answer(line)) {
            server_.dispatch(shared_from_this(), line, [] {});
        } else {
            queue_.push_back(std::move(line));
        }
    }
    if (reading_) {
        in_.erase(0, head);
        scanned_ = scanned_ > head ? scanned_ - head : 0;
    }
    if (eof) stop_reading();  // an unfinished last frame is never answered
    pump();
}

void Client::stop_reading() {
    reading_ = false;
    in_.clear();
    scanned_ = 0;
    if (read_) read_->setEnabled(false);
}

void Client::pump() {
    if (pumping_) return;
    pumping_ = true;
    while (!busy_ && !queue_.empty()) {
        std::string line = std::move(queue_.front());
        queue_.pop_front();
        if (closed) continue;  // protocol.py _work: what's queued after a close is dropped
        busy_ = true;
        std::weak_ptr<Client> weak = weak_from_this();
        server_.dispatch(shared_from_this(), line, [weak] {
            if (auto self = weak.lock()) {
                self->busy_ = false;
                if (!self->pumping_) self->pump();  // an answer that came later, from an async handler
            }
        });
    }
    pumping_ = false;
    // As protocol.py's finally: once reading has ended and the requests already read are answered, let go.
    if (!reading_ && !busy_ && queue_.empty() && !finishing_) {
        finishing_ = true;
        std::weak_ptr<Client> weak = weak_from_this();
        later([weak] {
            if (auto self = weak.lock()) self->server_.finish(self);
        });
    }
}

void Client::send(const json::Value& message) {
    if (closed) return;
    std::string frame = json::encode_line(message);
    if (buffered() + frame.size() > MAX_BUFFER) {
        log::warning("fart.protocol", "dropping a " + (kind.empty() ? std::string("new") : kind) + " client over the output limit");
        abort();
        return;
    }
    if (fd_ < 0 || dead_) return;
    out_ += frame;
    flush();
}

void Client::flush() {
    while (fd_ >= 0 && !dead_ && out_pos_ < out_.size()) {
        ssize_t n = ::send(fd_, out_.data() + out_pos_, out_.size() - out_pos_, MSG_NOSIGNAL | MSG_DONTWAIT);
        if (n > 0) {
            out_pos_ += static_cast<size_t>(n);
        } else if (n < 0 && errno == EINTR) {
            continue;
        } else if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (write_) write_->setEnabled(true);
            return;
        } else {
            dead_ = true;  // the peer is gone: what's queued can never arrive; reading will see the end
        }
    }
    out_.clear();
    out_pos_ = 0;
    if (write_) write_->setEnabled(false);
    if (closing_) release_fd();
}

void Client::on_writable() { flush(); }

void Client::close() {
    if (closed && closing_) return;
    closed = true;
    closing_ = true;
    stop_reading();
    if (buffered() == 0 || dead_) release_fd();  // otherwise once the rest is written
}

void Client::abort() {
    closed = true;
    out_.clear();
    out_pos_ = 0;
    stop_reading();
    release_fd();
    pump();
}

void Client::release_fd() {
    retire(read_);
    retire(write_);
    if (fd_ >= 0) {
        ::close(fd_);
        fd_ = -1;
    }
}

// --- Server ----------------------------------------------------------------------------------------------------

Server::Server(const json::Value& table) {
    for (const json::Value& entry : table.find("ops")->as_array()) {
        Spec spec;
        spec.peer = entry.find("peer")->as_string();
        for (const json::Value& p : entry.find("params")->as_array()) {
            const json::Value* def = p.find("default");
            spec.params.emplace_back(p.find("name")->as_string(), def ? std::optional<json::Value>(*def) : std::nullopt);
        }
        if (const json::Value* varkw = entry.find("varkw"); varkw && varkw->is_string()) spec.varkw = varkw->as_string();
        ops_.emplace(entry.find("op")->as_string(), std::move(spec));
    }
    for (const json::Value& t : table.find("topics")->as_array()) {
        topic_order_.push_back(t.as_string());
        snapshots_.emplace(t.as_string(), [] { return json::Value(json::Object{}); });
        revs_.emplace(t.as_string(), 0);
    }
    op("subscribe", [this](Client& c, const Args& a) { return subscribe(c, a); });
    op("unsubscribe", [this](Client& c, const Args& a) { return unsubscribe(c, a); });
}

Server::~Server() {
    stop_listening();
    close_all();
}

void Server::op(std::string_view name, Handler handler) {
    op_async(name, [handler = std::move(handler)](const std::shared_ptr<Client>& client, const Args& args, Respond respond) {
        respond(Outcome{true, handler(*client, args), {}});
    });
}

void Server::op_async(std::string_view name, AsyncHandler handler) {
    auto it = ops_.find(name);
    if (it == ops_.end())  // a port registering an op the Python core doesn't have: the table is the contract
        throw std::logic_error("op " + std::string(name) + " is not in the op table (tools/cpp_op_table.py)");
    it->second.handler = std::move(handler);
}

bool Server::ported(std::string_view op) const {
    auto it = ops_.find(op);
    return it != ops_.end() && it->second.handler;
}

void Server::topic(std::string_view name, std::function<json::Value()> snapshot) {
    auto it = snapshots_.find(name);
    if (it == snapshots_.end()) throw std::logic_error("topic " + std::string(name) + " is not in the op table");
    it->second = std::move(snapshot);
}

void Server::publish(std::string_view name) {
    auto rev = revs_.find(name);
    if (rev == revs_.end()) throw std::logic_error("publish of unknown topic " + std::string(name));
    ++rev->second;
    std::vector<std::shared_ptr<Client>> listeners;
    for (const auto& c : clients_)
        if (c->topics.contains(name)) listeners.push_back(c);
    if (listeners.empty()) return;
    json::Value data = snapshots_.find(name)->second();
    json::Value event = json::Object{{"event", std::string(name)}, {"rev", rev->second}, {"data", std::move(data)}};
    for (const auto& c : listeners) c->send(event);
}

void Server::push(Client& client, std::string_view name, json::Value data) {
    client.send(json::Object{{"event", std::string(name)}, {"rev", 0}, {"data", std::move(data)}});
}

json::Value Server::subscribe(Client& client, const Args& args) {
    const json::Value& topics = args["topics"];
    std::string offered;
    for (const auto& t : topic_order_) offered += (offered.empty() ? "" : ", ") + t;
    if (!topics.is_array()) throw bad_args("topics must be a list from " + offered);
    for (const json::Value& t : topics.as_array()) {  // all(t in snapshots): stops at the first miss
        if (unhashable(t)) throw std::runtime_error("unhashable type in topics");  // Python's TypeError
        if (!t.is_string() || !snapshots_.contains(t.as_string())) throw bad_args("topics must be a list from " + offered);
    }
    json::Value snaps = json::Object{}, revs = json::Object{};
    for (const json::Value& t : topics.as_array()) {
        client.topics.insert(t.as_string());
        snaps.set(t.as_string(), snapshots_.find(t.as_string())->second());
        revs.set(t.as_string(), revs_.find(t.as_string())->second);
    }
    return json::Object{{"snapshots", std::move(snaps)}, {"revs", std::move(revs)}};
}

json::Value Server::unsubscribe(Client& client, const Args& args) {
    const json::Value& topics = args["topics"];
    if (topics.is_array()) {
        for (const json::Value& t : topics.as_array()) {  // set.difference_update: removes until a TypeError
            if (unhashable(t)) throw std::runtime_error("unhashable type in topics");
            if (t.is_string()) client.topics.erase(t.as_string());
        }
    }
    return json::Object{};
}

void Server::listen(int fd) {
    listen_fd_ = fd;
    ::fcntl(fd, F_SETFL, ::fcntl(fd, F_GETFL) | O_NONBLOCK);
    accept_ = std::make_unique<QSocketNotifier>(fd, QSocketNotifier::Read);
    QObject::connect(accept_.get(), &QSocketNotifier::activated, [this] { on_accept(); });
}

void Server::on_accept() {
    while (true) {
        int fd = ::accept4(listen_fd_, nullptr, nullptr, SOCK_NONBLOCK | SOCK_CLOEXEC);
        if (fd < 0) {
            if (errno == EINTR) continue;
            return;  // EAGAIN, or a peer that left before we got to it
        }
        auto client = std::make_shared<Client>(*this, fd);
        if (client->uid != static_cast<int>(::getuid())) {
            log::warning("fart.protocol", "refused a peer with uid " + std::to_string(client->uid));
            client->release_fd();
            continue;
        }
        clients_.push_back(client);
        client->start();
    }
}

void Server::stop_listening() {
    retire(accept_);
    if (listen_fd_ >= 0) {
        ::close(listen_fd_);
        listen_fd_ = -1;
    }
}

void Server::close_all() {
    for (const auto& c : std::vector<std::shared_ptr<Client>>(clients_)) {
        c->flush();  // non-blocking: what fits goes out (the shutdown reply among it)
        c->closed = true;
        c->release_fd();
    }
    clients_.clear();
}

void Server::finish(const std::shared_ptr<Client>& client) {
    auto it = std::find(clients_.begin(), clients_.end(), client);
    if (it == clients_.end()) return;
    clients_.erase(it);
    client->close();
    for (const auto& callback : on_disconnect) callback(*client);
}

bool Server::is_answer(std::string_view line) {
    if (line.find("host.done") == std::string_view::npos) return false;
    auto parsed = json::parse(line);
    if (!parsed.value || !parsed.value->is_object()) return false;
    const json::Value* op = parsed.value->find("op");
    return op && op->is_string() && kAnswers.contains(op->as_string()) && !parsed.value->find("id");
}

std::optional<OpError> Server::bind(const Spec& spec, const json::Value& args, Args& out) const {
    // inspect.signature(handler).bind(client, **args), in its order: the peer given twice, then the first
    // missing parameter, then the first unexpected name (in the order sent) unless the handler takes **kwargs.
    if (args.find(spec.peer)) return bad_args("multiple values for argument " + py::repr(spec.peer));
    for (const auto& [name, def] : spec.params) {
        if (const json::Value* v = args.find(name)) {
            out.named_.set(name, *v);
            out.given_.insert(name);
        } else if (def) {
            out.named_.set(name, *def);
        } else {
            return bad_args("missing a required argument: " + py::repr(name));
        }
    }
    for (const json::Member& m : args.as_object()) {
        if (out.named_.find(m.key)) continue;
        if (spec.varkw.empty()) return bad_args("got an unexpected keyword argument " + py::repr(m.key));
        out.extra_.set(m.key, m.value);
    }
    return std::nullopt;
}

void Server::dispatch(const std::shared_ptr<Client>& client, const std::string& line, std::function<void()> done) {
    // protocol.py Server.dispatch, check for check.
    auto parsed = json::parse(line);
    if (!parsed.value || parsed.lone_surrogate) {  // not JSON, invalid UTF-8, or an escape Python can't encode
        client->send(error_reply(nullptr, {"bad-request", "not JSON"}));
        done();
        return;
    }
    const json::Value& message = *parsed.value;
    json::Value request_id;
    std::string op_text = "?";
    if (message.is_object()) {
        if (const json::Value* id = message.find("id")) request_id = *id;
        if (const json::Value* op = message.find("op")) op_text = op->is_string() ? op->as_string() : json::dump(*op, json::Style::Default);
    }
    auto answered = std::make_shared<bool>(false);
    auto respond = [client, request_id, op_text, done, answered](Outcome outcome) {
        if (*answered) return;
        *answered = true;
        if (!request_id.is_null()) {
            if (outcome.ok) {
                json::Value result = outcome.result.is_null() ? json::Value(json::Object{}) : std::move(outcome.result);
                client->send(json::Object{{"id", request_id}, {"ok", true}, {"result", std::move(result)}});
            } else {
                client->send(error_reply(request_id, outcome.error));
            }
        } else if (!outcome.ok) {
            log::info("fart.protocol", "notification " + op_text + " failed: " + outcome.error.code);
        }
        done();
    };
    try {
        const json::Value* op = message.is_object() ? message.find("op") : nullptr;
        if (!op || !op->is_string()) throw OpError{"bad-request", "a request needs an op"};
        const json::Value* given = message.find("args");
        json::Value args = given ? *given : json::Value(json::Object{});
        if (!args.is_object()) throw OpError{"bad-request", "args must be an object"};
        const std::string& name = op->as_string();
        if (client->kind.empty() && name != "hello") throw OpError{"protocol", "send hello first"};
        auto spec = ops_.find(name);
        if (spec == ops_.end()) throw OpError{"unknown-op", "unknown op " + py::repr(name)};
        Args bound;
        if (auto error = bind(spec->second, args, bound)) throw *error;
        if (!spec->second.handler)  // in the Python core, not here yet (docs/CPP_CORE.md stages)
            throw OpError{"unported", name + " is not in the C++ core yet"};
        spec->second.handler(client, bound, respond);
    } catch (const OpError& error) {
        respond(Outcome{false, {}, error});
    } catch (const std::exception& error) {
        log::error("fart.protocol", std::string("op failed: ") + error.what());
        respond(Outcome{false, {}, {"internal", "internal error; see the core log"}});
    }
}

}  // namespace fart
