#include "sessions.h"

#include "log.h"
#include "pystr.h"
#include "store.h"

#include <algorithm>
#include <cmath>
#include <ctime>
#include <map>
#include <set>
#include <stdexcept>

namespace fart {

namespace {

constexpr double kMaxSeconds = 12 * 3600;
constexpr double kStreakSeconds = 10 * 60;  // a day counts toward the streak with this much session time
constexpr int kDays = 14;                    // the streak strip: oldest first, today last
constexpr size_t kLogLines = 2000;           // lines read back from the log

const std::vector<std::pair<const char*, int64_t>>& presets() {
    static const std::vector<std::pair<const char*, int64_t>> p = {
        {"focus", 50 * 60}, {"deep", 90 * 60}, {"study", 2 * 3600}, {"read", 45 * 60}};
    return p;
}

const json::Value& get(const json::Value& object, std::string_view key) {
    static const json::Value null;
    const json::Value* v = object.is_object() ? object.find(key) : nullptr;
    return v ? *v : null;
}

// PRESET = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$") with match(): ASCII only, `$` also before a final "\n".
bool preset_name(const std::string& s) {
    std::string_view body = s;
    if (!body.empty() && body.back() == '\n') body.remove_suffix(1);
    auto ok = [](char c, bool first) {
        return (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || (!first && (c == '_' || c == '-'));
    };
    if (body.empty() || body.size() > 32 || !ok(body[0], true)) return false;
    return std::all_of(body.begin() + 1, body.end(), [&](char c) { return ok(c, false); });
}

bool non_negative_number(const json::Value& v) {  // isinstance(v, (int, float)) and not bool and v >= 0
    if (v.type() == json::Value::Type::BigInt) return v.as_bigint().digits[0] != '-';
    return (v.is_int() || v.is_float()) && py::number(v) >= 0;
}

bool valid_entry(const json::Value& e) {
    return e.is_object() && get(e, "preset").is_string() && non_negative_number(get(e, "start")) &&
           non_negative_number(get(e, "seconds"));
}

json::Value presets_json() {
    json::Array out;
    for (const auto& [name, seconds] : presets()) out.push_back(json::Object{{"name", name}, {"seconds", seconds}});
    return out;
}

// seconds.get(day, 0) + e["seconds"]: an int sum stays an int until a float joins it.
struct Sum {
    bool is_float = false;
    int64_t i = 0;
    double d = 0;
    void add(const json::Value& v) {
        if (v.is_float() || is_float) {
            if (!is_float) d = static_cast<double>(i);
            is_float = true;
            d += py::float_of(v);
        } else {
            i += py::int_of(v);
        }
    }
    double value() const { return is_float ? d : static_cast<double>(i); }
};

json::Value streak(const std::vector<json::Value>& entries, int64_t today) {
    std::map<int64_t, Sum> seconds;
    for (const json::Value& e : entries) seconds[local_day(py::float_of(get(e, "start")))].add(get(e, "seconds"));
    std::set<int64_t> counted;
    for (const auto& [day, sum] : seconds)
        if (sum.value() >= kStreakSeconds) counted.insert(day);
    int64_t current = 0, d = counted.contains(today) ? today : today - 1;
    while (counted.contains(d)) {
        ++current;
        --d;
    }
    int64_t best = 0, run = 0;
    std::optional<int64_t> last;
    for (int64_t day : counted) {
        run = last && day - *last == 1 ? run + 1 : 1;
        best = std::max(best, run);
        last = day;
    }
    json::Array strip;
    for (int i = 0; i < kDays; ++i) {
        auto it = seconds.find(today - (kDays - 1 - i));
        strip.push_back(json::py_round_int((it == seconds.end() ? 0.0 : it->second.value()) / 60));
    }
    return json::Object{{"current", current}, {"best", best}, {"minutes", std::move(strip)}};
}

// str.splitlines(): every line boundary Python knows, "\r\n" as one.
std::vector<std::string> splitlines(const std::string& text) {
    std::vector<std::string> out;
    std::string line;
    size_t i = 0;
    while (i < text.size()) {
        size_t at = i;
        uint32_t cp = py::next_code_point(text, i);
        bool boundary = cp == '\n' || cp == '\r' || cp == 0x0B || cp == 0x0C || cp == 0x1C || cp == 0x1D || cp == 0x1E ||
                        cp == 0x85 || cp == 0x2028 || cp == 0x2029;
        if (!boundary) {
            line.append(text, at, i - at);
            continue;
        }
        if (cp == '\r' && i < text.size() && text[i] == '\n') ++i;
        out.push_back(std::move(line));
        line.clear();
    }
    if (!line.empty()) out.push_back(std::move(line));
    return out;
}

}  // namespace

int64_t days_of(int year, int month, int day) {  // days from civil (proleptic Gregorian), 1970-01-01 = 0
    year -= month <= 2;
    const int64_t era = (year >= 0 ? year : year - 399) / 400;
    const int64_t yoe = year - era * 400;
    const int64_t doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
    const int64_t doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

Date civil(int64_t z) {
    z += 719468;
    const int64_t era = (z >= 0 ? z : z - 146096) / 146097;
    const int64_t doe = z - era * 146097;
    const int64_t yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    const int64_t doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    const int64_t mp = (5 * doy + 2) / 153;
    const int d = static_cast<int>(doy - (153 * mp + 2) / 5 + 1);
    const int m = static_cast<int>(mp < 10 ? mp + 3 : mp - 9);
    return Date{static_cast<int>(yoe + era * 400 + (m <= 2)), m, d};
}

int64_t local_day_at(double t) {
    // datetime.fromtimestamp(t): t split into seconds and microseconds rounded half to even, then local time.
    double whole;
    double us = std::nearbyint(std::modf(t, &whole) * 1e6);
    if (us >= 1e6) whole += 1;
    else if (us < 0) whole -= 1;
    time_t seconds = static_cast<time_t>(whole);
    tm local{};
    if (!localtime_r(&seconds, &local)) throw std::runtime_error("timestamp out of range");
    return days_of(local.tm_year + 1900, local.tm_mon + 1, local.tm_mday);
}

Sessions::Sessions(const Clock& clock, Scheduler& scheduler, Host& host, const std::filesystem::path& state_dir)
    : clock_(clock), scheduler_(scheduler), host_(host), path_(state_dir / "session.json"),
      log_path_(state_dir / "sessions.jsonl") {
    json::Value saved = json::Object{};
    try {
        auto read = store::read_json(path_);
        if (read && py::truthy(*read)) saved = std::move(*read);
    } catch (const store::ValueError&) {
    }
    if (!saved.is_object()) throw std::runtime_error("session.json: not an object");  // saved.get's AttributeError
    current_ = get(saved, "active").is_object() ? get(saved, "active") : json::Value();
    last_ = get(saved, "last").is_object() ? get(saved, "last") : json::Value();
    entries_ = read_log();
    if (active()) schedule();
}

std::vector<json::Value> Sessions::read_log() const {
    std::optional<std::string> text;
    try {
        text = store::read_text(log_path_);
    } catch (const std::system_error&) {  // OSError: no log to read
        return {};
    }
    if (!text) return {};
    std::vector<std::string> lines = splitlines(*text);
    if (lines.size() > kLogLines) lines.erase(lines.begin(), lines.end() - static_cast<long>(kLogLines));
    std::vector<json::Value> out;
    for (const auto& line : lines) {
        auto parsed = json::parse(line);
        if (parsed.value && valid_entry(*parsed.value)) out.push_back(std::move(*parsed.value));
    }
    return out;
}

double Sessions::left(const Now& now) const {
    return py::number(get(current_, "seconds")) - span(get(current_, "anchor"), now);
}

void Sessions::schedule() {
    Now now = clock_.now();
    scheduler_.at("session.end", now.boot + left(now), [this](const Now&) { finish(true); });
}

void Sessions::persist() {
    // The debrief is kept without the apps: those stay in memory, read from the host when the session ended.
    json::Value last;
    if (py::truthy(last_)) {
        last = json::Object{};
        for (const auto& m : last_.as_object())
            if (m.key != "apps") last.set(m.key, m.value);
    }
    store::write_json(path_, json::Object{{"active", current_}, {"last", last}});
}

json::Value Sessions::snapshot() const {
    Now now = clock_.now();
    json::Value out = json::Object{{"active", nullptr}, {"presets", presets_json()}, {"last", last_},
                                   {"streak", streak(entries_, local_day(now.real * 1000))}};
    if (py::truthy(current_)) {
        double started = py::number(get(get(current_, "anchor"), "real"));
        out.set("active", json::Object{{"preset", get(current_, "preset")}, {"startedAt", json::py_round_int(started * 1000)},
                                       {"until", json::py_round_int((now.real + left(now)) * 1000)},
                                       {"seconds", json::py_round_int(py::number(get(current_, "seconds")))}});
    }
    return out;
}

json::Value Sessions::start(const json::Value& preset, const json::Value& seconds_value) {
    if (py::truthy(current_)) throw OpError{"conflict", "a session is already running; end it first"};
    if (!preset.is_string() || !preset_name(preset.as_string())) throw bad_args("preset must be a short lowercase name");
    const std::string& name = preset.as_string();
    json::Value seconds = seconds_value;
    if (seconds.is_null()) {
        auto it = std::find_if(presets().begin(), presets().end(), [&](const auto& p) { return name == p.first; });
        if (it == presets().end()) throw bad_args(name + " isn't a preset (focus, deep, study, read); give it a length");
        seconds = it->second;
    }
    bool in_range = false;
    if (seconds.is_int() || seconds.is_float()) {
        double s = py::number(seconds);
        in_range = 60 <= s && s <= kMaxSeconds;
    }
    if (!in_range) throw bad_args("seconds must be between 60 and 43200");
    current_ = json::Object{{"preset", name}, {"anchor", anchor(clock_.now())}, {"seconds", py::float_of(seconds)}};
    // Do Not Disturb: turned on only if it was off, and remembered, so the end puts back only what it changed.
    current_.set("dnd", !host_.dnd() && host_.set_dnd(true));
    last_ = json::Value();
    schedule();
    persist();
    on_change();
    on_guard();
    // The session's music (app.py _session_music) goes through the view: nothing while the view is absent, which
    // it always is until view supervision (stage 2a).
    return snapshot();
}

json::Value Sessions::end() {
    if (!py::truthy(current_)) throw OpError{"not-found", "no session is running"};
    finish(false);
    return snapshot();
}

json::Value Sessions::dismiss() {
    last_ = json::Value();
    persist();
    on_change();
    return snapshot();
}

void Sessions::finish(bool completed) {
    if (!py::truthy(current_)) return;
    Now now = clock_.now();
    double spent = span(get(current_, "anchor"), now), planned = py::number(get(current_, "seconds"));
    double done = planned < spent ? planned : spent;  // min(span, seconds)
    json::Value start = json::py_round_int(py::number(get(get(current_, "anchor"), "real")) * 1000);
    json::Value end = json::py_round_int(now.real * 1000);
    json::Value entry = json::Object{{"preset", get(current_, "preset")}, {"start", start}, {"end", end},
                                     {"seconds", json::py_round_int(done)}, {"completed", completed}};
    store::append_line(log_path_, entry);
    entries_.push_back(entry);
    if (entries_.size() > kLogLines) entries_.erase(entries_.begin());
    int64_t tasks = 0;
    try {
        tasks = tasks_done(start.as_int(), end.as_int());
    } catch (const std::exception& error) {  // the debrief never stops a session ending
        log::error("fart.sessions", std::string("tasks for the debrief: ") + error.what());
    }
    last_ = entry;
    last_.set("planned", json::py_round_int(planned));
    last_.set("tasks", tasks);
    last_.set("apps", nullptr);  // host.focus(): the fixture keeps no focus tracker (the real ones are stage 3a)
    // Do Not Disturb back first, so the end is heard.
    if (py::truthy(get(current_, "dnd")) && host_.dnd()) host_.set_dnd(false);
    if (completed) host_.alert("Session", get(current_, "preset").as_string() + " session complete", "session.end");
    current_ = json::Value();
    scheduler_.cancel("session.end");
    persist();
    on_change();
    on_guard();
}

void Sessions::attach(Server& server) {
    server.topic("session", [this] { return snapshot(); });
    on_change = [&server] { server.publish("session"); };
    server.op("session.start", [this](Client&, const Args& a) { return start(a["preset"], a["seconds"]); });
    server.op("session.end", [this](Client&, const Args&) { return end(); });
    server.op("session.dismiss", [this](Client&, const Args&) { return dismiss(); });
}

}  // namespace fart
