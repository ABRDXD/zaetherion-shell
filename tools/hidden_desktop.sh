#!/usr/bin/env bash
# Run a command inside a private, invisible desktop: a virtual KWin with its own config and D-Bus, nothing on the user's screen.
#     tools/hidden_desktop.sh python3 -m unittest discover -s tests
# Windows and layer surfaces opened by the command land there, with the GPU working. Hyprland isn't there, so `hyprctl` from inside sees the real session: read-only use only.
set -u
base=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/fart-hidden-XXXXXX")
socket="fart-hidden-$$"
export FART_HIDDEN_DESKTOP_LOG="$base/kwin.log"
mkdir -p "$base/config" "$base/cache"
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME="$base/config" XDG_CACHE_HOME="$base/cache" QT_QPA_PLATFORM=offscreen KDE_FULL_SESSION= \
    dbus-run-session -- kwin_wayland --virtual --no-lockscreen --no-global-shortcuts --no-kactivities --width 1920 --height 1080 --socket "$socket" >"$base/kwin.log" 2>&1 &
kwin=$!
# By its unique socket name: killing the dbus-run-session wrapper alone leaves KWin running. When KWin goes, the wrapper and its private bus go with it.
trap 'pkill -TERM -f -- "kwin_wayland.*--socket $socket" 2>/dev/null; sleep 0.6; pkill -KILL -f -- "kwin_wayland.*--socket $socket" 2>/dev/null; rm -rf "$base" "$XDG_RUNTIME_DIR/$socket" "$XDG_RUNTIME_DIR/$socket.lock"' EXIT
for _ in $(seq 1 100); do [ -S "$XDG_RUNTIME_DIR/$socket" ] && break; sleep 0.1; done
if [ ! -S "$XDG_RUNTIME_DIR/$socket" ]; then echo "hidden desktop did not start:" >&2; tail -20 "$base/kwin.log" >&2; exit 3; fi
env -u DISPLAY WAYLAND_DISPLAY="$socket" "$@"
