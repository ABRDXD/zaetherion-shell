#include "clock.h"

#include "json.h"
#include "log.h"
#include "pystr.h"

#include <QSocketNotifier>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <ctime>
#include <fstream>
#include <stdexcept>
#include <sys/timerfd.h>
#include <unistd.h>

namespace fart {

namespace {
double seconds(clockid_t id) {
    timespec ts{};
    clock_gettime(id, &ts);
    return static_cast<double>(ts.tv_sec) + static_cast<double>(ts.tv_nsec) / 1e9;
}
}  // namespace

Clock::Clock(std::optional<double> epoch) {
    std::ifstream in("/proc/sys/kernel/random/boot_id");
    std::getline(in, boot_id_);
    while (!boot_id_.empty() && (boot_id_.back() == '\n' || boot_id_.back() == ' ')) boot_id_.pop_back();
    if (epoch) offset_ = *epoch - seconds(CLOCK_REALTIME);
}

Now Clock::now() const { return Now{seconds(CLOCK_BOOTTIME), seconds(CLOCK_REALTIME) + offset_, boot_id_}; }

std::optional<double> fixture_epoch(const std::map<std::string, std::string>& environ) {
    auto value = environ.find("FART_FIXTURE_EPOCH");
    auto host = environ.find("FART_HOST");
    if (value == environ.end() || value->second.empty() || host == environ.end() || host->second != "fixture")
        return std::nullopt;
    auto parsed = json::parse_double(value->second);
    if (!parsed) {
        log::warning("fart.core", "FART_FIXTURE_EPOCH=" + py::repr(value->second) + " ignored: not a number");
        return std::nullopt;
    }
    return parsed;
}

json::Value anchor(const Now& now) {
    return json::Object{{"boot", now.boot}, {"real", now.real}, {"bootId", now.boot_id}};
}

double span(const json::Value& start, const Now& now) {
    const json::Value* boot_id = start.find("bootId");
    if (boot_id && boot_id->is_string() && boot_id->as_string() == now.boot_id) {
        const json::Value* boot = start.find("boot");
        if (!boot) throw std::runtime_error("anchor without boot");
        return now.boot - py::number(*boot);
    }
    const json::Value* real = start.find("real");
    if (!real) throw std::runtime_error("anchor without real");
    return std::max(0.0, now.real - py::number(*real));
}

Run Run::since(double elapsed, const Now& now) { return Run{true, std::max(0.0, elapsed), fart::anchor(now)}; }

double Run::value(const Now& now) const {
    if (!running || !py::truthy(anchor)) return py::number(elapsed);
    return py::number(elapsed) + std::max(0.0, span(anchor, now));
}

json::Value Run::value_json(const Now& now) const {
    if (!running || !py::truthy(anchor)) return elapsed;
    return value(now);
}

void Run::start(const Now& now) {
    if (!running) {
        running = true;
        anchor = fart::anchor(now);
    }
}

void Run::pause(const Now& now) {
    if (running) {
        elapsed = value_json(now);
        running = false;
        anchor = json::Value();
    }
}

void Run::reset(json::Value to) {
    running = false;
    elapsed = std::move(to);
    anchor = json::Value();
}

bool Run::rebase(const Now& now) {
    // Fold a foreign-boot anchor once; afterwards only boottime arithmetic applies.
    if (running && py::truthy(anchor)) {
        const json::Value* id = anchor.find("bootId");
        if (!(id && id->is_string() && id->as_string() == now.boot_id)) {
            elapsed = value(now);
            anchor = fart::anchor(now);
            return true;
        }
    }
    return false;
}

double Run::deadline(double target, const Now& now) const { return now.boot + (target - value(now)); }

json::Value Run::to_json() const { return json::Object{{"running", running}, {"elapsed", elapsed}, {"anchor", anchor}}; }

Run Run::from_json(const json::Value& value) {
    static const json::Value empty = json::Object{};
    const json::Value& v = value.is_object() ? value : empty;
    auto get = [&](const char* key) {
        const json::Value* m = v.find(key);
        return m ? *m : json::Value();
    };
    Run run;
    run.running = py::truthy(get("running"));
    json::Value elapsed = get("elapsed");
    run.elapsed = py::truthy(elapsed) ? json::Value(py::float_of(elapsed)) : json::Value(py::float_of(json::Value(0)));
    run.anchor = get("anchor");
    if (run.running && !run.anchor.is_object()) run.running = false;
    return run;
}

// --- Scheduler -------------------------------------------------------------------------------------------------

namespace {
itimerspec absolute(double seconds) {
    itimerspec spec{};
    double whole = std::floor(seconds);
    spec.it_value.tv_sec = static_cast<time_t>(whole);
    spec.it_value.tv_nsec = static_cast<long>((seconds - whole) * 1e9);
    return spec;
}
}  // namespace

Scheduler::Scheduler(const Clock& clock) : clock_(clock) {
    fd_ = ::timerfd_create(CLOCK_BOOTTIME, TFD_NONBLOCK | TFD_CLOEXEC);
    realtime_ = ::timerfd_create(CLOCK_REALTIME, TFD_NONBLOCK | TFD_CLOEXEC);
    if (fd_ < 0 || realtime_ < 0) throw std::runtime_error("timerfd_create failed");
    fd_notifier_ = std::make_unique<QSocketNotifier>(fd_, QSocketNotifier::Read);
    QObject::connect(fd_notifier_.get(), &QSocketNotifier::activated, [this] {
        uint64_t count;
        ssize_t ignored = ::read(fd_, &count, sizeof count);
        (void)ignored;
        fire_due();
    });
    realtime_notifier_ = std::make_unique<QSocketNotifier>(realtime_, QSocketNotifier::Read);
    QObject::connect(realtime_notifier_.get(), &QSocketNotifier::activated, [this] {
        uint64_t count;
        if (::read(realtime_, &count, sizeof count) < 0 && errno != ECANCELED) return;  // EAGAIN: spurious
        watch_realtime();
        for (const auto& callback : std::vector<std::function<void()>>(clock_set)) callback();
        fire_due();
    });
    watch_realtime();
}

Scheduler::~Scheduler() {
    fd_notifier_.reset();
    realtime_notifier_.reset();
    if (fd_ >= 0) ::close(fd_);
    if (realtime_ >= 0) ::close(realtime_);
}

void Scheduler::at(const std::string& key, double boot, std::function<void(const Now&)> callback) {
    pending_[key] = {boot, std::move(callback)};
    arm();
}

void Scheduler::cancel(const std::string& key) {
    if (pending_.erase(key)) arm();
}

void Scheduler::arm() {
    // 0 disarms; a deadline already past fires at once (1 ns after the clock's epoch).
    itimerspec spec{};
    if (!pending_.empty()) {
        double next = pending_.begin()->second.first;
        for (const auto& [key, entry] : pending_) next = std::min(next, entry.first);
        spec = absolute(std::max(next, 1e-9));
        if (spec.it_value.tv_sec == 0 && spec.it_value.tv_nsec == 0) spec.it_value.tv_nsec = 1;
    }
    ::timerfd_settime(fd_, TFD_TIMER_ABSTIME, &spec, nullptr);
}

void Scheduler::fire_due() {
    Now now = clock_.now();
    std::vector<std::pair<double, std::string>> due;
    for (const auto& [key, entry] : pending_)
        if (entry.first <= now.boot) due.emplace_back(entry.first, key);
    std::sort(due.begin(), due.end());
    for (const auto& [boot, key] : due) {
        auto it = pending_.find(key);
        if (it == pending_.end()) continue;  // an earlier callback cancelled it
        auto callback = std::move(it->second.second);
        pending_.erase(it);
        callback(now);
    }
    arm();
}

void Scheduler::watch_realtime() {
    timespec ts{};
    clock_gettime(CLOCK_REALTIME, &ts);
    itimerspec spec{};
    spec.it_value.tv_sec = ts.tv_sec + 10L * 365 * 86400;
    ::timerfd_settime(realtime_, TFD_TIMER_ABSTIME | TFD_TIMER_CANCEL_ON_SET, &spec, nullptr);
}

}  // namespace fart
