// PLACEHOLDERS for what isn't ported yet. Each goes when its stage lands; nothing here writes a file or reaches the
// host. The parity diff (tools/parity.py) shows each as a difference from the Python core, on purpose.
//
//   status sections   view, timers, notifications, overdrive, session: {} until ported.
//   every topic       offered from the op table with a {} snapshot until its port registers one.
#pragma once

#include "json.h"
#include "protocol.h"

#include <string>

namespace fart {

class Placeholders {
public:
    explicit Placeholders(Server&) {}
    json::Value status_part(const std::string&) const { return json::Object{}; }
};

}  // namespace fart
