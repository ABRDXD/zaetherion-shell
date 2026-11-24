// Suspend-proof time, as core/clock.py: boottime for spans, wall time for what people read.
#pragma once

#include "json.h"

#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

class QSocketNotifier;

namespace fart {

struct Now {
    double boot;  // CLOCK_BOOTTIME seconds: counts suspend, ignores wall-clock changes
    double real;  // epoch seconds (moved by FART_FIXTURE_EPOCH in a fixture core)
    std::string boot_id;
};

class Clock {
public:
    // epoch: a test core's wall clock starts there and runs at the real rate (fixture host only; fixture_epoch).
    explicit Clock(std::optional<double> epoch = std::nullopt);
    Now now() const;

private:
    std::string boot_id_;
    double offset_ = 0.0;
};

// core/fartd.py fixture_epoch: FART_FIXTURE_EPOCH as a float, honoured only when FART_HOST is "fixture", so a
// stray variable can never move the desktop's clock. A value that isn't a number is ignored with a warning.
std::optional<double> fixture_epoch(const std::map<std::string, std::string>& environ);

json::Value anchor(const Now& now);  // {"boot", "real", "bootId"}
// Seconds since an anchor: boottime on the same boot, else wall time (never negative). Throws on a malformed one.
double span(const json::Value& start, const Now& now);

// Elapsed time that survives suspend, core restarts and (by realtime) reboots (clock.py Run). `elapsed` stays a
// JSON number so an int read from a file is written back as an int, as Python's arithmetic would keep it.
struct Run {
    bool running = false;
    json::Value elapsed = 0.0;
    json::Value anchor;  // null, or whatever the file held (only an object counts while running)

    static Run since(double elapsed, const Now& now);
    double value(const Now& now) const;
    json::Value value_json(const Now& now) const;  // value(), keeping elapsed's own type when not running
    void start(const Now& now);
    void pause(const Now& now);
    void reset(json::Value to = 0.0);
    bool rebase(const Now& now);
    double deadline(double target, const Now& now) const;
    json::Value to_json() const;
    static Run from_json(const json::Value& value);
};

// Keyed boottime deadlines on one CLOCK_BOOTTIME timerfd, plus a watch on wall-clock changes
// (clock.py TimerfdScheduler). Callbacks for the same moment run in (deadline, key) order.
class Scheduler {
public:
    explicit Scheduler(const Clock& clock);
    ~Scheduler();
    void at(const std::string& key, double boot, std::function<void(const Now&)> callback);
    void cancel(const std::string& key);
    std::vector<std::function<void()>> clock_set;  // the wall clock was set

private:
    const Clock& clock_;
    std::map<std::string, std::pair<double, std::function<void(const Now&)>>> pending_;
    int fd_ = -1, realtime_ = -1;
    std::unique_ptr<QSocketNotifier> fd_notifier_, realtime_notifier_;
    void arm();
    void fire_due();
    void watch_realtime();
};

}  // namespace fart
