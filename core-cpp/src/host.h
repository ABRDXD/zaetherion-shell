// The core's route to the host (core/host.py) and the sound-cue gate for alerts (core/sfx.py, alert cues only).
//
// Host profiles: only the fixture is here (adapters/fixture/core.py), which records each command instead of
// running it, appending it to FART_FIXTURE_LOG as one JSON line. The real profiles are stage 3a; until then
// main.cpp refuses any other FART_HOST.
#pragma once

#include "clock.h"
#include "json.h"
#include "protocol.h"

#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace fart {

using Argv = std::vector<std::string>;

class FixtureProfile {
public:
    FixtureProfile();
    std::string name() const { return "fixture"; }
    std::pair<bool, double> sfx() const { return {muted, volume}; }  // (muted, volume)
    bool dnd() const { return dnd_on; }
    bool set_dnd(bool on);
    std::optional<Argv> play_command(const std::string& cue, double gain) const;
    Argv notify_command(const std::string& summary, const std::string& body) const;
    void record(const Argv& argv);

    bool muted = false;
    double volume = 1.0;
    bool dnd_on = false;

private:
    std::string log_;  // FART_FIXTURE_LOG, or empty
};

class Sfx;

class Host {
public:
    FixtureProfile profile;
    Sfx* sfx = nullptr;  // the core's gate (Core sets it)

    std::string name() const { return profile.name(); }
    void run(const std::optional<Argv>& argv, const std::string& key = "");  // without waiting; key: stoppable
    void stop(const std::string& key);
    bool dnd() const { return profile.dnd(); }
    bool set_dnd(bool on) { return profile.set_dnd(on); }
    // Notify always; the cue goes through the sfx gate. `sound` overrides FART's own setting.
    void alert(const std::string& summary, const std::string& body, const std::string& cue = "",
               std::optional<bool> sound = std::nullopt);

private:
    std::vector<std::string> players_;  // keys of stoppable commands recorded (the fixture records, never runs)
};

// core/sfx.py's gate and event for the alert cues (timer.done, pomodoro.phase, session.end). The sfx topic, the
// per-cue switches (sfx.json) and the UI and notification cues are stage 3a.
class Sfx {
public:
    Sfx(Host& host, const Clock& clock, std::function<bool()> sound_on, std::function<bool()> session_active);
    std::function<void(const json::Value&)> on_cue = [](const json::Value&) {};
    json::Value emit(const std::string& name, std::optional<bool> sound = std::nullopt);

private:
    Host& host_;
    const Clock& clock_;
    std::function<bool()> sound_on_, session_active_;
    int64_t seq_ = 0;
};

}  // namespace fart
