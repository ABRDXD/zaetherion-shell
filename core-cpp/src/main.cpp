// fartd-cpp: the FART core daemon in C++ (Z226; core/fartd.py is the Python one, and the reference).
//
// Same environment, same socket, same files: FART_STATE_DIR, FART_HOST, FART_RUNTIME_DIR (socket core.sock, mode
// 0600; lock core.lock; log core.log), FART_LOG=-, FART_FIXTURE_EPOCH (fixture host only), LISTEN_FDS.
// Until the port is complete it runs only with the fixture host (docs/CPP_CORE.md: no partial core runs live).
#include "clock.h"
#include "core.h"
#include "json.h"
#include "log.h"
#include "protocol.h"

#include <QCoreApplication>
#include <QSocketNotifier>
#include <QTimer>

#include <cerrno>
#include <clocale>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <iostream>
#include <map>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

extern char** environ;

namespace {

const char kOpTable[] =
#include "op_table.inc"
    ;

int signal_pipe[2] = {-1, -1};

void on_signal(int signum) {
    int saved = errno;
    unsigned char byte = static_cast<unsigned char>(signum);
    ssize_t ignored = ::write(signal_pipe[1], &byte, 1);
    (void)ignored;
    errno = saved;
}

// Before anything else (fartd.py: "Signals first"): a SIGTERM at any moment from here on is a clean stop.
// A self-pipe, not a blocked mask, so the processes later stages spawn don't inherit blocked signals.
void install_signals() {
    if (::pipe2(signal_pipe, O_CLOEXEC | O_NONBLOCK) != 0) std::exit(1);
    struct sigaction action{};
    action.sa_handler = on_signal;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART;
    for (int signum : {SIGTERM, SIGINT, SIGHUP}) sigaction(signum, &action, nullptr);
    std::signal(SIGPIPE, SIG_IGN);  // writes use MSG_NOSIGNAL too; this covers everything else
}

std::map<std::string, std::string> environment() {
    std::map<std::string, std::string> env;
    for (char** e = environ; *e; ++e) {
        std::string_view entry(*e);
        size_t eq = entry.find('=');
        if (eq != std::string_view::npos) env.emplace(entry.substr(0, eq), entry.substr(eq + 1));
    }
    return env;
}

std::string get(const std::map<std::string, std::string>& env, const char* name) {
    auto it = env.find(name);
    return it == env.end() ? std::string() : it->second;
}

[[noreturn]] void die(const std::string& message) {
    std::cerr << message << "\n";
    std::exit(1);
}

// Path.mkdir(mode=0o700, parents=True, exist_ok=True).
void make_dir(const std::filesystem::path& path) {
    std::error_code ec;
    if (path.has_parent_path()) std::filesystem::create_directories(path.parent_path(), ec);
    if (::mkdir(path.c_str(), 0700) != 0 && errno != EEXIST) die("fartd: cannot make " + path.string() + ": " + std::strerror(errno));
}

// fartd.py listening_socket: an inherited systemd socket (LISTEN_FDS, not ours to remove) or our own.
int listening_socket(const std::filesystem::path& path, const std::map<std::string, std::string>& env, bool& owned) {
    if (get(env, "LISTEN_PID") == std::to_string(::getpid()) && std::atoi(get(env, "LISTEN_FDS").c_str()) >= 1) {
        owned = false;
        ::fcntl(3, F_SETFD, FD_CLOEXEC);
        return 3;
    }
    owned = true;
    ::unlink(path.c_str());  // stale: we hold the single-instance lock
    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    if (path.native().size() >= sizeof addr.sun_path) die("fartd: socket path too long: " + path.string());
    std::strcpy(addr.sun_path, path.c_str());
    int fd = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) die(std::string("fartd: socket: ") + std::strerror(errno));
    mode_t old = ::umask(0177);  // born 0600: no moment where another user could connect
    int bound = ::bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof addr);
    int bind_errno = errno;
    ::umask(old);
    if (bound != 0) die("fartd: bind " + path.string() + ": " + std::strerror(bind_errno));
    if (::listen(fd, 100) != 0)  // asyncio's start_unix_server listens again with its own backlog of 100
        die(std::string("fartd: listen: ") + std::strerror(errno));
    return fd;
}

}  // namespace

int main(int argc, char** argv) {
    install_signals();
    const auto env = environment();
    const std::string state = get(env, "FART_STATE_DIR"), host = get(env, "FART_HOST");
    if (state.empty() || host.empty())
        die("fartd: set FART_STATE_DIR and FART_HOST (fart-next does this)");
    if (host != "fixture")  // host profiles are stage 3a; until the port is whole this core never runs live
        die("fartd-cpp: host profile '" + host + "' is not in the C++ core yet; only FART_HOST=fixture runs");

    std::string runtime_text = get(env, "FART_RUNTIME_DIR");
    if (runtime_text.empty()) {
        std::string xdg = get(env, "XDG_RUNTIME_DIR");
        if (xdg.empty()) die("fartd: set FART_RUNTIME_DIR or XDG_RUNTIME_DIR");
        runtime_text = xdg + "/fart-next";
    }
    const std::filesystem::path runtime(runtime_text);
    make_dir(runtime);
    int lock = ::open((runtime / "core.lock").c_str(), O_WRONLY | O_APPEND | O_CREAT | O_CLOEXEC, 0666);
    if (lock < 0 || ::flock(lock, LOCK_EX | LOCK_NB) != 0) die("fartd: another core is already running");
    fart::log::setup(runtime / "core.log");

    QCoreApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");  // Qt set the user's locale; numbers are always written the C way

    fart::Clock clock(fart::fixture_epoch(env));
    make_dir(state);

    auto table = fart::json::parse(kOpTable);
    if (!table.value) die("fartd-cpp: op table unreadable: " + table.error);
    fart::Server server(*table.value);

    const std::filesystem::path sock_path = runtime / "core.sock";
    bool owned = false, stopping = false;
    auto stop = [&] {
        if (stopping) return;
        stopping = true;
        QTimer::singleShot(0, [&] {  // after the current reply (shutdown's) has been written
            fart::log::info("fart.core", "core stopping");
            server.stop_listening();
            server.close_all();
            if (owned) ::unlink(sock_path.c_str());
            QCoreApplication::exit(0);
        });
    };
    fart::Core core(clock, state, server, stop);

    QSocketNotifier signals(signal_pipe[0], QSocketNotifier::Read);
    QObject::connect(&signals, &QSocketNotifier::activated, [&] {
        unsigned char drain[16];
        while (::read(signal_pipe[0], drain, sizeof drain) > 0) {
        }
        stop();
    });

    server.listen(listening_socket(sock_path, env, owned));
    fart::log::info("fart.core", std::string("core ") + fart::VERSION + " up (C++, pid " + std::to_string(::getpid()) +
                                     ", host " + host + ", state " + state + ")");
    return app.exec();
}
