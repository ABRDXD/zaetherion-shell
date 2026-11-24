// The command line's grammar (core/command.py, docs/M5-COMMAND.md): one verb registry for the view's command line
// and the CLI. The registry is the Python core's (verb_table.inc, generated); the verbs whose subsystems are here
// act, the others answer "unported" until their stage lands, and so does anything that needs the view (a bare room
// verb, the launcher fallthrough), until view supervision (stage 2a).
#pragma once

#include "clock.h"
#include "json.h"
#include "protocol.h"
#include "sessions.h"
#include "settings.h"
#include "tasks.h"
#include "timers.h"

#include <filesystem>
#include <functional>
#include <map>
#include <string>
#include <vector>

namespace fart {

struct Verb {
    std::string name, domain, usage, summary;
    std::vector<std::string> examples, aliases;
    bool record = true;
};

// What a verb returns (core/verbs/base.py Result).
struct VerbResult {
    VerbResult() = default;
    VerbResult(std::string line, std::string tone = "ok", json::Value data = {})
        : line(std::move(line)), tone(std::move(tone)), data(std::move(data)) {}
    std::string line;
    std::string tone = "ok";  // ok | info | error
    json::Value data;         // null: {}
};

struct Subsystems {
    const Clock& clock;
    Timers& timers;
    Tasks& tasks;
    Sessions& sessions;
    Island& island;
};

class Commands {
public:
    Commands(Subsystems core, const std::filesystem::path& state_dir);

    json::Value run(const json::Value& line, const std::string& source, const json::Value& fallthrough, const json::Value& record);
    json::Value complete(const json::Value& text);
    json::Value recent(const json::Value& prefix, const json::Value& limit) const;
    void attach(Server& server);

    // (verb, ranked): an exact or unique match has no candidates; an ambiguous one has them ranked by history.
    std::pair<const Verb*, std::vector<const Verb*>> resolve(const std::string& word) const;

private:
    using Handler = std::function<VerbResult(const std::vector<std::string>& words)>;
    Subsystems core_;
    std::filesystem::path path_;
    std::vector<Verb> verbs_;
    std::vector<std::pair<std::string, size_t>> names_;  // every name and alias, in registry order -> verbs_ index
    std::map<std::string, Handler> handlers_;
    std::vector<std::string> history_;

    std::map<std::string, int64_t> counts() const;
    const Verb* exact(const std::string& name) const;
    void remember(const std::string& line);
    void install_handlers();
};

// Shared with the verbs and their tests: core/verbs/base.py and core/verbs/lines.py.
int64_t duration(const std::string& text, bool bare_minutes = true);  // throws Usage; an int, as Python's is
std::string clock_text(double seconds);                               // base.clock: 1:05, 0:42, 2:03:00
std::string timers_line(const json::Value& snapshot);
std::string session_line(const json::Value& snapshot, double now);

struct Usage {  // the line doesn't parse: the command line shows the message, the CLI exits 2
    std::string message;
};

}  // namespace fart
