// The core's log, in the Python core's shape: "2026-11-23 18:04:05,123 INFO fart.core: message".
#pragma once

#include <string>

namespace fart::log {

// Keeps the last 256 KiB of an existing log, then appends (mode 0600); FART_LOG=- writes to stderr instead.
// Before setup, lines go to stderr.
void setup(const std::string& path);

void info(const char* name, const std::string& message);
void warning(const char* name, const std::string& message);
void error(const char* name, const std::string& message);

}  // namespace fart::log
