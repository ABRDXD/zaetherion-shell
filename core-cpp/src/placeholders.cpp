#include "placeholders.h"

namespace fart {

Placeholders::Placeholders(Server& server) : server_(server) {
    server.topic("tasks", [this] { return tasks_snapshot(); });
    server.op("task.add", [this](Client&, const Args& args) {
        const json::Value& text = args["text"];
        if (!text.is_string()) throw bad_args("text must be text");
        texts_.push_back(text.as_string());
        server_.publish("tasks");
        return json::Value(json::Object{{"placeholder", true}});
    });
}

json::Value Placeholders::tasks_snapshot() const {
    json::Array texts(texts_.begin(), texts_.end());
    return json::Object{{"placeholder", "stage 0: in memory only; stage 1 ports core/tasks.py"}, {"texts", std::move(texts)}};
}

json::Value Placeholders::status_part(const std::string&) const { return json::Object{}; }

}  // namespace fart
