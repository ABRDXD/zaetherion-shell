#include "clock.h"

#include "json.h"
#include "log.h"
#include "pystr.h"

#include <ctime>
#include <fstream>

namespace fart {

namespace {
double seconds(clockid_t id) {
    timespec ts{};
    clock_gettime(id, &ts);
    return static_cast<double>(ts.tv_sec) + static_cast<double>(ts.tv_nsec) / 1e9;
}
}  // namespace

Clock::Clock(std::optional<double> epoch) {
    std::ifstream in("/proc/sys/kernel/random/boot_id");
    std::getline(in, boot_id_);
    while (!boot_id_.empty() && (boot_id_.back() == '\n' || boot_id_.back() == ' ')) boot_id_.pop_back();
    if (epoch) offset_ = *epoch - seconds(CLOCK_REALTIME);
}

Now Clock::now() const { return Now{seconds(CLOCK_BOOTTIME), seconds(CLOCK_REALTIME) + offset_, boot_id_}; }

std::optional<double> fixture_epoch(const std::map<std::string, std::string>& environ) {
    auto value = environ.find("FART_FIXTURE_EPOCH");
    auto host = environ.find("FART_HOST");
    if (value == environ.end() || value->second.empty() || host == environ.end() || host->second != "fixture")
        return std::nullopt;
    auto parsed = json::parse_double(value->second);
    if (!parsed) {
        log::warning("fart.core", "FART_FIXTURE_EPOCH=" + py::repr(value->second) + " ignored: not a number");
        return std::nullopt;
    }
    return parsed;
}

}  // namespace fart
