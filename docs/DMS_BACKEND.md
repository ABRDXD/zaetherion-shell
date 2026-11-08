# The DMS backend

ZÆTHERION does not write a system backend. It uses the backend of **DMS** (Dux Modular Shell, formerly DankMaterialShell), which is MIT-licensed: "Copyright (c) 2025 Avenge Media LLC". Source: `duxlabs-dev/dux-shell`, plus the shared `duxlabs-dev/dux-go` library.

These facts were read from the source on 8 Nov 2026 (v2.1.1, `apiVersion` 40), building on an earlier read at commit `47b1638`. Nothing has been run yet. S0 records real fixtures.

## What DMS is
- A Go daemon, `dms`, owns the system integrations. Its own Quickshell UI is a client of that daemon.
- `dms run` starts the backend and launches a Quickshell UI as its child.
- **`dms run -c <dir>`** (env `DMS_SHELL_DIR`) launches *a different* UI directory instead of the embedded one. ZÆTHERION uses this with its resident UI (Z10).
- `dms debug-srv` runs the server alone, but it is a debugging aid with no readiness signal and no `DMS_SOCKET`. It is not used.
- A systemd unit `dms.service` ships with the package (`Type=notify`, `BusName=org.freedesktop.Notifications`). It is **not** used, because startup is through Hyprland autostart only (Z13).

## Packaging
- **`dux-shell-git` (AUR)**, chosen by the owner (Z9). At planning time: version 2.1.0.r0. Depends on `quickshell` and `accountsservice`; build-depends on `git go make`; optional `dux-gop cava i2c-tools matugen`. Conflicts with `dms-shell`, `dux-shell` and `dms-shell-git`.
- The installed Quickshell package provides `quickshell`, and Go 1.27.3 is installed; DMS needs Go ≥ 1.27.1 to build.
- The official `extra/dux-shell` package exists but was not chosen.
- Installing the package auto-starts nothing. Nothing is enabled until `dms setup` or `dms systemd enable` is run, and ZÆTHERION runs neither.

## Protocol
- **Socket:** `$XDG_RUNTIME_DIR/dms-<pid>.sock`, mode 0600. The server never reads `DMS_SOCKET`; the launcher passes it to its Quickshell child.
- **Framing:** newline-delimited JSON, lines up to 64 MiB. On connect the server first sends one capabilities object.
- **Request:** `{"id": n, "method": "ns.method", "params": {…}}`. **Reply:** `{"id": n, "result": …}` or `{"id": n, "error": "…"}`. Replies can arrive out of order, so match them by `id`.
- **Events:** `{"method": "subscribe", "params": {"clientId": …, "services": [...]}}` on a second connection. Without `services` it subscribes to everything. The first event is `server` with `apiVersion`, `cliVersion` and `capabilities`.
- **Capabilities** appear only when their manager started. Always present: plugins, dgop, drives, lyrics, weather, fcitx5.

## Namespaces ZÆTHERION uses

| Namespace | Methods (selection) | Used for |
|---|---|---|
| `network.*` | `getState`, `wifi.scan/networks/connect/disconnect/forget/toggle`, `ethernet.*`, `vpn.*`, `hotspot.*`, `credentials.submit/cancel` | Devices, settings |
| `bluetooth.*` | `getState`, `startDiscovery`, `setPowered`, `pair`, `connect`, `disconnect`, `remove`, `trust`, `pairing.submit/cancel` | Devices, settings |
| `brightness.*` | `getState`, `setBrightness`, `increment`, `decrement` | OSD, Devices |
| `clipboard.*` | `getHistory`, `search`, `copyEntry`, `pinEntry`, `deleteEntry`, `import`, `clearHistory` | Clips tab and room |
| `wayland.gamma.*` | `getState`, `setEnabled`, `setTemperature`, `setLocation`, `setManualTimes`, `setUseIPLocation` | Night light |
| `wlroutput.*` | `getState`, `applyConfiguration`, `testConfiguration` | Display settings |
| `loginctl.*` | `getState`, `lock`, `setLockBeforeSuspend`, `setSleepInhibitorEnabled`, `setLockedHint` | Idle, lock, session card |
| `dgop.*` | `meta`, `gpu`, `hardware`, `process` | Performance room |
| `weather.*`, `location.*` | (read from the UI source at S0) | Weather, sky, night light |
| `lyrics.*` | (S0) | Media; order decided in S2 |
| `sysupdate.*` | (S0) | Update count |
| `wellbeing.*` | `getState`, `setLimits`, `summary` | Wellbeing; candidate (OPEN 1) |
| `freedesktop` events | `freedesktop.screensaver` | Idle inhibitors |

## What DMS does *not* do in Go

These are Quickshell services in DMS's QML. ZÆTHERION implements them on the same Quickshell primitives, and may adapt DMS's QML with credit in NOTICE:
- **Audio:** Pipewire.
- **Notifications:** `NotificationServer` with actions, images, markup, persistence and inline reply.
- **Lock:** `WlSessionLock` with `PamContext`. DMS uses PAM `dankshell` then `login`; ZÆTHERION uses `serpantinum` then `login` (Z37).
- **Idle:** `IdleMonitor`, with inhibit state taken from DMS's ScreenSaver events.
- **Polkit:** `PolkitAgent`.
- **MPRIS, UPower, tray.**

## Managers and ownership
- **Clipboard:** can be disabled via `~/.config/dms/clsettings.json` `{"disabled": true}`. ZÆTHERION keeps it on and imports cliphist once (Z14).
- **Gamma:** no control is created until night light is configured.
- **ScreenSaver:** claims `org.freedesktop.ScreenSaver` with `DoNotQueue`, and backs off if another process owns it. In the ZÆTHERION session nothing else does.
- **No other per-manager switches.** A manager is skipped only when its backend is missing.
- **Compositor:** the Go side targets protocols, not compositors: wlr-gamma-control, ext-data-control and wlr-output-management. All three are supported by current Hyprland according to wayland.app. Real behaviour on the owner's Hyprland 0.57.1 is verified at S0 and S2.

## How ZÆTHERION uses it
1. **Installed, not vendored.** It talks over the socket only.
2. **`adapters/dms`** fills the typed contract, so rooms never see DMS.
3. **Subscriptions follow leases.** Subscribe only while a lease holds a service; resubscribe with the shorter list on release.
4. **Capability gating.** A feature uses DMS only when the capability is present. Otherwise it shows OFFLINE (Z11, Z123).
5. **`apiVersion` pinned.** Out-of-range versions are reported in the settings window.

## Recent history (last three months)
- **v2.0.0 (20 Oct), breaking:** moved to Dux Labs; app id `dev.duxlabs.shell`; config, state and cache paths moved to `dms` (old paths symlinked); Go ≥ 1.27.1 required.
- **v2.1.0 (4 Nov):** packaging rebrand; `dms migrate dux`; an optional device argument on the brightness IPC.
- **v2.1.1 (6 Nov):** weather and wallpaper listing go through `dms`; clipboard handles large histories better; network devices are re-tracked after a NetworkManager restart.
