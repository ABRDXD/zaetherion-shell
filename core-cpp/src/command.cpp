#include "command.h"

#include "log.h"
#include "pystr.h"
#include "store.h"

#include <algorithm>
#include <cmath>
#include <ctime>
#include <stdexcept>

namespace fart {

namespace {

const char kVerbTable[] =
#include "verb_table.inc"
    ;

constexpr size_t kMaxLine = 1000;
constexpr size_t kHistory = 100;

const json::Value& get(const json::Value& object, std::string_view key) {
    static const json::Value null;
    const json::Value* v = object.is_object() ? object.find(key) : nullptr;
    return v ? *v : null;
}

json::Value error_result(const std::string& code, const std::string& message) {
    return json::Object{{"ok", false}, {"tone", "error"}, {"code", code}, {"line", message}};
}

std::string join(const std::vector<std::string>& words, const std::string& sep) {
    std::string out;
    for (size_t k = 0; k < words.size(); ++k) out += (k ? sep : "") + words[k];
    return out;
}

std::string common_prefix(const std::vector<std::string>& names) {  // os.path.commonprefix
    if (names.empty()) return "";
    auto [lo, hi] = std::minmax_element(names.begin(), names.end());
    size_t n = 0;
    while (n < lo->size() && n < hi->size() && (*lo)[n] == (*hi)[n]) ++n;
    return lo->substr(0, n);
}

// Something only the view can do (a room, the launcher): view supervision is stage 2a.
struct NeedsView {
    std::string what;
};

// --- big decimal ints, for durations typed with more digits than 64 bits hold --------------------------------------

std::string digits_of(const std::string& text) {  // re's \d+ text as ASCII digits, leading zeros dropped
    std::string out;
    for (size_t i = 0; i < text.size();) out += static_cast<char>('0' + py::decimal(py::next_code_point(text, i)));
    size_t nz = out.find_first_not_of('0');
    return nz == std::string::npos ? "0" : out.substr(nz);
}
std::string big_mul(const std::string& a, int m) {
    std::string out;
    int carry = 0;
    for (auto it = a.rbegin(); it != a.rend(); ++it) {
        int v = (*it - '0') * m + carry;
        out += static_cast<char>('0' + v % 10);
        carry = v / 10;
    }
    while (carry) {
        out += static_cast<char>('0' + carry % 10);
        carry /= 10;
    }
    while (out.size() > 1 && out.back() == '0') out.pop_back();
    return {out.rbegin(), out.rend()};
}
std::string big_add(const std::string& a, const std::string& b) {
    std::string out;
    int carry = 0;
    for (size_t k = 0; k < std::max(a.size(), b.size()) || carry; ++k) {
        int v = carry + (k < a.size() ? a[a.size() - 1 - k] - '0' : 0) + (k < b.size() ? b[b.size() - 1 - k] - '0' : 0);
        out += static_cast<char>('0' + v % 10);
        carry = v / 10;
    }
    while (out.size() > 1 && out.back() == '0') out.pop_back();
    return {out.rbegin(), out.rend()};
}
json::Value int_value(const std::string& digits) {
    if (digits.size() <= 18) return std::stoll(digits);
    return json::BigInt{digits};
}

// Big-capable duration; duration() below is its int64 face for the verbs' own arithmetic.
json::Value duration_value(const std::string& text, bool bare_minutes) {
    std::vector<uint32_t> cps;
    for (size_t i = 0; i < text.size();) cps.push_back(py::next_code_point(text, i));
    auto digit_run = [&](size_t at) {
        size_t end = at;
        while (end < cps.size() && py::decimal(cps[end]) >= 0) ++end;
        return end;
    };
    auto text_of = [&](size_t from, size_t to) {
        std::string out;
        for (size_t k = from; k < to; ++k) py::append_utf8(out, cps[k]);
        return digits_of(out);
    };
    if (!cps.empty() && digit_run(0) == cps.size()) return int_value(big_mul(text_of(0, cps.size()), bare_minutes ? 60 : 1));
    // (?:(?P<h>\d+)h)?(?:(?P<m>\d+)(?:m|$))?(?:(?P<s>\d+)s)?, fullmatch: each part takes its whole digit run or nothing.
    size_t at = 0;
    std::string h, m, s;
    auto part = [&](char unit, bool end_ok, std::string& into) {
        size_t end = digit_run(at);
        if (end == at) return;
        if (end < cps.size() && cps[end] == static_cast<uint32_t>(unit)) {
            into = text_of(at, end);
            at = end + 1;
        } else if (end_ok && end == cps.size()) {
            into = text_of(at, end);
            at = end;
        }
    };
    part('h', false, h);
    part('m', true, m);
    part('s', false, s);
    if (at != cps.size() || (h.empty() && m.empty() && s.empty()))
        throw Usage{"not a duration: " + py::repr(text) + " (try 25, 90s, 25m or 1h30)"};
    std::string total = big_add(big_add(big_mul(h.empty() ? "0" : h, 3600), big_mul(m.empty() ? "0" : m, 60)), s.empty() ? "0" : s);
    return int_value(total);
}

// --- dates for !due words ---------------------------------------------------------------------------------------

const char* kWeekdays[] = {"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"};
const char* kDayAbbrev[] = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"};
const char* kMonthAbbrev[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

int weekday(int64_t days) { return static_cast<int>(((days + 3) % 7 + 7) % 7); }  // 1970-01-01 was a Thursday

std::string iso(int64_t days) {
    Date d = civil(days);
    char buf[16];
    std::snprintf(buf, sizeof buf, "%04d-%02d-%02d", d.year, d.month, d.day);
    return buf;
}

// re.fullmatch(r"\d{4}-\d{2}-\d{2}(t\d{2}:\d{2})?", word) on the lowered word, with re's Unicode \d.
bool due_text(const std::string& word) {
    std::vector<uint32_t> cps;
    for (size_t i = 0; i < word.size();) cps.push_back(py::next_code_point(word, i));
    const char* shape = cps.size() == 10 ? "dddd-dd-dd" : cps.size() == 16 ? "dddd-dd-ddtdd:dd" : nullptr;
    if (!shape) return false;
    for (size_t k = 0; k < cps.size(); ++k)
        if (shape[k] == 'd' ? py::decimal(cps[k]) < 0 : cps[k] != static_cast<uint32_t>(shape[k])) return false;
    return true;
}

std::string resolve_due(const std::string& raw, int64_t today) {
    std::string word = py::lower(raw);
    if (word == "today" || word == "tod") return iso(today);
    if (word == "tomorrow" || word == "tom" || word == "tmr") return iso(today + 1);
    for (int index = 0; index < 7; ++index) {
        std::string name = kWeekdays[index];
        if (py::length(word) >= 3 && name.rfind(word, 0) == 0) {
            // The next one: !fri on a Friday is a week away (!today is today).
            int ahead = ((index - weekday(today) - 1) % 7 + 7) % 7 + 1;
            return iso(today + ahead);
        }
    }
    // \+(\d{1,3})([dw]), fullmatch
    std::vector<uint32_t> cps;
    for (size_t i = 0; i < word.size();) cps.push_back(py::next_code_point(word, i));
    if (cps.size() >= 3 && cps.size() <= 5 && cps[0] == '+' && (cps.back() == 'd' || cps.back() == 'w')) {
        bool digits = true;
        int64_t n = 0;
        for (size_t k = 1; k + 1 < cps.size(); ++k) {
            int d = py::decimal(cps[k]);
            digits = digits && d >= 0;
            n = n * 10 + std::max(d, 0);
        }
        if (digits) return iso(today + n * (cps.back() == 'w' ? 7 : 1));
    }
    if (due_text(word)) {
        std::string upper;
        for (uint32_t cp : cps) py::append_utf8(upper, cp == 't' ? 'T' : cp);  // word.upper(): only the t changes
        return upper;  // validated by the task store
    }
    throw Usage{"not a due date: !" + word + " (try !today, !tomorrow, !fri, !+3d or !2026-11-12)"};
}

// datetime.fromisoformat(due).strftime("%a %-d %b" + (" %H:%M" if "T" in due else "")), C locale names. A due has
// passed the task store, so it is ASCII; 24:00 is the next midnight.
std::string due_label(const std::string& due) {
    int y = std::stoi(due.substr(0, 4)), m = std::stoi(due.substr(5, 2)), d = std::stoi(due.substr(8, 2));
    int64_t days = days_of(y, m, d);
    int hh = 0, mm = 0;
    bool timed = due.find('T') != std::string::npos;
    if (timed) {
        hh = std::stoi(due.substr(11, 2));
        mm = std::stoi(due.substr(14, 2));
        if (hh == 24) {
            hh = 0;
            ++days;
        }
    }
    Date date = civil(days);
    std::string out = std::string(kDayAbbrev[(weekday(days))]) + " " + std::to_string(date.day) + " " + kMonthAbbrev[date.month - 1];
    if (timed) {
        char buf[8];
        std::snprintf(buf, sizeof buf, " %02d:%02d", hh, mm);
        out += buf;
    }
    return out;
}

std::string number_text(const json::Value& v) { return v.is_float() ? json::py_repr(v.as_float()) : py::str_of(v); }

json::Value floordiv_1000(const json::Value& v) {  // noticeMs // 1000
    if (v.is_float()) return std::floor(v.as_float() / 1000);
    int64_t n = py::int_of(v);
    return n >= 0 ? n / 1000 : -((-n + 999) / 1000);
}

}  // namespace

// --- shared helpers ----------------------------------------------------------------------------------------------

int64_t duration(const std::string& text, bool bare_minutes) {
    json::Value v = duration_value(text, bare_minutes);
    if (!v.is_int()) throw std::runtime_error("duration beyond 64 bits");
    return v.as_int();
}

std::string clock_text(double seconds) {
    int64_t s = std::max<int64_t>(0, json::py_round_int(seconds).as_int());
    int64_t hours = s / 3600, rest = s % 3600;
    char buf[48];
    if (hours) std::snprintf(buf, sizeof buf, "%lld:%02lld:%02lld", static_cast<long long>(hours), static_cast<long long>(rest / 60),
                             static_cast<long long>(rest % 60));
    else std::snprintf(buf, sizeof buf, "%lld:%02lld", static_cast<long long>(rest / 60), static_cast<long long>(rest % 60));
    return buf;
}

std::string timers_line(const json::Value& snap) {
    std::vector<std::string> parts;
    const json::Value &p = *snap.find("pomodoro"), &s = *snap.find("stopwatch"), &c = *snap.find("countdown");
    auto num = [](const json::Value& kind, const char* key) { return py::number(*kind.find(key)); };
    auto running = [](const json::Value& kind) { return kind.find("running")->as_bool(); };
    if (py::truthy(*c.find("done"))) {
        parts.push_back("countdown DONE");
    } else if (running(c) || num(c, "elapsed") > 0) {
        parts.push_back("countdown " + clock_text(num(c, "duration") - num(c, "elapsed")) + " left" + (running(c) ? "" : " (paused)"));
    }
    if (running(p) || num(p, "elapsed") > 0) {
        const json::Value& cycle = *p.find("cycle");
        json::Value next = cycle.is_float() ? json::Value(cycle.as_float() + 1) : json::Value(py::int_of(cycle) + 1);
        parts.push_back("pomodoro " + p.find("phase")->as_string() + " " + clock_text(num(p, "duration") - num(p, "elapsed")) +
                        " left, cycle " + number_text(next) + (running(p) ? "" : " (paused)"));
    }
    if (running(s) || num(s, "elapsed") > 0)
        parts.push_back("stopwatch " + clock_text(num(s, "elapsed")) + (running(s) ? "" : " (paused)"));
    return parts.empty() ? "idle" : join(parts, "; ");
}

std::string session_line(const json::Value& snap, double now) {
    const json::Value& active = *snap.find("active");
    if (!py::truthy(active)) return "none";
    return active.find("preset")->as_string() + ", " + clock_text(py::number(*active.find("until")) / 1000 - now) + " left";
}

// --- Commands ----------------------------------------------------------------------------------------------------

Commands::Commands(Subsystems core, const std::filesystem::path& state_dir) : core_(core), path_(state_dir / "history.json") {
    auto table = json::parse(kVerbTable);
    if (!table.value) throw std::logic_error("verb table unreadable");
    for (const json::Value& v : table.value->as_array()) {
        Verb verb{v.find("name")->as_string(), v.find("domain")->as_string(), v.find("usage")->as_string(),
                  v.find("summary")->as_string(), {}, {}, v.find("record")->as_bool()};
        for (const auto& e : v.find("examples")->as_array()) verb.examples.push_back(e.as_string());
        for (const auto& a : v.find("aliases")->as_array()) verb.aliases.push_back(a.as_string());
        verbs_.push_back(std::move(verb));
    }
    for (size_t k = 0; k < verbs_.size(); ++k) {
        names_.emplace_back(verbs_[k].name, k);
        for (const auto& alias : verbs_[k].aliases) names_.emplace_back(alias, k);
    }
    // History: the last 100 lines that ran from the command line, newest last, 0600.
    try {
        auto saved = store::read_json(path_);
        const json::Value& lines = saved && saved->is_object() ? get(*saved, "lines") : json::Value();
        if (lines.is_array())
            for (const json::Value& line : lines.as_array())
                if (line.is_string()) history_.push_back(line.as_string());
        if (history_.size() > kHistory) history_.erase(history_.begin(), history_.end() - static_cast<long>(kHistory));
    } catch (const store::ValueError&) {
        log::warning("fart.command", "history.json is not JSON; starting empty");
    }
    install_handlers();
}

const Verb* Commands::exact(const std::string& name) const {
    for (const auto& [n, k] : names_)
        if (n == name) return &verbs_[k];
    return nullptr;
}

std::map<std::string, int64_t> Commands::counts() const {
    std::map<std::string, int64_t> out;
    for (const auto& line : history_) {
        auto words = py::split(line);
        if (words.empty()) continue;
        if (const Verb* verb = exact(py::lower(words[0]))) ++out[verb->name];
    }
    return out;
}

std::pair<const Verb*, std::vector<const Verb*>> Commands::resolve(const std::string& raw) const {
    std::string word = py::lower(raw);
    if (const Verb* verb = exact(word)) return {verb, {}};
    std::vector<const Verb*> matches;
    for (const auto& [name, k] : names_)
        if (name.rfind(word, 0) == 0 && std::find(matches.begin(), matches.end(), &verbs_[k]) == matches.end())
            matches.push_back(&verbs_[k]);
    if (matches.size() <= 1) return {matches.empty() ? nullptr : matches[0], {}};
    auto count = counts();
    auto of = [&](const Verb* v) {
        auto it = count.find(v->name);
        return it == count.end() ? int64_t{0} : it->second;
    };
    std::vector<const Verb*> ranked = matches;
    std::stable_sort(ranked.begin(), ranked.end(), [&](const Verb* a, const Verb* b) {
        return of(a) != of(b) ? of(a) > of(b) : a->name < b->name;
    });
    int64_t top = of(ranked[0]), second = of(ranked[1]);
    if (top > 0 && top >= 2 * second) return {ranked[0], ranked};
    return {nullptr, ranked};
}

void Commands::remember(const std::string& line) {
    std::vector<std::string> kept;
    for (const auto& l : history_)
        if (l != line) kept.push_back(l);
    kept.push_back(line);
    if (kept.size() > kHistory) kept.erase(kept.begin(), kept.end() - static_cast<long>(kHistory));
    history_ = std::move(kept);
    json::Array lines(history_.begin(), history_.end());
    store::write_json(path_, json::Object{{"version", 1}, {"lines", std::move(lines)}});
}

json::Value Commands::recent(const json::Value& prefix, const json::Value& limit) const {
    bool int_limit = limit.is_int() || limit.type() == json::Value::Type::BigInt;
    bool positive = limit.is_int() ? limit.as_int() >= 1 : int_limit && limit.as_bigint().digits[0] != '-';
    if (!prefix.is_string() || !int_limit || !positive)
        throw OpError{"bad-args", "prefix must be a string and limit a positive integer"};
    json::Array lines;
    for (const auto& l : history_)
        if (l.rfind(prefix.as_string(), 0) == 0) lines.emplace_back(l);
    if (limit.is_int() && lines.size() > static_cast<uint64_t>(limit.as_int()))
        lines.erase(lines.begin(), lines.end() - static_cast<long>(limit.as_int()));
    return json::Object{{"lines", std::move(lines)}};
}

json::Value Commands::complete(const json::Value& text) {
    if (!text.is_string() || py::length(text.as_string()) > kMaxLine)
        throw OpError{"bad-args", "text must be a string of at most 1000 characters"};
    auto words = py::split(text.as_string());
    if (words.empty()) return json::Object{{"verb", nullptr}, {"usage", nullptr}, {"candidates", json::Array{}}, {"complete", ""}};
    auto [verb, ranked] = resolve(words[0]);
    std::vector<const Verb*> candidates = !ranked.empty() ? ranked : verb ? std::vector<const Verb*>{verb} : std::vector<const Verb*>{};
    json::Array listed;
    std::vector<std::string> names;
    for (const Verb* v : candidates) {
        listed.push_back(json::Object{{"name", v->name}, {"usage", v->usage}, {"summary", v->summary}});
        names.push_back(v->name);
    }
    return json::Object{{"verb", verb ? json::Value(verb->name) : json::Value()}, {"usage", verb ? json::Value(verb->usage) : json::Value()},
                        {"candidates", std::move(listed)},
                        {"complete", !ranked.empty() ? common_prefix(names) : verb ? verb->name : std::string()}};
}

json::Value Commands::run(const json::Value& line, const std::string& source, const json::Value& fallthrough_flag,
                          const json::Value& record_flag) {
    if (!line.is_string() || py::length(line.as_string()) > kMaxLine)
        throw OpError{"bad-args", "line must be a string of at most 1000 characters"};
    for (const auto& [name, flag] : {std::pair<const char*, const json::Value*>{"fallthrough", &fallthrough_flag}, {"record", &record_flag}})
        if (!flag->is_null() && !flag->is_bool()) throw OpError{"bad-args", std::string(name) + " must be a boolean"};
    bool fallthrough = fallthrough_flag.is_null() ? source == "view" : fallthrough_flag.as_bool();
    bool record = record_flag.is_null() ? source == "view" : record_flag.as_bool();
    auto words = py::split(line.as_string());
    if (words.empty()) return error_result("usage", "type a verb; ? lists them");
    auto [verb, ranked] = resolve(words[0]);
    if (!verb && !ranked.empty()) {
        std::vector<std::string> names;
        json::Array candidates;
        for (const Verb* v : ranked) {
            names.push_back(v->name);
            candidates.emplace_back(v->name);
        }
        return json::Object{{"ok", false}, {"tone", "info"}, {"code", "ambiguous"}, {"line", words[0] + ": " + join(names, " · ") + "?"},
                            {"candidates", std::move(candidates)}, {"complete", common_prefix(names)}};
    }
    if (!verb) {
        if (!fallthrough) return error_result("usage", "unknown verb " + py::repr(words[0]) + "; ? lists them");
        // The launcher fallthrough folds the panel and opens the host launcher through the view.
        return error_result("unported", "the launcher fallthrough needs the view, which isn't in the C++ core yet");
    }
    std::vector<std::string> rest(words.begin() + 1, words.end());
    auto failed = [&](const std::string& code, const std::string& message) {
        json::Value out = error_result(code, message);
        out.set("verb", verb->name);
        return out;
    };
    VerbResult result;
    auto handler = handlers_.find(verb->name);
    if (handler == handlers_.end()) return failed("unported", verb->name + " isn't in the C++ core yet");
    try {
        result = handler->second(rest);
    } catch (const Usage& error) {
        return failed("usage", error.message);
    } catch (const OpError& error) {
        return failed(error.code, error.message);
    } catch (const NeedsView& need) {
        return failed("unported", need.what + " needs the view, which isn't in the C++ core yet");
    }
    if (record && verb->record) remember(join(words, " "));
    return json::Object{{"ok", true}, {"tone", result.tone}, {"line", result.line}, {"verb", verb->name},
                        {"data", result.data.is_null() || !py::truthy(result.data) ? json::Value(json::Object{}) : result.data}};
}

// --- the verbs -------------------------------------------------------------------------------------------------------

void Commands::install_handlers() {
    Timers& timers = core_.timers;
    auto timers_result = [&timers] { return VerbResult{timers_line(timers.snapshot())}; };
    auto start_focus = [&timers, timers_result](const std::vector<std::string>& words) {
        if (words.size() > 1) throw Usage{"focus [minutes]"};
        timers.start("pomodoro", json::Value(), words.empty() ? json::Value() : duration_value(words[0], true));
        return timers_result();
    };
    const std::string tim_usage = "tim <25 | 90s | 1h30 | focus [min] | sw | lap | pause | stop>";

    handlers_["tim"] = [&timers, timers_result, start_focus, tim_usage](const std::vector<std::string>& words) {
        if (words.empty()) throw NeedsView{"opening Timers"};
        std::string verb = py::lower(words[0]);
        std::vector<std::string> rest(words.begin() + 1, words.end());
        if (verb == "focus") return start_focus(rest);
        if (!rest.empty()) throw Usage{tim_usage};
        if (verb == "sw") {
            timers.toggle("stopwatch");
        } else if (verb == "lap") {
            timers.lap();
        } else if (verb == "pause") {
            for (const auto& kind : timers.running()) timers.toggle(kind);
        } else if (verb == "stop") {
            auto running = timers.running();
            timers.ack(json::Value());
            for (const auto& kind : running) timers.reset(kind);
        } else {
            timers.start("countdown", duration_value(verb, true), json::Value());
        }
        return timers_result();
    };
    handlers_["focus"] = start_focus;
    handlers_["sw"] = [&timers, timers_result](const std::vector<std::string>& words) {
        if (!words.empty()) throw Usage{"sw takes no arguments"};
        timers.toggle("stopwatch");
        return timers_result();
    };

    handlers_["task"] = [this](const std::vector<std::string>& words) {
        if (words.empty()) throw NeedsView{"opening Tasks"};
        std::vector<std::string> text;
        std::optional<std::string> list_name, due;
        for (const auto& word : words) {
            if (word[0] == '@' && word.size() > 1) {
                if (list_name) throw Usage{"one @list per task"};
                list_name = word.substr(1);
            } else if (word[0] == '!' && word.size() > 1) {
                if (due) throw Usage{"one !due per task"};
                due = resolve_due(word.substr(1), local_day_at(core_.clock.now().real));
            } else {
                text.push_back(word);
            }
        }
        if (text.empty()) throw Usage{"task <text> [@list] [!today | !tomorrow | !fri | !+3d | !2026-11-12]"};
        json::Value lists = *core_.tasks.snapshot().find("lists");
        json::Value target = lists.as_array()[0];
        if (list_name) {
            const json::Value* found = nullptr;
            for (const json::Value& l : lists.as_array()) {
                const json::Value& name = get(l, "name");
                if ((name.is_string() && py::lower(name.as_string()) == py::lower(*list_name)) ||
                    get(l, "id").py_equals(json::Value(*list_name))) {
                    found = &l;
                    break;
                }
            }
            if (!found) {
                std::vector<std::string> names;
                for (const json::Value& l : lists.as_array()) names.push_back(py::str_of(get(l, "name")));
                throw OpError{"not-found", "no list named " + py::repr(*list_name) + "; lists: " + join(names, ", ")};
            }
            target = *found;
        }
        json::Value added = *core_.tasks.add(join(text, " "), get(target, "id"), due ? json::Value(*due) : json::Value(), json::Value())
                                 .find("task");
        const json::Value& when = get(added, "due");
        std::string line = "added to " + py::str_of(get(target, "name"));
        if (py::truthy(when)) line += ", due " + due_label(when.as_string());
        return VerbResult{line, "ok", json::Object{{"id", get(added, "id")}, {"list", get(target, "id")}, {"due", when}}};
    };

    handlers_["island"] = [this](const std::vector<std::string>& words) {
        Island& settings = core_.island;
        auto line = [](const json::Value& state) {
            const json::Value& screen = get(state, "screen");
            std::vector<std::string> rest;
            for (const auto& m : get(state, "rest").as_object()) rest.push_back(m.key + ":" + py::str_of(m.value));
            return "> ISLAND · " + py::upper_ascii(py::str_of(get(state, "form"))) + " · " + py::upper_ascii(py::str_of(get(state, "edge"))) +
                   " · " + py::upper_ascii(py::str_of(get(state, "placement"))) + " · " +
                   (py::truthy(screen) ? py::str_of(screen) : std::string("focused screen")) + " · REST " +
                   py::upper_ascii(join(rest, " ")) + " · NOTICE " + number_text(floordiv_1000(get(state, "noticeMs"))) + " S";
        };
        const std::string usage = "island [fluid | angular | top | bottom | notch | floating | screen <name> | screen auto"
                                  " | rest <today|a|b|c> | rest <power|network|battery|inbox> <mode> | notice <1|2|3|5>]";
        if (words.empty()) return VerbResult{line(settings.snapshot()), "info"};
        std::string first = py::lower(words[0]);
        if (first == "screen" && words.size() == 2) {
            std::string name = words[1];
            return VerbResult{line(settings.set(json::Object{{"screen", py::lower(name) == "auto" ? std::string() : name}}))};
        }
        static const std::pair<const char*, int64_t> notice[] = {{"1", 1000}, {"2", 2000}, {"3", 3000}, {"5", 5000}};
        if (first == "notice" && words.size() == 2)
            for (const auto& [word, ms] : notice)
                if (words[1] == word) return VerbResult{line(settings.set(json::Object{{"noticeMs", ms}}))};
        if (first == "rest" && words.size() == 2)
            for (const auto& [name, modes] : Island::rest_presets())
                if (py::lower(words[1]) == name) return VerbResult{line(settings.set_rest(modes))};
        if (first == "rest" && words.size() == 3 && !Island::rest_modes(py::lower(words[1])).empty())
            return VerbResult{line(settings.set_rest(json::Object{{py::lower(words[1]), py::lower(words[2])}}))};
        if (words.size() == 1)
            for (const auto& [key, values] : Island::choices())
                if (key != "noticeMs")
                    for (const auto& value : values)
                        if (value.as_string() == first) return VerbResult{line(settings.set(json::Object{{key, first}}))};
        throw Usage{usage};
    };

    handlers_["session"] = [this](const std::vector<std::string>& words) {
        Sessions& sessions = core_.sessions;
        if (words.empty()) return VerbResult{session_line(sessions.snapshot(), core_.clock.now().real), "info"};
        if (words.size() == 1 && py::lower(words[0]) == "end") return VerbResult{session_line(sessions.end(), core_.clock.now().real)};
        static const char* presets[] = {"focus", "deep", "study", "read"};
        if (words.size() == 1)
            for (const char* p : presets)
                if (py::lower(words[0]) == p) return VerbResult{session_line(sessions.start(py::lower(words[0]), json::Value()), core_.clock.now().real)};
        if (words.size() != 2) throw Usage{"session <preset> [duration] | session end (presets: focus, deep, study, read)"};
        json::Value seconds = duration_value(words[1], true);
        return VerbResult{session_line(sessions.start(py::lower(words[0]), seconds), core_.clock.now().real)};
    };

    handlers_["?"] = [this](const std::vector<std::string>& words) {
        if (!words.empty()) {
            auto [verb, ranked] = resolve(words[0]);
            if (!verb) throw Usage{"no verb " + py::repr(words[0]) + "; ? lists them"};
            std::string aliases = verb->aliases.empty() ? "" : " (also " + join(verb->aliases, ", ") + ")";
            json::Array examples(verb->examples.begin(), verb->examples.end());
            return VerbResult{verb->usage + aliases + ": " + verb->summary + ". e.g. " + join(verb->examples, ", "), "info",
                              json::Object{{"verb", verb->name}, {"usage", verb->usage}, {"examples", std::move(examples)}}};
        }
        json::Value domains = json::Object{};
        for (const Verb& verb : verbs_) {
            if (!domains.find(verb.domain)) domains.set(verb.domain, json::Array{});
            domains[verb.domain].as_array().emplace_back(verb.name);
        }
        std::vector<std::string> lines;
        for (const auto& m : domains.as_object()) {
            std::vector<std::string> names;
            for (const auto& n : m.value.as_array()) names.push_back(n.as_string());
            lines.push_back(m.key + ": " + join(names, " "));
        }
        return VerbResult{join(lines, "\n"), "info", json::Object{{"domains", domains}}};
    };
}

void Commands::attach(Server& server) {
    server.op("cmd.run", [this](Client& peer, const Args& a) { return run(a["line"], peer.kind, a["fallthrough"], a["record"]); });
    server.op("cmd.complete", [this](Client&, const Args& a) { return complete(a["text"]); });
    server.op("cmd.history", [this](Client&, const Args& a) { return recent(a["prefix"], a["limit"]); });
}

}  // namespace fart
