#include "tasks.h"

#include "log.h"
#include "pystr.h"
#include "store.h"

#include <algorithm>
#include <vector>

namespace fart {

namespace {

const char* kDefault = "default";
constexpr size_t kMaxText = 1000, kMaxName = 64;

std::string new_id(const char* prefix) { return prefix + store::random_hex(4); }

json::Value empty_state() {
    return json::Object{{"version", 1},
                        {"lists", json::Array{json::Object{{"id", kDefault}, {"name", "Tasks"}}}},
                        {"tasks", json::Array{}}};
}

// DUE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$") with re.match: \d is any Unicode decimal digit and
// `$` also matches before a final "\n".
bool due_shape(const std::string& text) {
    std::vector<uint32_t> cps;
    for (size_t i = 0; i < text.size();) cps.push_back(py::next_code_point(text, i));
    auto shape = [&](size_t n) {
        static const char date[] = "dddd-dd-dd", stamp[] = "dddd-dd-ddTdd:dd";
        const char* want = n == 10 ? date : n == 16 ? stamp : nullptr;
        if (!want) return false;
        for (size_t k = 0; k < n; ++k)
            if (want[k] == 'd' ? py::decimal(cps[k]) < 0 : cps[k] != static_cast<uint32_t>(want[k])) return false;
        return true;
    };
    if (shape(cps.size())) return true;
    return !cps.empty() && cps.back() == '\n' && shape(cps.size() - 1);
}

bool leap(int y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0; }
int days_in(int y, int m) {
    static const int days[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    return m == 2 && leap(y) ? 29 : days[m - 1];
}

// datetime.fromisoformat() on what due_shape lets through: ASCII digits only, real dates in years 1..9999,
// hours 0..23, and 24:00 as the next midnight (refused when that is past 9999-12-31).
bool real_date(const std::string& text) {
    if (text.size() != 10 && text.size() != 16) return false;
    for (size_t k : {0, 1, 2, 3, 5, 6, 8, 9})
        if (text[k] < '0' || text[k] > '9') return false;
    int y = std::stoi(text.substr(0, 4)), m = std::stoi(text.substr(5, 2)), d = std::stoi(text.substr(8, 2));
    if (y < 1 || m < 1 || m > 12 || d < 1 || d > days_in(y, m)) return false;
    if (text.size() == 10) return true;
    for (size_t k : {11, 12, 14, 15})
        if (text[k] < '0' || text[k] > '9') return false;
    int hh = std::stoi(text.substr(11, 2)), mm = std::stoi(text.substr(14, 2));
    if (hh == 24 && mm == 0) return !(y == 9999 && m == 12 && d == 31);
    return hh <= 23 && mm <= 59;
}

bool is_int(const json::Value& v) { return v.is_int() || v.type() == json::Value::Type::BigInt; }
bool is_int_like(const json::Value& v) { return is_int(v) || v.is_bool(); }  // isinstance(v, int)

// _check_index: None, or a non-negative int that isn't a bool.
void check_index(const json::Value& index) {
    if (index.is_null()) return;
    bool negative = index.is_int() ? index.as_int() < 0
                                   : index.type() == json::Value::Type::BigInt && index.as_bigint().digits[0] == '-';
    if (index.is_bool() || !is_int(index) || negative) throw bad_args("index must be a non-negative integer");
}

const json::Value& get(const json::Value& object, std::string_view key) {  // dict.get(key)
    static const json::Value null;
    const json::Value* v = object.find(key);
    return v ? *v : null;
}

}  // namespace

std::string clean_text(const json::Value& text, size_t limit, const std::string& name) {
    std::string stripped = text.is_string() ? py::strip(text.as_string()) : std::string();
    if (!text.is_string() || stripped.empty()) throw bad_args(name + " must be non-empty text");
    if (py::length(stripped) > limit) throw bad_args(name + " is longer than " + std::to_string(limit) + " characters");
    return stripped;
}

json::Value clean_due(const json::Value& due) {
    if (due.is_null()) return due;
    if (!due.is_string() || !due_shape(due.as_string())) throw bad_args("due must be YYYY-MM-DD or YYYY-MM-DDTHH:MM");
    if (!real_date(due.as_string())) throw bad_args("due is not a real date");
    return due;
}

Tasks::Tasks(const Clock& clock, const std::filesystem::path& state_dir)
    : clock_(clock), path_(state_dir / "tasks.json"), todo_path_(state_dir / "todo.json") {
    state_ = load();
}

json::Value Tasks::load() {
    std::optional<json::Value> state;
    try {
        state = store::read_json(path_);
    } catch (const store::ValueError&) {
        log::error("fart.tasks", "tasks.json is invalid; kept aside as tasks.json.invalid");
        // The text itself, written as JSON (a string), as publish_new(path, path.read_text()) does.
        store::publish_new(path_.parent_path() / "tasks.json.invalid", json::Value(store::read_text(path_).value()));
        return fresh(empty_state());
    }
    if (state && state->is_object() && get(*state, "tasks").is_array()) {
        const json::Value& lists = get(*state, "lists");
        bool has_default = false;
        if (py::truthy(lists)) {
            if (!lists.is_array()) throw std::runtime_error("tasks.json: lists is not a list");
            for (const json::Value& entry : lists.as_array()) {  // any(): stops at the first default
                if (!entry.is_object()) throw std::runtime_error("tasks.json: a list entry is not an object");
                if (get(entry, "id").py_equals(json::Value(kDefault))) {
                    has_default = true;
                    break;
                }
            }
        }
        if (!has_default) {
            json::Array with{json::Object{{"id", kDefault}, {"name", "Tasks"}}};
            if (py::truthy(lists))
                for (const json::Value& entry : lists.as_array()) with.push_back(entry);
            state->set("lists", std::move(with));
        }
        return std::move(*state);
    }
    std::optional<json::Value> todo;
    try {
        todo = store::read_json(todo_path_);
    } catch (const store::ValueError&) {
        log::error("fart.tasks", "todo.json is invalid; not migrated and left untouched");
        return empty_state();
    }
    if (!todo || !todo->is_array()) return fresh(empty_state());
    json::Value migrated = empty_state();
    for (const json::Value& item : todo->as_array()) {
        if (!item.is_object() || !get(item, "content").is_string()) continue;
        std::string text = py::strip(get(item, "content").as_string());
        if (text.empty()) continue;
        const json::Value& done = get(item, "done");
        migrated["tasks"].as_array().push_back(json::Object{
            {"id", new_id("t")}, {"list", kDefault}, {"text", py::prefix(text, kMaxText)},
            {"done", done.is_bool() && done.as_bool()}, {"due", nullptr}, {"created", nullptr}, {"doneAt", nullptr}});
    }
    if (!store::publish_new(path_, migrated)) {  // a concurrent writer won; take its file
        auto theirs = store::read_json(path_);
        return theirs ? std::move(*theirs) : json::Value();
    }
    log::info("fart.tasks", "migrated " + std::to_string(migrated["tasks"].as_array().size()) + " tasks from todo.json into the default list");
    return migrated;
}

json::Value Tasks::fresh(json::Value state) {
    store::write_json(path_, state);
    return state;
}

void Tasks::commit() {
    store::write_json(path_, state_);
    on_change();
}

json::Value Tasks::snapshot() const {
    return json::Object{{"lists", *state_.find("lists")}, {"tasks", *state_.find("tasks")}};
}

json::Value Tasks::summary() const {
    int64_t open = 0, done = 0;
    for (const json::Value& t : state_.find("tasks")->as_array()) {
        const json::Value& d = get(t, "done");
        open += !py::truthy(d);
        done += d.is_int() ? d.as_int() : py::truthy(d);  // sum(t["done"]): bools count 1, ints their value
    }
    return json::Object{{"lists", static_cast<int64_t>(state_.find("lists")->as_array().size())}, {"open", open}, {"done", done}};
}

int64_t Tasks::done_between(int64_t start_ms, int64_t end_ms) const {
    int64_t n = 0;
    for (const json::Value& t : state_.find("tasks")->as_array()) {
        const json::Value& at = get(t, "doneAt");
        if (py::truthy(get(t, "done")) && at.is_int() && start_ms <= at.as_int() && at.as_int() <= end_ms) ++n;
    }
    return n;
}

json::Value& Tasks::find_list(const json::Value& list_id) {
    for (json::Value& entry : lists())
        if (get(entry, "id").py_equals(list_id)) return entry;
    throw OpError{"not-found", "no list " + py::repr_of(list_id)};
}

size_t Tasks::find_task(const json::Value& task_id) {
    auto& all = tasks();
    for (size_t i = 0; i < all.size(); ++i)
        if (get(all[i], "id").py_equals(task_id)) return i;
    throw OpError{"not-found", "no task " + py::repr_of(task_id)};
}

std::vector<size_t> Tasks::members(const json::Value& list_id) {
    std::vector<size_t> out;
    auto& all = tasks();
    for (size_t i = 0; i < all.size(); ++i)
        if (get(all[i], "list").py_equals(list_id)) out.push_back(i);
    return out;
}

void Tasks::insert(json::Value task, const json::Value& index) {
    auto in_list = members(get(task, "list"));
    check_index(index);
    auto& all = tasks();
    if (index.is_int() && static_cast<uint64_t>(index.as_int()) < in_list.size()) {
        all.insert(all.begin() + static_cast<long>(in_list[static_cast<size_t>(index.as_int())]), std::move(task));
    } else {
        size_t at = in_list.empty() ? all.size() : in_list.back() + 1;
        all.insert(all.begin() + static_cast<long>(at), std::move(task));
    }
}

int64_t Tasks::index_in_list(const json::Value& task) {
    auto in_list = members(get(task, "list"));
    for (size_t k = 0; k < in_list.size(); ++k)
        if (get(tasks()[in_list[k]], "id").py_equals(get(task, "id"))) return static_cast<int64_t>(k);
    throw std::runtime_error("task not in its own list");  // list.index's ValueError
}

json::Value Tasks::now_ms() const { return json::py_round_int(clock_.now().real * 1000); }

json::Value Tasks::add(const json::Value& text, const json::Value& list, const json::Value& due, const json::Value& index) {
    json::Value list_id = get(find_list(py::truthy(list) ? list : json::Value(kDefault)), "id");
    std::string id = new_id("t");
    std::string clean = clean_text(text);
    json::Value when = clean_due(due);
    json::Value task = json::Object{{"id", id}, {"list", list_id}, {"text", clean}, {"done", false},
                                    {"due", when}, {"created", now_ms()}, {"doneAt", nullptr}};
    insert(task, index);
    commit();
    return json::Object{{"task", task}};
}

json::Value Tasks::update(const json::Value& id, const json::Object& changes) {
    auto change = [&](std::string_view key) -> const json::Value* {
        for (const auto& m : changes)
            if (m.key == key) return &m.value;
        return nullptr;
    };
    static const json::Value null;
    const json::Value& text = change("text") ? *change("text") : null;
    const json::Value& done = change("done") ? *change("done") : null;
    const json::Value& list = change("list") ? *change("list") : null;
    size_t position = find_task(id);
    json::Value task = tasks()[position];
    if (!text.is_null()) task.set("text", clean_text(text));
    if (!done.is_null()) {
        if (!done.is_bool()) throw bad_args("done must be true or false");
        if (!done.py_equals(get(task, "done"))) {
            task.set("done", done);
            task.set("doneAt", done.as_bool() ? now_ms() : json::Value());
        }
    }
    if (const json::Value* due = change("due")) task.set("due", clean_due(*due));
    if (!list.is_null() && !list.py_equals(get(task, "list"))) {
        find_list(list);
        tasks().erase(tasks().begin() + static_cast<long>(position));
        task.set("list", list);
        insert(task, json::Value());
    } else {
        tasks()[position] = task;
    }
    commit();
    return json::Object{{"task", task}};
}

json::Value Tasks::move(const json::Value& id, const json::Value& index) {
    size_t position = find_task(id);
    json::Value task = tasks()[position];
    check_index(index);  // before removing, so a bad index can't drop the task
    tasks().erase(tasks().begin() + static_cast<long>(position));
    insert(task, index);
    commit();
    return json::Object{{"task", task}};
}

json::Value Tasks::remove(const json::Value& id) {
    size_t position = find_task(id);
    json::Value task = tasks()[position];
    int64_t index = index_in_list(task);
    tasks().erase(tasks().begin() + static_cast<long>(position));
    commit();
    return json::Object{{"task", task}, {"index", index}};
}

json::Value Tasks::restore(const json::Value& task, const json::Value& index) {
    auto valid_id = [](const json::Value& v) {  // re.fullmatch(r"t[0-9a-f]{8}", id)
        if (!v.is_string() || v.as_string().size() != 9 || v.as_string()[0] != 't') return false;
        return std::all_of(v.as_string().begin() + 1, v.as_string().end(), [](char c) {
            return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
        });
    };
    if (!task.is_object() || !valid_id(get(task, "id"))) throw bad_args("task must be a removed task");
    for (const json::Value& t : tasks())
        if (get(t, "id").py_equals(get(task, "id"))) throw OpError{"conflict", "that task still exists"};
    bool known = false;
    for (const json::Value& e : lists()) known = known || get(e, "id").py_equals(get(task, "list"));
    json::Value list_id = known ? get(task, "list") : json::Value(kDefault);
    std::string text = clean_text(get(task, "text"));
    const json::Value& done = get(task, "done");
    json::Value due = clean_due(get(task, "due"));
    const json::Value& created = get(task, "created");
    const json::Value& done_at = get(task, "doneAt");
    json::Value restored = json::Object{{"id", get(task, "id")}, {"list", list_id}, {"text", text},
                                        {"done", done.is_bool() && done.as_bool()}, {"due", due},
                                        {"created", is_int_like(created) ? created : json::Value()},
                                        {"doneAt", is_int_like(done_at) ? done_at : json::Value()}};
    insert(restored, index);
    commit();
    return json::Object{{"task", restored}};
}

json::Value Tasks::list_add(const json::Value& name) {
    std::string id = new_id("l");
    json::Value entry = json::Object{{"id", id}, {"name", clean_text(name, kMaxName, "name")}};
    lists().push_back(entry);
    commit();
    return json::Object{{"list", entry}};
}

json::Value Tasks::list_rename(const json::Value& id, const json::Value& name) {
    json::Value& entry = find_list(id);
    entry.set("name", clean_text(name, kMaxName, "name"));
    json::Value copy = entry;
    commit();
    return json::Object{{"list", copy}};
}

json::Value Tasks::list_remove(const json::Value& id) {
    if (id.py_equals(json::Value(kDefault))) throw OpError{"conflict", "the default list cannot be removed"};
    json::Value& entry = find_list(id);
    size_t entry_at = static_cast<size_t>(&entry - lists().data());
    json::Array moved, kept;
    for (json::Value& t : tasks()) (get(t, "list").py_equals(id) ? moved : kept).push_back(std::move(t));
    tasks() = std::move(kept);
    lists().erase(lists().begin() + static_cast<long>(entry_at));
    for (json::Value& t : moved) {
        t.set("list", kDefault);
        insert(std::move(t), json::Value());
    }
    commit();
    return json::Object{};
}

void Tasks::attach(Server& server) {
    server.topic("tasks", [this] { return snapshot(); });
    on_change = [&server] { server.publish("tasks"); };
    server.op("task.add", [this](Client&, const Args& a) { return add(a["text"], a["list"], a["due"], a["index"]); });
    server.op("task.update", [this](Client&, const Args& a) {
        // app.py _only(changes, "text", "done", "due", "list"): the unknown names, sorted
        std::vector<std::string> unknown;
        for (const auto& m : a.extra())
            if (m.key != "text" && m.key != "done" && m.key != "due" && m.key != "list") unknown.push_back(m.key);
        if (!unknown.empty()) {
            std::sort(unknown.begin(), unknown.end());
            std::string names;
            for (const auto& n : unknown) names += (names.empty() ? "" : ", ") + n;
            throw bad_args("unexpected " + names);
        }
        return update(a["id"], a.extra());
    });
    server.op("task.move", [this](Client&, const Args& a) { return move(a["id"], a["index"]); });
    server.op("task.remove", [this](Client&, const Args& a) { return remove(a["id"]); });
    server.op("task.restore", [this](Client&, const Args& a) { return restore(a["task"], a["index"]); });
    server.op("list.add", [this](Client&, const Args& a) { return list_add(a["name"]); });
    server.op("list.rename", [this](Client&, const Args& a) { return list_rename(a["id"], a["name"]); });
    server.op("list.remove", [this](Client&, const Args& a) { return list_remove(a["id"]); });
}

}  // namespace fart
