// Suspend-proof time, as core/clock.py: boottime for spans, wall time for what people read.
#pragma once

#include <map>
#include <optional>
#include <string>

namespace fart {

struct Now {
    double boot;  // CLOCK_BOOTTIME seconds: counts suspend, ignores wall-clock changes
    double real;  // epoch seconds (moved by FART_FIXTURE_EPOCH in a fixture core)
    std::string boot_id;
};

class Clock {
public:
    // epoch: a test core's wall clock starts there and runs at the real rate (fixture host only; fixture_epoch).
    explicit Clock(std::optional<double> epoch = std::nullopt);
    Now now() const;

private:
    std::string boot_id_;
    double offset_ = 0.0;
};

// core/fartd.py fixture_epoch: FART_FIXTURE_EPOCH as a float, honoured only when FART_HOST is "fixture", so a
// stray variable can never move the desktop's clock. A value that isn't a number is ignored with a warning.
std::optional<double> fixture_epoch(const std::map<std::string, std::string>& environ);

}  // namespace fart
