#include "timers.h"

#include "log.h"
#include "pystr.h"
#include "store.h"

#include <cmath>
#include <stdexcept>

namespace fart {

namespace {

const char* kKinds[] = {"pomodoro", "stopwatch", "countdown"};
constexpr int kPomodoro = 0, kStopwatch = 1, kCountdown = 2;
constexpr double kLate = 60.0;  // beyond this, a deadline passed while the machine slept: no sound, pomodoro pauses
constexpr int64_t kMaxSeconds = 7 * 86400;

json::Value default_config() {
    return json::Object{{"pomodoro", json::Object{{"focus", 1500}, {"break", 300}, {"longBreak", 900}, {"cycles", 4}}},
                        {"sound", false}};
}

const char* phase_label(const std::string& phase) {
    if (phase == "focus") return "Focus";
    if (phase == "break") return "Break";
    if (phase == "longBreak") return "Long break";
    return nullptr;
}

const json::Value& get(const json::Value& object, std::string_view key) {  // dict.get(key)
    static const json::Value null;
    const json::Value* v = object.is_object() ? object.find(key) : nullptr;
    return v ? *v : null;
}

// `value or {}` followed by .get(): a truthy value that isn't a dict is Python's AttributeError.
const json::Value& or_empty(const json::Value& value) {
    static const json::Value empty = json::Object{};
    if (!py::truthy(value)) return empty;
    if (!value.is_object()) throw std::runtime_error("timers: expected an object, found " + py::repr_of(value));
    return value;
}

// `for x in value or []`: what Python iterates in a list, a string (its characters) or a dict (its keys).
json::Array items(const json::Value& value) {
    if (!py::truthy(value)) return {};
    if (value.is_array()) return value.as_array();
    json::Array out;
    if (value.is_string()) {
        const std::string& s = value.as_string();
        for (size_t i = 0; i < s.size();) {
            size_t start = i;
            py::next_code_point(s, i);
            out.emplace_back(s.substr(start, i - start));
        }
        return out;
    }
    if (value.is_object()) {
        for (const auto& m : value.as_object()) out.emplace_back(m.key);
        return out;
    }
    throw std::runtime_error("timers: not iterable: " + py::repr_of(value));
}

bool is_int(const json::Value& v) { return v.is_int() || v.is_bool() || v.type() == json::Value::Type::BigInt; }
bool is_number(const json::Value& v) { return is_int(v) || v.is_float(); }
bool positive(const json::Value& v) {
    if (v.type() == json::Value::Type::BigInt) return v.as_bigint().digits[0] != '-';
    return py::number(v) > 0;
}

// a % b, a + 1 and a >= b on Python numbers (int stays int, a float on either side makes a float). An int of
// any size works, as in Python: a file can hold a cycle past 64 bits; a divisor is a validated small length.

json::Value py_mod(const json::Value& a, const json::Value& b) {
    if (is_int(a) && is_int(b)) {
        int64_t y = py::int_of(b);  // the cycles length: 1 to 12
        if (y == 0) throw std::runtime_error("integer modulo by zero");
        int64_t r;
        if (a.type() == json::Value::Type::BigInt) {
            // |a| mod |y| digit by digit; acc * 10 + 9 stays inside 64 bits while |y| is below 10**17.
            uint64_t m = y < 0 ? 0 - static_cast<uint64_t>(y) : static_cast<uint64_t>(y), acc = 0;
            if (m >= 100000000000000000ULL) throw std::runtime_error("modulo of a huge int by a huge int");
            const std::string& digits = a.as_bigint().digits;
            bool negative = digits[0] == '-';
            for (char c : std::string_view(digits).substr(negative ? 1 : 0)) acc = (acc * 10 + static_cast<uint64_t>(c - '0')) % m;
            r = static_cast<int64_t>(acc);
            if (negative) r = -r;
        } else {
            r = py::int_of(a) % y;
        }
        return (r != 0 && ((r < 0) != (y < 0))) ? r + y : r;
    }
    double x = py::number(a), y = py::number(b);
    if (y == 0) throw std::runtime_error("float modulo");
    double r = std::fmod(x, y);
    if (r != 0 && ((r < 0) != (y < 0))) r += y;
    return r;
}
json::Value plus_one(const json::Value& a) {
    if (is_int(a)) return py::int_plus_one(a);
    return py::number(a) + 1;
}
bool at_least(const json::Value& a, const json::Value& b) {  // a >= b, b a small length
    if (a.type() == json::Value::Type::BigInt) return a.as_bigint().digits[0] != '-';  // |a| >= 2**63
    return py::number(a) >= py::number(b);
}

double seconds_arg(const json::Value& value, const std::string& name = "seconds", int64_t minimum = 1) {
    if (value.is_bool() || !is_number(value)) throw bad_args(name + " must be a number");
    if (value.type() == json::Value::Type::BigInt) {
        double d = py::float_of(value);  // math.isfinite(huge int) raises OverflowError
        (void)d;
        throw bad_args(name + " must be between " + std::to_string(minimum) + " and " + std::to_string(kMaxSeconds));
    }
    double d = py::number(value);
    if (!std::isfinite(d)) throw bad_args(name + " must be a number");
    if (!(minimum <= d && d <= kMaxSeconds))
        throw bad_args(name + " must be between " + std::to_string(minimum) + " and " + std::to_string(kMaxSeconds));
    return d;
}

int kind_arg(const json::Value& kind) {
    for (int k = 0; k < 3; ++k)
        if (kind.py_equals(json::Value(kKinds[k]))) return k;
    throw bad_args("kind must be one of pomodoro, stopwatch, countdown");
}

std::string ago(double seconds) {
    json::Value rounded = json::py_round_int(seconds / 60);
    int64_t minutes = std::max<int64_t>(1, rounded.as_int());
    if (minutes < 60) return std::to_string(minutes) + " min";
    return std::to_string(minutes / 60) + " h " + std::to_string(minutes % 60) + " min";
}

json::Value round_value(const json::Value& v, int digits) {  // round(x, n): an int stays an int
    return v.is_float() ? json::Value(json::py_round(v.as_float(), digits)) : v;
}

}  // namespace

Timers::Timers(const Clock& clock, Scheduler& scheduler, Host& host, const std::filesystem::path& state_dir)
    : clock_(clock), scheduler_(scheduler), host_(host), path_(state_dir / "timers.json"),
      settings_path_(state_dir / "settings.json") {
    state_ = load();
    scheduler.clock_set.push_back([this] { on_change(); });
    schedule();
}

// --- Persistence ---------------------------------------------------------------------------------------------------

Timers::State Timers::fresh(json::Value config) {
    State s;
    json::Value lengths = *config.find("pomodoro");
    s.kinds[kPomodoro].fields = json::Object{{"phase", "focus"}, {"cycle", 0}, {"duration", *lengths.find("focus")},
                                             {"lengths", lengths}, {"run", nullptr}, {"done", nullptr}};
    s.kinds[kStopwatch].fields = json::Object{{"run", nullptr}, {"laps", json::Array{}}};
    s.kinds[kCountdown].fields = json::Object{{"duration", 0.0}, {"run", nullptr}, {"done", nullptr}};
    s.config = std::move(config);
    return s;
}

json::Value Timers::config_from_settings() const {
    // The view's version 1 timer settings (settings.json), read once at migration.
    json::Value config = default_config();
    json::Value settings;
    try {
        auto saved = store::read_json(settings_path_);
        settings = saved && py::truthy(*saved) ? *saved : json::Value(json::Object{});
    } catch (const store::ValueError&) {
        return config;
    }
    if (!settings.is_object()) throw std::runtime_error("settings.json: not an object");  // settings.get's AttributeError
    const json::Value& pomodoro = or_empty(get(or_empty(get(settings, "time")), "pomodoro"));
    const std::pair<const char*, const char*> keys[] = {
        {"focus", "focus"}, {"break", "breakTime"}, {"longBreak", "longBreak"}, {"cycles", "cyclesBeforeLongBreak"}};
    for (const auto& [name, key] : keys) {
        const json::Value& v = get(pomodoro, key);
        if (is_int(v) && positive(v)) config["pomodoro"].set(name, v);
    }
    const json::Value& sound = get(or_empty(get(settings, "sounds")), "pomodoro");
    config.set("sound", sound.is_bool() && sound.as_bool());
    return config;
}

Timers::State Timers::migrate_v1(const json::Value& old, json::Value config, const Now& now) const {
    // Version 1 (TimerService): epoch seconds for pomodoro/countdown, 10 ms units for the stopwatch.
    const json::Value& timer = or_empty(get(old, "timer"));
    State s = fresh(std::move(config));
    const json::Value& pomodoro = or_empty(get(timer, "pomodoro"));
    const json::Value& stopwatch = or_empty(get(timer, "stopwatch"));
    const json::Value& countdown = or_empty(get(timer, "countdown"));
    json::Value& p = s.kinds[kPomodoro].fields;
    const json::Value lengths = p["lengths"];
    json::Value cycle_raw = get(pomodoro, "cycle");
    json::Value cycle = py_mod(py::int_value(py::truthy(cycle_raw) ? cycle_raw : json::Value(0)), *lengths.find("cycles"));
    bool broke = py::truthy(get(pomodoro, "isBreak"));
    std::string phase = !broke ? "focus" : at_least(plus_one(cycle), *lengths.find("cycles")) ? "longBreak" : "break";
    p.set("phase", phase);
    p.set("cycle", cycle);
    p.set("duration", *lengths.find(phase));
    auto or_now = [&](const json::Value& v) { return py::truthy(v) ? py::float_of(v) : now.real; };
    if (py::truthy(get(pomodoro, "running"))) s.kinds[kPomodoro].run = Run::since(now.real - or_now(get(pomodoro, "start")), now);
    if (py::truthy(get(stopwatch, "running"))) {
        const json::Value& start = get(stopwatch, "start");
        s.kinds[kStopwatch].run = Run::since((now.real * 100 - (py::truthy(start) ? py::float_of(start) : 0.0)) / 100, now);
    } else {
        const json::Value& elapsed = get(stopwatch, "elapsed");
        s.kinds[kStopwatch].run = Run{false, std::max(0.0, (py::truthy(elapsed) ? py::float_of(elapsed) : 0.0) / 100), {}};
    }
    json::Array laps;
    for (const json::Value& lap : items(get(stopwatch, "laps")))
        if (is_number(lap)) laps.emplace_back(py::float_of(lap) / 100);
    s.kinds[kStopwatch].fields.set("laps", std::move(laps));
    const json::Value& duration = get(countdown, "duration");
    double length = is_number(duration) && positive(duration) ? py::float_of(duration) : 0.0;
    s.kinds[kCountdown].fields.set("duration", length);
    if (py::truthy(get(countdown, "running")) && length > 0)
        s.kinds[kCountdown].run = Run::since(now.real - or_now(get(countdown, "start")), now);
    return s;
}

Timers::State Timers::parse(const json::Value& raw) const {
    json::Value config = default_config();
    const json::Value& saved_config = or_empty(get(raw, "config"));
    if (const json::Value* pomodoro = saved_config.find("pomodoro")) {  // .get("pomodoro", {}).items()
        if (!pomodoro->is_object()) throw std::runtime_error("timers.json: config.pomodoro is not an object");
        for (const auto& [k, v] : pomodoro->as_object())
            if (config["pomodoro"].find(k) && is_int(v) && positive(v)) config["pomodoro"].set(k, v);
    }
    const json::Value& sound = get(saved_config, "sound");
    config.set("sound", sound.is_bool() && sound.as_bool());
    State s = fresh(config);
    const json::Value& pomodoro = or_empty(get(raw, "pomodoro"));
    json::Value lengths = *config.find("pomodoro");
    for (const auto& [k, v] : or_empty(get(pomodoro, "lengths")).as_object())
        if (lengths.find(k) && is_number(v) && positive(v)) lengths.set(k, v);
    const json::Value& saved_phase = get(pomodoro, "phase");
    if (saved_phase.is_array() || saved_phase.is_object()) throw std::runtime_error("timers.json: unhashable phase");
    std::string phase = saved_phase.is_string() && phase_label(saved_phase.as_string()) ? saved_phase.as_string() : "focus";
    const json::Value& cycle = get(pomodoro, "cycle");
    const json::Value& duration = get(pomodoro, "duration");
    const json::Value& done = get(pomodoro, "done");
    json::Value& p = s.kinds[kPomodoro].fields;
    p.set("phase", phase);
    p.set("cycle", py::int_value(py::truthy(cycle) ? cycle : json::Value(0)));
    p.set("lengths", lengths);
    p.set("duration", py::float_of(py::truthy(duration) ? duration : *lengths.find(phase)));
    s.kinds[kPomodoro].run = Run::from_json(get(pomodoro, "run"));
    p.set("done", done.is_object() ? done : json::Value());
    const json::Value& stopwatch = or_empty(get(raw, "stopwatch"));
    s.kinds[kStopwatch].run = Run::from_json(get(stopwatch, "run"));
    json::Array laps;
    for (const json::Value& lap : items(get(stopwatch, "laps"))) laps.emplace_back(py::float_of(lap));
    s.kinds[kStopwatch].fields.set("laps", std::move(laps));
    const json::Value& countdown = or_empty(get(raw, "countdown"));
    const json::Value& length = get(countdown, "duration");
    const json::Value& countdown_done = get(countdown, "done");
    s.kinds[kCountdown].fields.set("duration", py::float_of(py::truthy(length) ? length : json::Value(0)));
    s.kinds[kCountdown].run = Run::from_json(get(countdown, "run"));
    s.kinds[kCountdown].fields.set("done", countdown_done.is_object() ? countdown_done : json::Value());
    return s;
}

Timers::State Timers::load() {
    Now now = clock_.now();
    std::optional<json::Value> raw;
    try {
        raw = store::read_json(path_);
    } catch (const store::ValueError&) {
        log::error("fart.timers", "timers.json is invalid; kept aside as timers.json.invalid");
        store::publish_new(path_.parent_path() / "timers.json.invalid", json::Value(store::read_text(path_).value()));
        raw.reset();
    }
    State state;
    if (!raw || !raw->is_object()) {
        state = fresh(config_from_settings());
    } else if (!raw->find("version")) {
        store::publish_new(path_.parent_path() / "timers.v1.json", *raw);
        state = migrate_v1(*raw, config_from_settings(), now);
        log::info("fart.timers", "migrated timers.json from version 1");
    } else {
        state = parse(*raw);
        bool rebased = false;
        for (auto& k : state.kinds) rebased = k.run.rebase(now) || rebased;  // every kind, as the Python loop does
        if (!rebased) return state;
    }
    write(state);
    return state;
}

void Timers::write(const State& state) const {
    json::Value value = json::Object{{"version", 2}, {"config", state.config}};
    for (int k = 0; k < 3; ++k) {
        json::Value fields = state.kinds[static_cast<size_t>(k)].fields;
        fields.set("run", state.kinds[static_cast<size_t>(k)].run.to_json());
        value.set(kKinds[k], std::move(fields));
    }
    store::write_json(path_, value);
}

void Timers::commit() {
    schedule();
    write(state_);
    on_change();
}

// --- Snapshot ------------------------------------------------------------------------------------------------------

bool Timers::sound() const { return py::truthy(*state_.config.find("sound")); }

json::Value Timers::snapshot() const {
    Now now = clock_.now();
    const Kind &p = state_.kinds[kPomodoro], &s = state_.kinds[kStopwatch], &c = state_.kinds[kCountdown];
    auto done_of = [](const json::Value& done) { return py::truthy(done) ? done : json::Value(); };
    return json::Object{
        {"at", json::py_round_int(now.real * 1000)},
        {"sound", *state_.config.find("sound")},
        {"config", state_.config},
        {"pomodoro", json::Object{{"running", p.run.running}, {"phase", *p.fields.find("phase")}, {"cycle", *p.fields.find("cycle")},
                                  {"elapsed", p.run.value_json(now)}, {"duration", *p.fields.find("duration")},
                                  {"lengths", *p.fields.find("lengths")}, {"done", done_of(*p.fields.find("done"))}}},
        {"stopwatch", json::Object{{"running", s.run.running}, {"elapsed", s.run.value_json(now)}, {"laps", *s.fields.find("laps")}}},
        {"countdown", json::Object{{"running", c.run.running}, {"elapsed", c.run.value_json(now)},
                                   {"duration", *c.fields.find("duration")}, {"done", done_of(*c.fields.find("done"))}}},
    };
}

json::Value Timers::summary() const {
    json::Value snap = snapshot();
    json::Value out = json::Object{};
    for (const char* kind : kKinds)
        out.set(kind, json::Object{{"running", *snap[kind].find("running")}, {"elapsed", round_value(*snap[kind].find("elapsed"), 2)}});
    out.set("done", !snap["countdown"].find("done")->is_null());
    out.set("pomodoroDone", !snap["pomodoro"].find("done")->is_null());
    return out;
}

std::vector<std::string> Timers::running() const {
    std::vector<std::string> out;
    for (int k = 0; k < 3; ++k)
        if (state_.kinds[static_cast<size_t>(k)].run.running) out.push_back(kKinds[k]);
    return out;
}

json::Value Timers::done_marks() const {
    return json::Array{*state_.kinds[kCountdown].fields.find("done"), *state_.kinds[kPomodoro].fields.find("done")};
}

// --- Operations (docs/CORE.md §2.4) ------------------------------------------------------------------------------

void Timers::start(const json::Value& kind_value, const json::Value& seconds, const json::Value& focus) {
    Now now = clock_.now();
    int k = kind_arg(kind_value);
    Kind& state = kind(k);
    if (k == kCountdown) {
        double length = seconds_arg(seconds);
        state.fields.set("duration", length);
        state.fields.set("done", nullptr);
    } else if (k == kPomodoro) {
        json::Value lengths = *state_.config.find("pomodoro");
        if (!focus.is_null()) lengths.set("focus", seconds_arg(focus, "focus"));
        state.fields.set("phase", "focus");
        state.fields.set("cycle", 0);
        state.fields.set("lengths", lengths);
        state.fields.set("duration", *lengths.find("focus"));
        state.fields.set("done", nullptr);
    } else {
        state.fields.set("laps", json::Array{});
    }
    state.run = Run();
    state.run.start(now);
    commit();
}

void Timers::toggle(const json::Value& kind_value) {
    Now now = clock_.now();
    int k = kind_arg(kind_value);
    Kind& state = kind(k);
    if (k == kCountdown) {
        if (py::number(*state.fields.find("duration")) <= 0) return;
        if (py::truthy(*state.fields.find("done"))) {
            state.fields.set("done", nullptr);
            state.run.reset();
        }
    }
    if (state.run.running) {
        state.run.pause(now);
    } else {
        if (k == kStopwatch && state.run.value(now) == 0) state.fields.set("laps", json::Array{});
        state.run.start(now);
    }
    commit();
}

void Timers::add(const json::Value& kind_value, const json::Value& seconds_value) {
    if (kind_arg(kind_value) != kCountdown) throw bad_args("only a countdown can be extended");
    double seconds = seconds_arg(seconds_value);
    Kind& state = kind(kCountdown);
    if (py::truthy(*state.fields.find("done"))) {
        state.fields.set("done", nullptr);
        state.fields.set("duration", 0.0);
        state.run.reset();
    }
    double total = py::number(*state.fields.find("duration")) + seconds;
    // min(MAX_SECONDS, total): the int unless total is smaller
    state.fields.set("duration", total < kMaxSeconds ? json::Value(total) : json::Value(kMaxSeconds));
    commit();
}

void Timers::lap() {
    Kind& state = kind(kStopwatch);
    Now now = clock_.now();
    if (state.run.value(now) > 0) {
        state.fields["laps"].as_array().push_back(state.run.value_json(now));
        commit();
    }
}

void Timers::reset(const json::Value& kind_value) {
    int k = kind_arg(kind_value);
    Kind& state = kind(k);
    state.run.reset();
    if (k == kPomodoro) {
        json::Value lengths = *state_.config.find("pomodoro");
        state.fields.set("phase", "focus");
        state.fields.set("cycle", 0);
        state.fields.set("lengths", lengths);
        state.fields.set("duration", *lengths.find("focus"));
        state.fields.set("done", nullptr);
    } else if (k == kStopwatch) {
        state.fields.set("laps", json::Array{});
    } else {
        state.fields.set("duration", 0.0);
        state.fields.set("done", nullptr);
    }
    commit();
}

void Timers::ack(const json::Value& kind_value) {
    // Clears DONE: a countdown's, a pomodoro phase's, or (no kind) both.
    int k = kind_value.is_null() ? -1 : kind_arg(kind_value);
    bool changed = false;
    Kind& countdown = kind(kCountdown);
    if ((k == -1 || k == kCountdown) && py::truthy(*countdown.fields.find("done"))) {
        countdown.fields.set("done", nullptr);  // back to a full, ready countdown of the same length
        countdown.run.reset();
        changed = true;
    }
    Kind& pomodoro = kind(kPomodoro);
    if ((k == -1 || k == kPomodoro) && py::truthy(*pomodoro.fields.find("done"))) {
        pomodoro.fields.set("done", nullptr);  // the next phase keeps running
        changed = true;
    }
    if (changed) commit();
}

void Timers::configure(const json::Value& pomodoro, const json::Value& sound) {
    json::Value& config = state_.config;
    json::Value update = json::Object{};
    if (!pomodoro.is_null()) {
        if (!pomodoro.is_object()) throw bad_args("pomodoro must be an object");
        for (const auto& [key, value] : pomodoro.as_object()) {
            if (!config["pomodoro"].find(key)) throw bad_args("unknown pomodoro setting " + py::repr(key));
            if (key == "cycles") {
                if (!value.is_int() || value.as_int() < 1 || value.as_int() > 12)
                    throw bad_args("cycles must be an integer from 1 to 12");
                update.set(key, value);
            } else {
                update.set(key, static_cast<int64_t>(seconds_arg(value, key, 60)));  // int(seconds_arg(...))
            }
        }
    }
    if (!sound.is_null() && !sound.is_bool()) throw bad_args("sound must be true or false");  // before anything changes
    if (!pomodoro.is_null()) {
        for (const auto& [key, value] : update.as_object()) config["pomodoro"].set(key, value);
        Kind& state = kind(kPomodoro);
        state.fields.set("lengths", *config.find("pomodoro"));
        // The running phase keeps its length; an idle pomodoro shows the new one.
        if (!state.run.running && py::number(state.run.elapsed) == 0)
            state.fields.set("duration", *state.fields["lengths"].find(state.fields["phase"].as_string()));
    }
    if (!sound.is_null()) config.set("sound", sound);
    commit();
}

// --- Deadlines -----------------------------------------------------------------------------------------------------

void Timers::schedule() {
    Now now = clock_.now();
    for (int k : {kPomodoro, kCountdown}) {
        Kind& state = kind(k);
        std::string key = std::string("timer.") + kKinds[k];
        if (state.run.running) {
            double at = state.run.deadline(py::number(*state.fields.find("duration")), now);
            if (k == kPomodoro) scheduler_.at(key, at, [this](const Now& n) { pomodoro_due(n); });
            else scheduler_.at(key, at, [this](const Now& n) { countdown_due(n); });
        } else {
            scheduler_.cancel(key);
        }
    }
}

void Timers::pomodoro_due(const Now& now) {
    Kind& state = kind(kPomodoro);
    double late = state.run.value(now) - py::number(*state.fields.find("duration"));
    if (late < 0) return schedule();
    std::string ended = state.fields["phase"].as_string();
    const json::Value lengths = *state.fields.find("lengths");
    const json::Value& cycles = *lengths.find("cycles");
    if (ended == "focus") {
        state.fields.set("phase", at_least(plus_one(*state.fields.find("cycle")), cycles) ? "longBreak" : "break");
    } else {
        state.fields.set("phase", "focus");
        state.fields.set("cycle", py_mod(plus_one(*state.fields.find("cycle")), cycles));
    }
    std::string phase = state.fields["phase"].as_string();
    state.fields.set("duration", *lengths.find(phase));
    state.run = Run();
    state.fields.set("done", json::Object{{"phase", ended}, {"next", phase}, {"at", json::py_round_int((now.real - late) * 1000)},
                                          {"late", json::py_round(late, 3)}});
    if (late > kLate) {
        host_.alert("Pomodoro", std::string(phase_label(ended)) + " ended " + ago(late) + " ago · paused");
    } else {
        // Anchor the next phase at the true boundary so wake latency never accumulates.
        state.run = Run::since(late, now);
        std::string minutes = std::to_string(static_cast<int64_t>(std::floor(py::number(*state.fields.find("duration")) / 60)));
        std::string message = phase == "focus" ? "🔴 Focus: " + minutes + " minutes"
                              : phase == "break" ? "☕ Break: " + minutes + " minutes"
                                                 : "🌿 Long break: " + minutes + " minutes";
        host_.alert("Pomodoro", message, "pomodoro.phase", sound());
    }
    commit();
}

void Timers::countdown_due(const Now& now) {
    Kind& state = kind(kCountdown);
    double late = state.run.value(now) - py::number(*state.fields.find("duration"));
    if (late < 0) return schedule();
    state.run.reset(*state.fields.find("duration"));
    state.fields.set("done", json::Object{{"at", json::py_round_int((now.real - late) * 1000)}, {"late", json::py_round(late, 3)}});
    if (late > kLate) host_.alert("Timers", "⏰ Countdown finished " + ago(late) + " ago");
    else host_.alert("Timers", "⏰ Countdown finished", "timer.done", sound());
    commit();
}

// --- Ops -------------------------------------------------------------------------------------------------------------

void Timers::attach(Server& server) {
    server.op("timer.start", [this](Client&, const Args& a) { return start(a["kind"], a["seconds"], a["focus"]), snapshot(); });
    server.op("timer.toggle", [this](Client&, const Args& a) { return toggle(a["kind"]), snapshot(); });
    server.op("timer.add", [this](Client&, const Args& a) { return add(a["kind"], a["seconds"]), snapshot(); });
    server.op("timer.lap", [this](Client&, const Args&) { return lap(), snapshot(); });
    server.op("timer.reset", [this](Client&, const Args& a) { return reset(a["kind"]), snapshot(); });
    server.op("timer.ack", [this](Client&, const Args& a) { return ack(a["kind"]), snapshot(); });
    server.op("timer.configure", [this](Client&, const Args& a) { return configure(a["pomodoro"], a["sound"]), snapshot(); });
}

}  // namespace fart
