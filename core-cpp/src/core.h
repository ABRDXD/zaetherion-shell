// Wires the core's subsystems to the protocol (core/app.py). Stage 0: the connection ops (hello, status,
// shutdown), the `core` and `supervisor` topics, and the stage-0 placeholders (placeholders.h).
#pragma once

#include "clock.h"
#include "json.h"
#include "placeholders.h"
#include "protocol.h"

#include <functional>
#include <string>

namespace fart {

inline constexpr const char* VERSION = "0.2.0";  // core/app.py VERSION: the same core, whichever language

class Core {
public:
    Core(const Clock& clock, std::string host, Server& server, std::function<void()> stop);

    json::Value core_snapshot() const;
    json::Value status() const;

private:
    const Clock& clock_;
    std::string host_;
    Server& server_;
    std::function<void()> stop_;
    Now started_;
    Placeholders placeholders_;

    json::Value hello(Client& peer, const Args& args);
};

long rss_kib();

}  // namespace fart
