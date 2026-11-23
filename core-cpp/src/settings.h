// Two small settings owners, published as topics and kept in the state directory:
//   Island (core/island.py, Z155/Z201/Z207): one form/edge/placement/screen/rest/notice for every surface.
//   Clips  (core/clips.py, Z184): quick paste's settings; the history itself is DMS's (Z202).
#pragma once

#include "json.h"
#include "protocol.h"

#include <filesystem>
#include <functional>
#include <string>
#include <vector>

namespace fart {

class Island {
public:
    explicit Island(const std::filesystem::path& state_dir);
    std::function<void()> on_change = [] {};

    json::Value snapshot() const;
    // set_rest(**modes) and set(**changes): names in the order given, as keyword arguments arrive.
    json::Value set_rest(const json::Object& modes);
    json::Value set(const json::Object& changes);
    void attach(Server& server);

    // REST_PRESETS and CHOICES, for the island verb.
    static const std::vector<std::pair<std::string, json::Object>>& rest_presets();
    static const std::vector<std::string>& rest_modes(const std::string& item);  // empty: not an item
    static const std::vector<std::pair<std::string, std::vector<json::Value>>>& choices();

private:
    std::filesystem::path path_;
    json::Value state_;
    static bool valid(const std::string& key, const json::Value& value);
};

class Clips {
public:
    explicit Clips(const std::filesystem::path& state_dir);
    std::function<void()> on_change = [] {};

    json::Value snapshot() const { return state_; }
    json::Value set(const json::Value& key, const json::Value& value);
    void attach(Server& server);

private:
    std::filesystem::path path_;
    json::Value state_;
};

}  // namespace fart
