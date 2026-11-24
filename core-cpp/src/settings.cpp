#include "settings.h"

#include "log.h"
#include "pystr.h"
#include "store.h"

namespace fart {

namespace {

json::Object rest_of(const char* power, const char* network, const char* battery, const char* inbox) {
    return {{"power", power}, {"network", network}, {"battery", battery}, {"inbox", inbox}};
}

std::string joined(const std::vector<std::string>& words) {
    std::string out;
    for (const auto& w : words) out += (out.empty() ? "" : ", ") + w;
    return out;
}

bool in(const json::Value& value, const std::vector<std::string>& options) {  // `value in (...)`: Python ==
    for (const auto& o : options)
        if (value.py_equals(json::Value(o))) return true;
    return false;
}

// read_json(path, {}) or {}, with a file that isn't JSON warned about and ignored.
json::Value saved_or_empty(const std::filesystem::path& path) {
    try {
        auto saved = store::read_json(path);
        if (saved && py::truthy(*saved)) return std::move(*saved);
    } catch (const store::ValueError& error) {
        log::warning(path.stem() == "island" ? "fart.island" : "fart.clips", std::string(error.what()) + "; using defaults");
    }
    return json::Object{};
}

}  // namespace

// --- Island ----------------------------------------------------------------------------------------------------

const std::vector<std::pair<std::string, json::Object>>& Island::rest_presets() {
    static const std::vector<std::pair<std::string, json::Object>> presets = {
        {"today", rest_of("always", "always", "always", "always")},
        {"a", rest_of("hover", "matters", "matters", "matters")},
        {"b", rest_of("hover", "always", "always", "dot")},
        {"c", rest_of("hover", "matters", "always", "unread")},
    };
    return presets;
}

const std::vector<std::string>& Island::rest_modes(const std::string& item) {
    static const std::vector<std::string> three = {"always", "matters", "hover"};
    static const std::vector<std::string> inbox = {"always", "matters", "unread", "dot", "hover"};
    static const std::vector<std::string> none;
    if (item == "power" || item == "network" || item == "battery") return three;
    if (item == "inbox") return inbox;
    return none;
}

const std::vector<std::pair<std::string, std::vector<json::Value>>>& Island::choices() {
    static const std::vector<std::pair<std::string, std::vector<json::Value>>> c = {
        {"form", {"angular", "fluid"}}, {"edge", {"top", "bottom"}}, {"placement", {"notch", "floating"}},
        {"noticeMs", {1000, 2000, 3000, 5000}}};
    return c;
}

bool Island::valid(const std::string& key, const json::Value& value) {
    if (key == "screen") return value.is_string() && py::length(value.as_string()) <= 64;
    for (const auto& [name, options] : choices())
        if (name == key) {
            for (const auto& o : options)
                if (value.py_equals(o)) return true;
            return false;
        }
    return false;
}

Island::Island(const std::filesystem::path& state_dir) : path_(state_dir / "island.json") {
    json::Value saved = saved_or_empty(path_);
    if (!saved.is_object()) throw std::runtime_error("island.json: not an object");  // saved.items()'s AttributeError
    state_ = json::Object{{"form", "angular"}, {"edge", "top"}, {"placement", "notch"}, {"screen", ""},
                          {"rest", rest_presets()[2].second}, {"noticeMs", 1000}};
    for (const auto& [key, value] : saved.as_object()) {
        if (key == "rest" && value.is_object()) {
            for (const auto& [item, mode] : value.as_object())
                if (in(mode, rest_modes(item))) state_["rest"].set(item, mode);
        } else if (valid(key, value)) {
            state_.set(key, value);
        }
    }
}

json::Value Island::snapshot() const { return state_; }  // presets' form preview (Z180) arrives with stage 3c

json::Value Island::set_rest(const json::Object& modes) {
    for (const auto& [item, mode] : modes) {
        const auto& allowed = rest_modes(item);
        if (!in(mode, allowed))
            throw bad_args("island rest " + item + ": " + py::repr_of(mode) + " is not one of " +
                           joined(allowed.empty() ? std::vector<std::string>{"power", "network", "battery", "inbox"} : allowed));
    }
    json::Value rest = *state_.find("rest");
    for (const auto& [item, mode] : modes) rest.set(item, mode);
    if (!rest.py_equals(*state_.find("rest"))) {
        state_.set("rest", std::move(rest));
        store::write_json(path_, state_);
        on_change();
    }
    return snapshot();
}

json::Value Island::set(const json::Object& changes) {
    for (const auto& [key, value] : changes)
        if (!valid(key, value)) {
            std::string options = "a screen name";
            for (const auto& [name, values] : choices())
                if (name == key) {
                    options.clear();
                    for (const auto& v : values) options += (options.empty() ? "" : ", ") + py::str_of(v);
                }
            throw bad_args("island " + key + ": " + py::repr_of(value) + " is not one of " + options);
        }
    bool changed = false;
    for (const auto& [key, value] : changes) changed = changed || !state_[key].py_equals(value);
    if (changed) {
        for (const auto& [key, value] : changes) state_.set(key, value);
        store::write_json(path_, state_);
        on_change();
    }
    return snapshot();
}

void Island::attach(Server& server) {
    server.topic("island", [this] { return snapshot(); });
    on_change = [&server] { server.publish("island"); };
    server.op("island.rest", [this](Client&, const Args& a) {
        const json::Value& item = a["item"];
        if (!item.is_string()) throw std::runtime_error("keywords must be strings");  // **{item: mode}'s TypeError
        return set_rest(json::Object{{item.as_string(), a["mode"]}});
    });
}

// --- Clips -----------------------------------------------------------------------------------------------------

namespace {
bool clips_valid(const json::Value& key, const json::Value& value) {
    if (!key.is_string()) return false;
    const std::string& k = key.as_string();
    if (k == "enterPastes" || k == "showImages") return value.is_bool();
    if (k == "rows") return value.is_int() && value.as_int() >= 4 && value.as_int() <= 10;
    return false;
}
}  // namespace

Clips::Clips(const std::filesystem::path& state_dir) : path_(state_dir / "clips.json") {
    json::Value saved = saved_or_empty(path_);
    state_ = json::Object{{"enterPastes", false}, {"rows", 6}, {"showImages", true}};
    if (saved.is_object())
        for (const auto& [key, value] : saved.as_object())
            if (clips_valid(json::Value(key), value)) state_.set(key, value);
}

json::Value Clips::set(const json::Value& key, const json::Value& value) {
    if (!clips_valid(key, value)) throw bad_args("clips " + py::str_of(key) + ": " + py::repr_of(value) + " is not allowed");
    if (!state_[key.as_string()].py_equals(value)) {
        state_.set(key.as_string(), value);
        store::write_json(path_, state_);
        on_change();
    }
    return snapshot();
}

void Clips::attach(Server& server) {
    server.topic("clips", [this] { return snapshot(); });
    on_change = [&server] { server.publish("clips"); };
    server.op("clips.set", [this](Client&, const Args& a) { return set(a["key"], a["value"]); });
}

}  // namespace fart
