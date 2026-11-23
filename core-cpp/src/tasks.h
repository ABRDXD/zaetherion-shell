// Task lists with due dates; the version 1 todo.json migrates once into the default list (core/tasks.py,
// docs/CORE.md §4). The state is kept as the parsed file, as the Python core keeps its dict, so keys this core
// doesn't know survive a write.
#pragma once

#include "clock.h"
#include "json.h"
#include "protocol.h"

#include <filesystem>
#include <functional>

namespace fart {

class Tasks {
public:
    Tasks(const Clock& clock, const std::filesystem::path& state_dir);

    std::function<void()> on_change = [] {};

    json::Value snapshot() const;
    json::Value summary() const;
    int64_t done_between(int64_t start_ms, int64_t end_ms) const;  // the session debrief: a count only

    json::Value add(const json::Value& text, const json::Value& list, const json::Value& due, const json::Value& index);
    // changes: the op's **kwargs, already limited to text, done, due and list (app.py _only)
    json::Value update(const json::Value& id, const json::Object& changes);
    json::Value move(const json::Value& id, const json::Value& index);
    json::Value remove(const json::Value& id);
    json::Value restore(const json::Value& task, const json::Value& index);
    json::Value list_add(const json::Value& name);
    json::Value list_rename(const json::Value& id, const json::Value& name);
    json::Value list_remove(const json::Value& id);

    void attach(Server& server);  // the task.* and list.* ops and the tasks topic

private:
    const Clock& clock_;
    std::filesystem::path path_, todo_path_;
    json::Value state_;

    json::Value load();
    json::Value fresh(json::Value state);
    void commit();
    json::Array& tasks() { return state_["tasks"].as_array(); }
    json::Array& lists() { return state_["lists"].as_array(); }
    json::Value& find_list(const json::Value& list_id);
    size_t find_task(const json::Value& task_id);
    std::vector<size_t> members(const json::Value& list_id);
    void insert(json::Value task, const json::Value& index);
    int64_t index_in_list(const json::Value& task);
    json::Value now_ms() const;
};

// core/tasks.py's validators, also used by the verbs: OpError bad-args with the Python words.
std::string clean_text(const json::Value& text, size_t limit = 1000, const std::string& name = "text");
json::Value clean_due(const json::Value& due);

}  // namespace fart
