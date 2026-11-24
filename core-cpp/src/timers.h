// Pomodoro, stopwatch and countdown on boottime anchors, so they survive suspend (core/timers.py, docs/CORE.md §3).
// Each kind is the Python dict it is there (key order and int/float kept), with its Run held beside it.
#pragma once

#include "clock.h"
#include "host.h"
#include "json.h"
#include "protocol.h"

#include <array>
#include <filesystem>
#include <functional>

namespace fart {

class Timers {
public:
    Timers(const Clock& clock, Scheduler& scheduler, Host& host, const std::filesystem::path& state_dir);

    std::function<void()> on_change = [] {};

    json::Value snapshot() const;
    json::Value summary() const;
    bool sound() const;
    std::vector<std::string> running() const;
    json::Value done_marks() const;  // (countdown done, pomodoro done): the core's satellite check

    void start(const json::Value& kind, const json::Value& seconds, const json::Value& focus);
    void toggle(const json::Value& kind);
    void add(const json::Value& kind, const json::Value& seconds);
    void lap();
    void reset(const json::Value& kind);
    void ack(const json::Value& kind);
    void configure(const json::Value& pomodoro, const json::Value& sound);

    void attach(Server& server);

private:
    struct Kind {
        json::Value fields;  // the dict, with "run" holding a placeholder at its place
        Run run;
    };
    struct State {
        json::Value config;
        std::array<Kind, 3> kinds;  // pomodoro, stopwatch, countdown
    };

    const Clock& clock_;
    Scheduler& scheduler_;
    Host& host_;
    std::filesystem::path path_, settings_path_;
    State state_;

    State load();
    State parse(const json::Value& raw) const;
    State migrate_v1(const json::Value& old, json::Value config, const Now& now) const;
    static State fresh(json::Value config);
    json::Value config_from_settings() const;
    void write(const State& state) const;
    void commit();
    void schedule();
    void pomodoro_due(const Now& now);
    void countdown_due(const Now& now);
    Kind& kind(int index) { return state_.kinds[static_cast<size_t>(index)]; }
};

}  // namespace fart
