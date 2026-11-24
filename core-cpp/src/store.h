// Atomic, private JSON state files (core/store.py): the same bytes, the same temp names, the same failures.
#pragma once

#include "json.h"

#include <filesystem>
#include <optional>
#include <stdexcept>
#include <string>

namespace fart::store {

namespace fs = std::filesystem;

// Python's ValueError, as the callers catch it: a file that isn't UTF-8 (UnicodeDecodeError) or isn't JSON.
struct ValueError : std::runtime_error {
    using std::runtime_error::runtime_error;
};

// Path.read_text(): nullopt when missing; ValueError when not UTF-8; other I/O errors throw std::system_error.
// Universal newlines, as text mode reads: "\r\n" and "\r" become "\n".
std::optional<std::string> read_text(const fs::path& path);
// read_json: the parsed file, or nullopt when missing; ValueError(f"{path}: invalid JSON") when it isn't JSON.
std::optional<json::Value> read_json(const fs::path& path);
// write_json: through a private temp file (.NAME.PID.HEX.tmp, 0600, fsynced) renamed over the path; style store.
void write_json(const fs::path& path, const json::Value& value);
// publish_new: write only if the path doesn't exist yet; an existing file always wins (false).
bool publish_new(const fs::path& path, const json::Value& value);
// append_line: one compact line (style store) appended to a 0600 file.
void append_line(const fs::path& path, const json::Value& value);

std::string random_hex(size_t bytes);  // os.urandom(n).hex()

}  // namespace fart::store
