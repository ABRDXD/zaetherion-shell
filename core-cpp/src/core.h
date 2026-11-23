// Wires the core's subsystems to the protocol (core/app.py): the connection ops (hello, status, shutdown), the
// `core` and `supervisor` topics, the ported subsystems, and placeholders for what is not ported yet.
#pragma once

#include "clock.h"
#include "json.h"
#include "placeholders.h"
#include "protocol.h"
#include "settings.h"
#include "tasks.h"

#include <filesystem>

#include <functional>
#include <string>

namespace fart {

inline constexpr const char* VERSION = "0.2.0";  // core/app.py VERSION: the same core, whichever language

class Core {
public:
    Core(const Clock& clock, std::string host, const std::filesystem::path& state_dir, Server& server, std::function<void()> stop);

    json::Value core_snapshot() const;
    json::Value status() const;

private:
    const Clock& clock_;
    std::string host_;
    Server& server_;
    std::function<void()> stop_;
    Now started_;
    Tasks tasks_;
    Island island_;
    Clips clips_;
    Placeholders placeholders_;

    json::Value hello(Client& peer, const Args& args);
};

long rss_kib();

}  // namespace fart
