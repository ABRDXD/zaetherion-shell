# Using the DMS backend for FART

For Mshell, the next major project, after the whole FART-next project is done (PROJECT_PLAN, Open exploration topics): a separate repo cloned from fart-next, with FART's UI and `fartd` on the DMS backend. It has not started. The user allowed taking DMS's backend instead of building one, on 8 November 2026. Read from the source at `AvengeMedia/DankMaterialShell` (now `duxlabs-dev/dux-shell`), commit `47b1638` of 7 November 2026, before DMS was installed here. Nothing below has been run.

## What DMS is

- DMS is Dux Modular Shell, formerly DankMaterialShell, under the MIT licence (© 2025 Avenge Media LLC).
- A Go daemon, `dms` (`core/`), owns the system integrations.
- Its Quickshell UI (`quickshell/`) is a client of that daemon.
- `dms run` starts the server and spawns `qs` as a child.
- `dms debug-srv` starts only the server: `server.Start(true)`, which also prints the API docs. This is the standalone path FART would use. Its name suggests a debugging aid, so confirm it is meant to stay before relying on it.

## The protocol

- Newline-delimited JSON over a Unix socket. DMS's QML reads the path from `$DMS_SOCKET`; the default path is set in `dux-go`, not read yet.
- `quickshell/Services/DMSService.qml` uses two connections:
  - **Requests:** `{"id": n, "method": "network.…", "params": {…}}`. The reply carries the same `id`, with a result or an error.
  - **Events:** `{"method": "subscribe", "params": {"clientId": …, "services": [...]}}` on a second socket. With no `services`, it subscribes to everything. To narrow the subscription, DMS reconnects with a shorter list.
- `getServerInfo` returns `apiVersion`, which is 40 at `47b1638`, and `capabilities`. A capability appears only when its manager started: `network`, `bluetooth`, `brightness`, `clipboard`, `loginctl`, `wlroutput`, `cups`, `dgop`, `lyrics`, `wellbeing`, `wallpaper`, `gamma` and others.

## What the Go side covers, and what it doesn't

| Area | Where it lives in DMS | FART today |
|---|---|---|
| Network: NetworkManager, iwd, networkd | Go `server/network` | host adapter |
| Bluetooth, with a pairing agent | Go `server/bluez` | host adapter |
| Brightness: logind, sysfs, DDC/CI | Go `server/brightness` | host adapter |
| Clipboard history (ext-data-control) | Go `server/clipboard` | `cliphist list` under the `history` lease |
| Sessions and sleep inhibit | Go `server/loginctl` | — |
| Process and system stats | Go `server/dgop` | the Performance room's own sampling |
| Lyrics | Go `server/lyrics` | host cache, then lrclib |
| Displays and DPMS, night light, printers | Go | — |
| **Audio** | QML: `PipewireAudioBackend.qml` (Quickshell's Pipewire) | host adapter |
| **Notifications** | QML: `NotificationService.qml` (Quickshell's server) | the core's notification mirror |
| **Lock screen** | QML: `Modules/Lock` (WlSessionLock) | the host's |
| **Idle and idle inhibit** | QML: `IdleService.qml` | the host's |
| **Polkit agent** | QML: `PolkitService.qml` | the host's |

The Go backend therefore doesn't make FART a complete shell by itself. Audio, notifications, lock, idle and polkit are Quickshell built-ins that DMS drives from QML. For those, FART would write its own QML on the same Quickshell primitives, and could use DMS's QML as a reference, with credit in NOTICE if any is copied.

## How FART would use it

1. **Talk to an installed `dms`; don't vendor it.** Copying the Go code would bring in a Go toolchain and about 40 modules. AGENTS.md allows no dependency without a concrete benefit, and talking over the socket gives the same result.
2. **Add an adapter, `adapters/dms`,** beside `serpantinum` and `fixture`. It would fill the same typed contract (network, bluetooth, audio stays host or Quickshell, palette and so on), so the rooms don't change.
3. **Tie subscriptions to leases.** Subscribe to a service only while a FART lease holds it, and resubscribe with the shorter list on release. This pairs acquiring with releasing, as AGENTS.md requires. Clipboard history would come from the `clipboard` service instead of running `cliphist`.
4. **Gate each feature on capabilities.** A room uses DMS only when the service is listed in `capabilities`, and falls back to the host adapter otherwise.

## Risks to check before building

- **Two owners of one thing:** next to Serpantinum on Hyprland, the `dms` server may start its own clipboard history, gamma control and screensaver-inhibit service. Find out which managers can be turned off, or run it only where DMS is the host.
- **Cost:** a second resident daemon. Measure RSS and PSS, separately, before claiming any saving over the host adapter.
- **API drift:** `apiVersion` moves (it is 40 now). Pin the range the adapter accepts and say so in the panel when it's out of range.
- **The compositor:** the user is trying DMS on niri, while FART's clock hook, its bind and its events are Hyprland's. An adapter for DMS on niri also needs the workspace and fullscreen sources for niri.

## Next step, once DMS is installed

Read the real socket path and `getServerInfo`, then list the methods. DMS's QML calls them by name, so `grep -o '"[a-z]*\.[a-zA-Z.]*"'` over `quickshell/Services` gives the list, and `dms debug-srv` prints the docs. Then build `adapters/dms`: read-only first (network, bluetooth, brightness, clipboard counts), against a fixture recorded from the real socket.
