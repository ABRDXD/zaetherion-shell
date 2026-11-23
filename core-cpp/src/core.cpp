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

Core::Core(const Clock& clock, const std::filesystem::path& state_dir, Server& server,
           std::function<void()> stop)
    : clock_(clock), server_(server), stop_(std::move(stop)), started_(clock.now()),
      scheduler_(clock), timers_(clock, scheduler_, host_, state_dir), tasks_(clock, state_dir), island_(state_dir),
      clips_(state_dir), sfx_(host_, clock, [this] { return timers_.sound(); }, [] { return false; }),
      placeholders_(server) {
    host_.sfx = &sfx_;
    server.topic("timers", [this] { return timers_.snapshot(); });
    timers_.attach(server);
    sound_ = timers_.sound();
    // app.py _timers_changed: the alert cues' switch is the timer sound setting, so sfx follows that one value.
    // (Its satellite spawn for a DONE with the view reaped is view supervision: stage 2a.)
    timers_.on_change = [this, &server] {
        server.publish("timers");
        if (timers_.sound() != sound_) {
            sound_ = timers_.sound();
            server.publish("sfx");
        }
    };
    // An impulse, not state: sent to sfx subscribers as it happens and never replayed (app.py push_cue).
    sfx_.on_cue = [&server](const json::Value& event) {
        for (const auto& client : std::vector<std::shared_ptr<Client>>(server.clients()))
            if (client->topics.contains("sfx")) server.push(*client, "sfx.cue", event);
    };
    tasks_.attach(server);
    island_.attach(server);
    clips_.attach(server);
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
                        {"host", host_.name()}, {"startedAt", json::py_round_int(started_.real * 1000)}};
}

json::Value Core::status() const {
    Now now = clock_.now();
    json::Value core = json::Object{{"pid", static_cast<int64_t>(::getpid())}, {"rssKiB", static_cast<int64_t>(rss_kib())},
                                    {"uptime", json::py_round_int(now.boot - started_.boot)}, {"host", host_.name()}};
    json::Value out = json::Object{{"core", std::move(core)}};
    for (const char* part : {"view", "timers", "tasks", "notifications", "overdrive", "session"})
        out.set(part, std::string_view(part) == "tasks"    ? tasks_.summary()
                      : std::string_view(part) == "timers" ? timers_.summary()
                                                            : placeholders_.status_part(part));
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
