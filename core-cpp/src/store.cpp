#include "store.h"

#include "pystr.h"

#include <cerrno>
#include <fcntl.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <system_error>
#include <unistd.h>

namespace fart::store {

namespace {

[[noreturn]] void fail(const std::string& what, const fs::path& path) {
    throw std::system_error(errno, std::generic_category(), what + " " + path.string());
}

// Path.mkdir(parents=True, exist_ok=True, mode=0o700): the parents with the default mode, the last one private.
void make_parent(const fs::path& path) {
    fs::path dir = path.parent_path();
    if (dir.empty()) return;
    std::error_code ec;
    if (dir.has_parent_path()) fs::create_directories(dir.parent_path(), ec);
    if (::mkdir(dir.c_str(), 0700) != 0 && errno != EEXIST) fail("mkdir", dir);
}

void write_all(int fd, const std::string& data, const fs::path& path) {
    size_t done = 0;
    while (done < data.size()) {
        ssize_t n = ::write(fd, data.data() + done, data.size() - done);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) fail("write", path);
        done += static_cast<size_t>(n);
    }
}

std::string temp(const fs::path& path, const json::Value& value) {
    make_parent(path);
    // Not mkstemp's name: the Python core's, so a crash leaves the same kind of leftover behind.
    fs::path name = path.parent_path() / ("." + path.filename().string() + "." + std::to_string(::getpid()) + "." + random_hex(4) + ".tmp");
    int fd = ::open(name.c_str(), O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0600);
    if (fd < 0) fail("open", name);
    try {
        write_all(fd, json::dump(value, json::Style::Store), name);
        if (::fsync(fd) != 0) fail("fsync", name);
    } catch (...) {
        ::close(fd);
        throw;
    }
    ::close(fd);
    return name.string();
}

}  // namespace

std::string random_hex(size_t bytes) {
    std::string raw(bytes, '\0');
    size_t got = 0;
    while (got < bytes) {
        ssize_t n = ::getrandom(raw.data() + got, bytes - got, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) throw std::system_error(errno, std::generic_category(), "getrandom");
        got += static_cast<size_t>(n);
    }
    static const char digits[] = "0123456789abcdef";
    std::string out;
    for (unsigned char c : raw) {
        out += digits[c >> 4];
        out += digits[c & 15];
    }
    return out;
}

std::optional<std::string> read_text(const fs::path& path) {
    int fd = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        if (errno == ENOENT) return std::nullopt;
        fail("open", path);
    }
    std::string data;
    char buf[65536];
    while (true) {
        ssize_t n = ::read(fd, buf, sizeof buf);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) {
            int saved = errno;
            ::close(fd);
            errno = saved;
            fail("read", path);
        }
        if (n == 0) break;
        data.append(buf, static_cast<size_t>(n));
    }
    ::close(fd);
    if (!py::utf8_valid(data)) throw ValueError(path.string() + ": not UTF-8");
    std::string text;
    text.reserve(data.size());
    for (size_t i = 0; i < data.size(); ++i) {
        if (data[i] == '\r') {
            text += '\n';
            if (i + 1 < data.size() && data[i + 1] == '\n') ++i;
        } else {
            text += data[i];
        }
    }
    return text;
}

std::optional<json::Value> read_json(const fs::path& path) {
    auto text = read_text(path);
    if (!text) return std::nullopt;
    auto parsed = json::parse(*text);
    if (!parsed.value) throw ValueError(path.string() + ": invalid JSON");
    return std::move(*parsed.value);
}

void write_json(const fs::path& path, const json::Value& value) {
    std::string name = temp(path, value);
    if (::rename(name.c_str(), path.c_str()) != 0) {
        int saved = errno;
        ::unlink(name.c_str());
        errno = saved;
        fail("rename", path);
    }
}

bool publish_new(const fs::path& path, const json::Value& value) {
    std::string name = temp(path, value);
    int linked = ::link(name.c_str(), path.c_str());
    int saved = errno;
    ::unlink(name.c_str());
    if (linked == 0) return true;
    if (saved == EEXIST) return false;
    errno = saved;
    fail("link", path);
}

void append_line(const fs::path& path, const json::Value& value) {
    make_parent(path);
    int fd = ::open(path.c_str(), O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0600);
    if (fd < 0) fail("open", path);
    try {
        write_all(fd, json::dump(value, json::Style::Store) + "\n", path);
    } catch (...) {
        ::close(fd);
        throw;
    }
    ::close(fd);
}

}  // namespace fart::store
