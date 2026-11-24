#include "host.h"

#include <algorithm>
#include <charconv>
#include <cstdlib>
#include <fcntl.h>
#include <stdexcept>
#include <unistd.h>

namespace fart {

// --- the fixture profile -----------------------------------------------------------------------------------------

FixtureProfile::FixtureProfile() {
    if (const char* log = std::getenv("FART_FIXTURE_LOG")) log_ = log;
}

bool FixtureProfile::set_dnd(bool on) {
    dnd_on = on;
    record({"dnd", on ? "on" : "off"});
    return true;
}

std::optional<Argv> FixtureProfile::play_command(const std::string& cue, double gain) const {
    char buf[32];
    auto end = std::to_chars(buf, buf + sizeof buf, gain, std::chars_format::fixed, 3).ptr;  // f"{gain:.3f}"
    return Argv{"play", cue, std::string(buf, end)};
}

Argv FixtureProfile::notify_command(const std::string& summary, const std::string& body) const {
    return {"notify", summary, body};
}

void FixtureProfile::record(const Argv& argv) {
    if (log_.empty()) return;
    json::Array items(argv.begin(), argv.end());
    std::string line = json::dump(json::Value(std::move(items)), json::Style::Default) + "\n";  // json.dumps(argv)
    int fd = ::open(log_.c_str(), O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0666);
    if (fd < 0) return;
    ssize_t ignored = ::write(fd, line.data(), line.size());
    (void)ignored;
    ::close(fd);
}

// --- Host --------------------------------------------------------------------------------------------------------

void Host::run(const std::optional<Argv>& argv, const std::string& key) {
    if (!argv || argv->empty()) return;
    if (!key.empty()) stop(key);
    profile.record(*argv);  // a recording profile: host.py's `record` branch
    if (!key.empty()) players_.push_back(key);
}

void Host::stop(const std::string& key) {
    auto it = std::find(players_.begin(), players_.end(), key);
    if (it == players_.end()) return;
    players_.erase(it);
    profile.record({"stop", key});
}

void Host::alert(const std::string& summary, const std::string& body, const std::string& cue, std::optional<bool> sound) {
    run(profile.notify_command(summary, body));
    if (!cue.empty() && sfx) sfx->emit(cue, sound);
}

// --- Sfx (alerts) --------------------------------------------------------------------------------------------------

namespace {
struct AlertCue {
    const char* name;
    bool session;  // still audible while a session runs
};
constexpr AlertCue kAlerts[] = {{"timer.done", false}, {"pomodoro.phase", true}, {"session.end", true}};
}  // namespace

Sfx::Sfx(Host& host, const Clock& clock, std::function<bool()> sound_on, std::function<bool()> session_active)
    : host_(host), clock_(clock), sound_on_(std::move(sound_on)), session_active_(std::move(session_active)) {}

json::Value Sfx::emit(const std::string& name, std::optional<bool> sound) {
    const AlertCue* cue = nullptr;
    for (const auto& c : kAlerts)
        if (name == c.name) cue = &c;
    if (!cue) throw std::logic_error("cue " + name + " is not ported yet (stage 3a ports sfx)");
    // decide(): on, no session quieting it, the host not muted, not in DND.
    bool audible = true;
    json::Value reason;
    double gain = 0.0;
    bool on = sound ? *sound : sound_on_();
    if (!on) {
        audible = false, reason = "off";
    } else if (session_active_() && !cue->session) {
        audible = false, reason = "session";
    } else if (auto [muted, volume] = host_.profile.sfx(); muted || volume <= 0) {  // asked only now, as decide()
        audible = false, reason = "muted";
    } else if (host_.profile.dnd()) {
        audible = false, reason = "dnd";
    } else {
        gain = volume;
    }
    if (audible) {
        auto command = host_.profile.play_command(cue->name, gain);
        if (command) {
            host_.run(command);
        } else {
            audible = false, reason = "no-sound", gain = 0.0;
        }
    }
    ++seq_;
    json::Value event = json::Object{{"cue", cue->name}, {"seq", seq_}, {"at", json::py_round_int(clock_.now().real * 1000)},
                                     {"audible", audible}, {"reason", reason}, {"gain", json::py_round(gain, 3)}};
    on_cue(event);
    return event;
}

}  // namespace fart
