#include "log.h"

#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <fcntl.h>
#include <string_view>
#include <sys/stat.h>
#include <unistd.h>

namespace fart::log {

namespace {
constexpr long kKeep = 256 * 1024;  // fartd.py LOG_KEEP
int out_fd = STDERR_FILENO;

void line(const char* level, const char* name, const std::string& message) {
    timespec ts{};
    clock_gettime(CLOCK_REALTIME, &ts);
    tm local{};
    localtime_r(&ts.tv_sec, &local);
    char stamp[32];
    std::strftime(stamp, sizeof stamp, "%Y-%m-%d %H:%M:%S", &local);
    char ms[16];
    std::snprintf(ms, sizeof ms, ",%03ld", ts.tv_nsec / 1000000);
    std::string text = std::string(stamp) + ms + " " + level + " " + name + ": " + message + "\n";
    // One write per line, so lines from a later child process sharing the file never interleave mid-line.
    ssize_t ignored = ::write(out_fd, text.data(), text.size());
    (void)ignored;
}
}  // namespace

void setup(const std::string& path) {
    const char* mode = std::getenv("FART_LOG");
    if (mode && std::string_view(mode) == "-") return;
    if (FILE* old = std::fopen(path.c_str(), "rb")) {
        std::fseek(old, 0, SEEK_END);
        long size = std::ftell(old);
        if (size > kKeep) {
            std::string tail(static_cast<size_t>(kKeep), '\0');
            std::fseek(old, size - kKeep, SEEK_SET);
            size_t got = std::fread(tail.data(), 1, tail.size(), old);
            std::fclose(old);
            old = nullptr;
            if (FILE* trimmed = std::fopen(path.c_str(), "wb")) {
                std::fwrite(tail.data(), 1, got, trimmed);
                std::fclose(trimmed);
            }
        }
        if (old) std::fclose(old);
    }
    int fd = ::open(path.c_str(), O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0666);
    if (fd < 0) return;  // stays on stderr, as a failed FileHandler would have raised; the core still runs
    ::fchmod(fd, 0600);
    out_fd = fd;
}

void info(const char* name, const std::string& message) { line("INFO", name, message); }
void warning(const char* name, const std::string& message) { line("WARNING", name, message); }
void error(const char* name, const std::string& message) { line("ERROR", name, message); }

}  // namespace fart::log
