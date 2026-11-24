// Sessions (core/sessions.py, M11): one active session at a time, presets, Do Not Disturb, the debrief and the
// streak log (sessions.jsonl). Days are local days, as datetime.fromtimestamp() gives them under TZ.
#pragma once

#include "clock.h"
#include "host.h"
#include "json.h"
#include "protocol.h"

#include <filesystem>
#include <functional>
#include <vector>

namespace fart {

class Sessions {
public:
    Sessions(const Clock& clock, Scheduler& scheduler, Host& host, const std::filesystem::path& state_dir);

    std::function<void()> on_change = [] {};
    std::function<void()> on_guard = [] {};                           // the session guard (Overdrive, stage 4)
    std::function<int64_t(int64_t, int64_t)> tasks_done = [](int64_t, int64_t) { return int64_t{0}; };

    bool active() const { return !current_.is_null(); }
    json::Value snapshot() const;
    json::Value start(const json::Value& preset, const json::Value& seconds);
    json::Value end();
    json::Value dismiss();
    void attach(Server& server);

private:
    const Clock& clock_;
    Scheduler& scheduler_;
    Host& host_;
    std::filesystem::path path_, log_path_;
    json::Value current_, last_;
    std::vector<json::Value> entries_;

    std::vector<json::Value> read_log() const;
    double left(const Now& now) const;
    void schedule();
    void persist();
    void finish(bool completed);
};

// The local day of an epoch moment, as days since 1970-01-01: datetime.fromtimestamp(t).date().
int64_t local_day_at(double seconds);
inline int64_t local_day(double ms) { return local_day_at(ms / 1000); }
// The civil date of a day number, and back.
struct Date {
    int year, month, day;
};
Date civil(int64_t days);
int64_t days_of(int year, int month, int day);

}  // namespace fart
