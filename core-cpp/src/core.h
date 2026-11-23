// Wires the core's subsystems to the protocol (core/app.py): the connection ops (hello, status, shutdown), the
// `core` and `supervisor` topics, the ported subsystems, and placeholders for what is not ported yet.
#pragma once

#include "clock.h"
#include "host.h"
#include "json.h"
#include "placeholders.h"
#include "protocol.h"
#include "settings.h"
#include "tasks.h"
#include "timers.h"

#include <filesystem>

#include <functional>
#include <string>

namespace fart {

inline constexpr const char* VERSION = "0.2.0";  // core/app.py VERSION: the same core, whichever language

class Core {
public:
    Core(const Clock& clock, const std::filesystem::path& state_dir, Server& server, std::function<void()> stop);

    json::Value core_snapshot() const;
    json::Value status() const;

private:
    const Clock& clock_;
    Server& server_;
    std::function<void()> stop_;
    Now started_;
    Host host_;
    Scheduler scheduler_;
    Timers timers_;
    Tasks tasks_;
    Island island_;
    Clips clips_;
    Sfx sfx_;
    Placeholders placeholders_;
    bool sound_ = false;  // the timer sound setting the sfx snapshot last followed

    json::Value hello(Client& peer, const Args& args);
};

long rss_kib();

}  // namespace fart
