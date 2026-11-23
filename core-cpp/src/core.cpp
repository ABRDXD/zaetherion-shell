#include "core.h"

#include <fstream>
#include <unistd.h>

namespace fart {

long rss_kib() {
    std::ifstream in("/proc/self/status");
    std::string line;
    while (std::getline(in, line))
        if (line.rfind("VmRSS:", 0) == 0) return std::stol(line.substr(6));
    return 0;
}

Core::Core(const Clock& clock, std::string host, Server& server, std::function<void()> stop)
    : clock_(clock), host_(std::move(host)), server_(server), stop_(std::move(stop)), started_(clock.now()),
      placeholders_(server) {
    server.topic("core", [this] { return core_snapshot(); });
    // Always offered, so a view can subscribe whether or not this core supervises DMS (stage 2b ports the
    // supervisor; until then this core never supervises, which is what this snapshot says).
    server.topic("supervisor", [] { return json::Value(json::Object{{"children", json::Object{}}}); });
    server.op("hello", [this](Client& peer, const Args& args) { return hello(peer, args); });
    server.op("status", [this](Client&, const Args&) { return status(); });
    server.op("shutdown", [this](Client&, const Args&) {
        stop_();
        return json::Value(json::Object{});
    });
}

json::Value Core::core_snapshot() const {
    return json::Object{{"version", VERSION}, {"protocol", PROTOCOL}, {"pid", static_cast<int64_t>(::getpid())},
                        {"host", host_}, {"startedAt", json::py_round_int(started_.real * 1000)}};
}

json::Value Core::status() const {
    Now now = clock_.now();
    json::Value core = json::Object{{"pid", static_cast<int64_t>(::getpid())}, {"rssKiB", static_cast<int64_t>(rss_kib())},
                                    {"uptime", json::py_round_int(now.boot - started_.boot)}, {"host", host_}};
    json::Value out = json::Object{{"core", std::move(core)}};
    for (const char* part : {"view", "timers", "tasks", "notifications", "overdrive", "session"})
        out.set(part, placeholders_.status_part(part));
    return out;
}

json::Value Core::hello(Client& peer, const Args& args) {
    // app.py Core.hello: Python's != and `in` (1.0 and true are protocol 1; only the exact strings are kinds).
    if (!args["protocol"].py_equals(json::Value(PROTOCOL)))
        throw OpError{"protocol", "this core speaks protocol " + std::to_string(PROTOCOL)};
    const json::Value& client = args["client"];
    bool cli = client.is_string() && client.as_string() == "cli";
    bool view = client.is_string() && client.as_string() == "view";
    if (!cli && !view) throw bad_args("client must be cli or view");
    if (view)  // stage 2a ports view supervision; until then no view was spawned, so none may say it is one
        throw OpError{"refused", "only the view this core spawned may connect as the view"};
    peer.kind = client.as_string();
    return json::Object{{"core", core_snapshot()}};
}

}  // namespace fart
