// JSON lines over a Unix socket: requests, replies and full-snapshot topic events (docs/CORE.md §2), as
// core/protocol.py serves them. Sockets are plain non-blocking fds watched by QSocketNotifier: the framing,
// the 1 MiB line limit, the 4 MiB output limit, half-closes and aborts all behave as asyncio's streams do there.
#pragma once

#include "json.h"

#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <string_view>
#include <vector>

class QSocketNotifier;

namespace fart {

constexpr int PROTOCOL = 1;
constexpr size_t MAX_LINE = 1 << 20;
constexpr size_t MAX_BUFFER = 4 << 20;

// A request failure reported to the client as {code, message} (core/errors.py OpError).
struct OpError {
    std::string code, message;
};
inline OpError bad_args(std::string message) { return {"bad-args", std::move(message)}; }

class Server;

class Client : public std::enable_shared_from_this<Client> {
public:
    Client(Server& server, int fd);
    ~Client();
    Client(const Client&) = delete;
    Client& operator=(const Client&) = delete;

    int pid = 0, uid = -1;
    std::string kind;  // "" until hello, then "cli" or "view"
    std::set<std::string, std::less<>> topics;
    bool closed = false;

    void send(const json::Value& message);
    void close();  // flush what is queued, then close (asyncio's writer.close())

private:
    friend class Server;
    Server& server_;
    int fd_;
    std::unique_ptr<QSocketNotifier> read_, write_;
    std::string in_, out_;
    size_t scanned_ = 0, out_pos_ = 0;
    std::deque<std::string> queue_;  // this client's requests, run one at a time and in order
    bool busy_ = false;       // a request is running (an async one may answer later)
    bool pumping_ = false;    // inside pump(): a synchronous answer doesn't recurse
    bool reading_ = true;     // false after EOF, a line over the limit, or a close
    bool finishing_ = false;  // the server has been asked to let this client go
    bool closing_ = false;    // close(): the fd goes once what's queued is written
    bool dead_ = false;       // a write failed: the peer is gone

    void start();
    void on_readable();
    void on_writable();
    void flush();
    void stop_reading();
    void abort();
    void release_fd();
    void pump();
    size_t buffered() const { return out_.size() - out_pos_; }
};

// What a handler sees: the bound arguments, defaults filled in, as the Python lambda's parameters would hold them.
class Args {
public:
    const json::Value& operator[](std::string_view name) const;
    bool given(std::string_view name) const;     // sent by the client (not a default)
    const json::Object& extra() const { return extra_.as_object(); }  // **kwargs, in the order sent

private:
    friend class Server;
    json::Value named_ = json::Object{}, extra_ = json::Object{};
    std::set<std::string, std::less<>> given_;
};

struct Outcome {
    bool ok = true;
    json::Value result;  // ok: null becomes {} on the wire
    OpError error;
};

class Server {
public:
    // table: the op table JSON (op_table.inc). Every topic in it is offered from the start, with a {} snapshot
    // until a port registers its own; every op in it binds its arguments, and answers "unported" until ported.
    explicit Server(const json::Value& table);
    ~Server();

    using Handler = std::function<json::Value(Client&, const Args&)>;  // throws OpError
    using Respond = std::function<void(Outcome)>;
    using AsyncHandler = std::function<void(const std::shared_ptr<Client>&, const Args&, Respond)>;
    void op(std::string_view name, Handler handler);
    void op_async(std::string_view name, AsyncHandler handler);
    void topic(std::string_view name, std::function<json::Value()> snapshot);

    void publish(std::string_view name);
    void push(Client& client, std::string_view name, json::Value data);

    void listen(int fd);  // a bound, listening socket; accepted clients are served from here on
    void stop_listening();
    void close_all();     // at exit: what can be written without blocking goes out, then every client closes

    std::vector<std::function<void(Client&)>> on_disconnect;
    const std::vector<std::shared_ptr<Client>>& clients() const { return clients_; }
    bool ported(std::string_view op) const;

private:
    friend class Client;
    struct Spec {
        std::string peer;
        std::vector<std::pair<std::string, std::optional<json::Value>>> params;  // name, default
        std::string varkw;  // "" when the handler takes no **kwargs
        AsyncHandler handler;  // empty: not ported yet
    };
    std::map<std::string, Spec, std::less<>> ops_;
    std::vector<std::string> topic_order_;
    std::map<std::string, std::function<json::Value()>, std::less<>> snapshots_;
    std::map<std::string, int64_t, std::less<>> revs_;
    std::vector<std::shared_ptr<Client>> clients_;
    int listen_fd_ = -1;
    std::unique_ptr<QSocketNotifier> accept_;

    void on_accept();
    void finish(const std::shared_ptr<Client>& client);
    static bool is_answer(std::string_view line);
    void dispatch(const std::shared_ptr<Client>& client, const std::string& line, std::function<void()> done);
    std::optional<OpError> bind(const Spec& spec, const json::Value& args, Args& out) const;
    json::Value subscribe(Client& client, const Args& args);
    json::Value unsubscribe(Client& client, const Args& args);
};

}  // namespace fart
