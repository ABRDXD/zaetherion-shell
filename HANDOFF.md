# 14 November 2026 · Opus (Claude A): S6 started; the first open keeps every key

- **Design.** `docs/S6_LAUNCHER.md` (F4 draft): where keys go when the launcher opens, measured with `tools/launcher_keycheck.py` (nested Hyprland, fixture adapter, a focused app logging its keys, `wtype`). Today's path (bind → `zaetherion key` → core → view) takes 85–89 ms median with the view up, worst 128, and drops ~3 in 10 presses whose press and release arrive together. A Hyprland global shortcut handled in the view (option B) takes ~60 ms, worst 85, and never dropped one. Plan: B now, the launcher grown out of the island (C) to close the rest. Owner: keep DMS's spotlight on another key during the trial; Brave for `?term`.
- **Bug fixed (live).** The first open after the view starts lost every key: Hyprland moved the keyboard from the panel to the island named after it in the focus grab. Panel last in `HyprlandFocusGrab.windows` (`bb511d1`): 0 lost in 160 trials; the owner confirmed on the live desktop after a restart.
- **Shortcut.** `adapters/hyprland/HyprlandLauncherShortcut.qml` is the one file that may hold a `GlobalShortcut`, off unless `FART_LAUNCHER_SHORTCUT=1`; `KeybindsDomain.launcherPressed/Released` carry it to the view. The layout law says exactly that. Not bound on the live session.
- **Checks.** Full suite 954 OK on `2d04d4f`. Main checkout fast-forwarded; core restarted with the S4 settings.
- **Prompts written** for Claude B (wallpaper/presets, Z177+), C (clipboard from the island, calmer island rest, Z180+), D (Wi-Fi and Bluetooth in FART, Z190+). Launcher decisions: Z185+.
- **Next.** The launcher itself: apps domain in the adapter, frecency in the core (import `launch_stats.json`, Z136), matching in the core, the surface grown from the island.

# 14 November 2026 · Opus (Claude A): S4 live; our notification server starts with the desktop

- **Live (owner present).** S5 (`s5-sfx`) merged into `s0-seed` (`39719a2`, 948 OK); main checkout fast-forwarded. Core started with `FART_VIEW_ENTRY=<repo>/shell-dms.qml`, `FART_RESIDENT_VIEW=1`, `FART_NOTIFICATION_SERVER=1`, `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet`. Quiet copy matched the running DMS (`9483c24f0a364ed0`); `dms_quiet_check.py` 12/12. The owner watched the matrix pass: normal, low, critical (stays), an action (`ok` returned), a picture, a replace-id, expiry, DND on (normal held, critical through) and off; all listed in FART's Inbox. Wi-Fi, tray, media, audio, battery, logout card and lock work.
- **Found.** (1) `docs/S4_GO_LIVE.md` lacked `FART_VIEW_ENTRY`; without it the view is `shell.qml` and nobody holds the name. Fixed in the doc. (2) `zaetherion restart` raced: the new core exited with "another core is already running" while the old one was still sweeping; `start` once it had gone worked. (3) `DmsNotifications` was a deferred domain, so our server only started at FART's first open; until then notifications were lost.
- **Fix (branch `s4-eager-notif`).** `DmsAdapter` creates the notifications domain at start when `FART_NOTIFICATION_SERVER=1` (`serverAtStart`), else at `loadDeferred()` as before. Test: `test_notification_server.AtStartTests` through the whole adapter (`tools/dmstest/AdapterNotificationHarness.qml`), panel never opened; fails without the fix. Full suite: 949 OK.
- **At login (owner's go, branch `s4-session`).** `tools/session-start` sets the four settings when `tools/dms_quiet.py fits` passes (new: the copy records the installed `dms` program, since `dms version` names no UI revision and nothing is extracted before DMS runs); else DMS's own, logged. A `stock-notifications` file in the state folder opts out. The live copy was stamped by hand (`/usr/bin/dms` unchanged since 4 November; the copy's revision is the running session's). Dry-run of the script in a scratch folder with a stand-in `zaetherion`: fits, opt-out and changed-program each did the right thing. `test_dms_quiet` 9, layout, sessions and supervise-guard tests OK; full suite not rerun (tool and shell script only). Not yet seen at a real login.
- **Open.** The owner finds the island at rest too cluttered (power, Wi-Fi, battery, notifications icon). The owner wants a wallpaper selector and a preset selector inside FART (Z162); briefed to Claude B.

# 13 November 2026 · Sonnet: notifications leave the island sooner (branch `s5-notif-dismiss`, Z175)

- **Owner asked** to dismiss notifications by right-click or shorten the stay; both done.
- **Right-click.** `IslandSurface` has a right-button-only `MouseArea` (`objectName: "noticeRightClick"`) over the island while a notification or critical one is shown; it calls `dismissNotice()`: `queue.remove` plus `host.notifications.dismiss(id)` (the Inbox's own dismiss). Left-click is unchanged; the right button is consumed, no menu, nothing reaches the window below. Not for the FART-docked critical drop (`FartAlertDrop`), which has its own path.
- **Time.** `NotificationTiming` low/normal 5000 -> 3000; `IslandEvents.durations.notification` 3000. A sender's timeout is honoured, but `IslandEvents.notificationCap` (6000) caps a non-critical one on the island; the Inbox keeps the item. Critical with no timeout now stays until dismissed on the mirror path too (it used to take `durations.notification`).
- **Hover.** Separable, so no 10 s cap: `IslandExpansion` has a `HoverHandler` on the notification card (`noticeHovered`), `IslandSurface.noticeHovered` follows it, and `queue.hovered` is that while a notice is shown (island `pointerInside` otherwise). The pointer on the island's padding no longer pauses.
- **Tests.** New `tests/fixtures/island/DismissTest.qml` (right-click via the area's `clicked`, 3 s default, hover rule); `NoticeTest.qml` gained the cap, 3 s and critical checks; `test_notification_server.py` expects 3000. Z175 in DECISIONS, SURFACES row updated.
- **Not done / doubts.** A reply being typed does not pause the countdown with the pointer away (as before). The right-click is injected as a signal in tests, not a real pointer event. Not tried on the live session (never touched).

# 13 November 2026 · Opus: live switch to our notification server; the empty strip under the island

- **Live.** Main checkout on `s0-seed` (Astra's island docs committed as `842d054`, merged `d91937b`). Core started with `FART_VIEW_ENTRY=shell-dms.qml`, `FART_RESIDENT_VIEW=1`, `FART_NOTIFICATION_SERVER=1`, `FART_RESIDENT_DIR=~/.local/state/zaetherion/dms-quiet`; our view holds `org.freedesktop.Notifications`; DMS's volume/mic/brightness OSDs off (backup `~/.config/dms/settings.json.bak-2026-11-13-osd`). A test notification showed ~5 s (measured by screen grabs, pointer away).
- **`zaetherion restart` race.** The new core started while the old one was still stopping DMS ("another core is already running"): no core for ~30 s until a plain `start`. A fix (wait for core.lock, 12 s bound) is committed on `s5-restart-race` (`4832e4b`), not yet verified or merged. Until then: `stop`, wait, `start`.
- **Empty strip.** The screen reserved 70 px: our island's 36 plus 34 from DMS's hidden island-style Main Bar, which DMS reserves even when `visible` is false. `tools/dms_quiet.py` now patches that expression too (Z171); rebuilt live, `dms restart`: reserved 36.
- **Owner asked, not started:** right-click to dismiss a notification and a much shorter showing time.
# 13 November 2026 · Opus: S5, the OSD shows in FART's header while FART is open (Z174, branch `s5-osd-header`)

- **Owner's decision (Z174, bends Z161 for the OSD only).** With FART grown from the island, a volume, mic or brightness change shows at once in FART's header instead of waiting, time banked, for the fold (the stale level noted in S5 step 1). Every other ordinary event keeps Z161; critical events keep `FartAlertDrop`. FART closed: unchanged.
- **Readout.** `view/shell/FartHeaderOsd.qml`, drawn by the Overlay beside `FartAlertDrop`: the island's OSD face on one line (glyph, kind, 16 blades, percent or MUTED) on a small island silhouette exactly the header row's height (32 px), centred over the command line so it never hides a button (`Shell.headerTop/headerHeight/headerSlotX/headerSlotWidth`). It drops in from FART's top edge (`Cue` "fart.osd", navigate in, feedback out), updates in place, no flash, no card. Type and sizes are Design tokens only (`Design.readout`, `caption`, `baseline`).
- **Queue.** `IslandEvents` gets `covered` (the island's `docked`): covered, an OSD change is handed out (`coveredOsd`) instead of `queue.offer`. `IslandSurface.headerOsd` holds it with its own 1.2 s timer, restarted on each change; `IslandWindow` and the three `shell*.qml` pass it to the Overlay as `islandOsd`. The readout follows the cover with its time: an OSD already on the island goes up into the header when FART docks, and one still in the header goes back to the island for what is left of its 1.2 s when FART folds.
- **Checks.** `tests/fixtures/island/HeaderOsdTest.qml` (11 checks, `test_island.test_osd_shows_in_fart_header_while_covered`): in the header at once and not in the queue, repeat updates in place, sits on the header row and no taller, MUTED, dwell follows the last change, gone after 1.2 s, the fold replays nothing stale, uncovered on the island as before, dock lifts it, fold hands it back. Targeted modules (island, architecture, layout, contract, cues): 36 OK. qmllint (Qt 6, JSON): 0 syntax diagnostics on the 10 changed QML files; `make_qmldirs.py --check` clean. Full suite: 912 of 913; the one failure, `test_notification_server` `test_sound_is_left_to_a_sender_that_plays_its_own_and_to_do_not_disturb` (`['dnd.on', 'notify.critical'] != ['notify.critical']`), fails the same way on an untouched export of the base `526319d` (its new `dnd.on` cue), so it is not this branch's; left for the sound-set work.
- **Captures.** Offscreen through `tools/shots.py` with the readout laid over the Shell as the Overlay lays it (a scratch wrapper, not checked in): volume 62 %, muted, brightness 80 %, Mocha. Not yet seen in the nested Hyprland or live.
- **For the owner.** (1) The readout covers the middle of the command line for 1.2 s; if you are typing there, your text is hidden under it meanwhile. (2) Fluid form not captured.
# 13 November 2026 · Opus: S5 step 3, our own equaliser (branch `s5-eq`, owner away; not live)

- **Owner's call.** Keep the 10 bands and mono; drop balance, channel swap, "dynamic EQ", dynamics, reset audio and open host. Presets: Flat, Bass, Treble, Vocal, Loudness (our values). How it exists: Z173.
- **Built.** `core/eq_chain.py` (bands, presets, RBJ response and headroom, the `pw-cli` params, the filter-chain config text), `core/equalizer.py` (settings in `eq.json`, topic `equalizer`, ops `eq.enable/band/preset/mono`, the chain's process: start, live set-param, restart after PipeWire goes, give up after four stops in 60 s, dies with the core), verb `eq` (`core/verbs/equalizer.py`). fartd attaches the chain only when it supervises DMS and is not a fixture host. Contract `EqualizerDomain` trimmed to enabled, active, error, bands, preset(s), mono and four setters; `adapters/common/CoreEqualizer.qml` is the DMS session's (`DmsAdapter.loadDeferred`), the fixture and the legacy Serpantinum adapter follow; `QuickshellAudio` hides our two nodes from devices and streams. No room shows the equaliser yet (none did before); the Settings Audio/EQ tab (Z93) needs the owner's look.
- **Checks.** `tests/test_equalizer.py` (23). Architecture, layout, contract and equalizer: 48 OK; DMS adapter, shell, client, verbs, command, daemon, supervise guard: 68 OK. qmllint (Qt 6): 0 syntax diagnostics on the seven edited QML files. `make_qmldirs.py --check` clean. `tools/eq_check.py` on a private PipeWire (null sinks, no session manager; the owner's PipeWire untouched, same pid before and after): 24/24, covering the nodes, smart filter, gains and mono via pw-dump, a PipeWire restart, a killed core and off. Full suite: 934 run, 1 failure, `test_notification_server` ("sound is left to a sender…"): it now also hears the `dnd.on` cue added in `526319d`; it fails the same on the base commit alone, so it is not this branch's; the test needs updating to the new cue.
- **Not checked, needs the owner present.** WirePlumber placing the smart filter in front of the real default sink, and how it sounds: `zaetherion eq on`, play something, `eq bass`, `eq mono`, switch the output device in Devices, `eq off`, and check the sound is unchanged afterwards. The headroom makes boosted presets quieter (Bass by 7.1 dB); say if you'd rather have no automatic headroom.
- **Next.** The owner's live try; then the EQ's look in Settings (Audio/EQ tab).

# 13 November 2026 · Opus: S5 step 2, caps and num lock; the DMS link keeps early feeds (owner away)

- **Caps and num lock.** `adapters/dms/DmsKeybinds.qml`: `HyprlandKeybinds` plus DMS's `evdev` service (`{available, capsLock, numLock}`), held while the domain exists; null until the first snapshot. The island's hover view already shows caps lock when it is on (`IslandRest.hoverStatus`). Live probe: caps true (it was on), num false, 94 binds read.
- **DMS link fix.** `DmsLink` reset its machine in `Component.onCompleted`, dropping feeds that completed before it (seen when a feed sat beside its link). It now keeps them. Live probe: a sibling `evdev` feed subscribes and gets data.
- **Airplane mode** has no DMS source (no rfkill field in `network`); still null in this session.
- **Checks.** Full suite: 904 of 911; the 7 failures were `test_dms_adapter` asserting `network` is the only un-leased subscription and `HyprlandKeybinds` in the composition. §3 of DMS_ADAPTER.md now names `evdev` (and the OSD's `brightness`) as un-leased, the tests follow, and `test_dms_adapter` passes alone (20). Full suite on `fe88271`: 911 OK.
- **EQ (Z50), not started: questions for the owner first.** Our own PipeWire filter-chain (10 biquads) replaces the host script, so: (1) keep balance, mono, channel swap, "dynamic EQ" and the night/balanced dynamics the contract inherited, or only the 10 bands and presets? (2) Which presets? (3) The chain becomes the default output while on; it is a PipeWire config drop-in, so it changes the owner's audio routing and needs them present to try. Plan once answered: a generator for the drop-in, gains changed live with `pw-cli set-param`, state in the core, and a check on a private PipeWire with a null sink so the live audio is never touched.

# 13 November 2026 · Opus: S5 step 1, OSD levels for the island (branch `s5-osd`, owner away)

- **Built (Z172).** `adapters/quickshell/OsdChange.js` (which change is an event), `QuickshellOsd.qml` (volume, mic from Pipewire), `adapters/dms/DmsOsd.qml` (adds brightness from DMS), `DmsBrightnessMap.js`. `DmsAdapter.osdWanted` (bound to `ZAETHERION_ISLAND` in `shell-dms.qml`) creates it at start; `QuickshellAudio.setVolume/setMuted` hush it for 2 s. The island's OSD face and queue entry were already there.
- **DMS link (S9a).** DMS sends brightness changes as `brightness.update` (`{device}`), which the link dropped as "unsubscribed". `<service>.update` now belongs to its service: cached, passed on and dropped with it; `DmsFeed.update` exposes it.
- **Checks.** `test_osd_change.py` (7), `test_dms_brightness_map.py` (6), a new S9a machine test. Full suite: 910 of 911; the one failure was `test_shell_dms` (its copy of the adapter block lacked `osdWanted`), fixed and rerun alone. Live probes against the real Pipewire and DMS (owner away; each change undone): a volume step, mute and unmute gave exactly one event each and none at start (volume back at 0.28); `dms ipc call brightness decrement/increment 5` gave 0.95 then 1 (back at 100 %). `brightnessctl` changes are not reported by DMS at all.
- **Found.** A `DmsFeed` declared in the same file as its `DmsLink` registers before the link's `Component.onCompleted` resets its machine, so it never subscribes. Real adapters create domains after the link, so nothing live is affected; worth fixing in `DmsLink` (keep `feeds` across the reset).
- **For the owner.** (1) While FART is open, an OSD waits with its time banked (Z161's rule for ordinary events) and shows after FART folds, a stale level. Drop OSDs that couldn't show instead? (2) Turning ours on means turning DMS's own OSD settings off (Z172); not done.
- **Next in S5.** Media keys (already DMS's `dms ipc`), the hover-only states (caps/num lock, airplane, power profile, Z24), the EQ filter-chain. Not started.

# 13 November 2026 · Opus: quiet DMS, so our notification server can hold the name (owner away; not live)

- **Problem.** DMS has no switch for its notification server, and Quickshell won't take the name from a running owner (Z169), so ours could never go live beside DMS.
- **Quiet DMS (Z171).** `tools/dms_quiet.py build` copies the UI the running DMS uses and removes its one `NotificationServer` object; everything else in DMS is unchanged. It refuses a DMS it doesn't recognise, never builds from a quiet copy, never writes over a folder it didn't make. Output: `~/.local/state/zaetherion/dms-quiet` (not checked in). The supervisor already passes `FART_RESIDENT_DIR` to DMS as `DMS_SHELL_DIR`.
- **Checks.** `tests/test_dms_quiet.py` (4). `tools/dms_quiet_check.py` in the nested Hyprland on a private bus: 12/12 (stock DMS takes the name as a control; quiet DMS comes up, stays up 8 s, leaves the name free, no NotificationService errors in its log; a Quickshell server then takes the name and receives a notify-send; the session's own server untouched). Full suite: 897 OK.
- **Not done.** Nothing on the live session changed. `docs/S4_GO_LIVE.md` has the steps for when the owner is present: main checkout to `s0-seed` (Astra's uncommitted docs there first), build the copy, restart the core with three settings, the `notify-send` matrix, and how to go back.

# 13 November 2026 · Opus: S4 merged into s0-seed; test tools can no longer stop the owner's DMS

- **Merged.** `s4-notifications` (renumbered to Z166–Z170, then brought up to date with the palette work) fast-forwarded into `s0-seed` at `373cc63`. Full suite on it: 889 OK. Not pushed.
- **What stopped DMS at 09:13.** A `tools/smoke.py` run from the main checkout by the other agent there: its session log shows the run starting at 09:13:16, DMS logged "received terminated" at 09:13:24, and `e6c86ea` followed at 09:14:54. Its shell had inherited the live core's `FART_SUPERVISE=dms`; `smoke.py` built its env from `os.environ`, so the private test core supervised the real DMS and stopped it on exit.
- **Guard (branch `s4-dms-guard`).** (1) `smoke.inherited_env()` drops every inherited `FART_*`; `prepare()` uses it, so every tool built on it (keytest, faces, shots, demo_frames, dms_smoke, overdrive) is covered, and `measure/cold_breakdown.py` strips them inline. (2) `fartd.supervise_allowed`: a fixture-host core ignores `FART_SUPERVISE=dms` (logged) unless `FART_SUPERVISE_FIXTURE=1`; `supervisor_check.py` opts in. (3) `fartd.view_env`: the view, and so apps launched from the shell, no longer inherit `FART_SUPERVISE`.
- **Checks.** `tests/test_supervise_guard.py` (4 tests, one end to end with a fake `dms` that must not start); it fails with the guard turned off. Full suite: 893 OK.
- **Next.** Going live with our notification server, with the owner present.

# 13 November 2026 · Fable: s8-palette merged into s0-seed, with three rule fixes

- **Merged.** `s8-palette` (Astra: palette picker inside FART, shared palette state, AMOLED studies; Z162–Z165) into `s0-seed` with the owner's OK. Not pushed.
- **Review.** Astra's own tests passed. Three project laws failed on the branch and are fixed in the commit after the merge, not on Astra's branch: `core/palette_catalog.py` named a host (`catalogue()`'s parameters are now `presets`, `themes`, `generated`); `PreferencesPane.qml` animated with a raw `Behavior` (now a `Tween` gated by the panel); `view/shell/qmldir` and `view/ui/qmldir` were not in the generator's order.
- **Checks.** Palette, architecture, layout, contract, command, verbs, island, daemon and cue tests: 88 OK; `make_qmldirs.py --check` clean. The pane's grow animation was not looked at after the `Tween` change. The full suite has not been run on the merged tree.
- **Numbers.** S4 (branch `s4-notifications`) also used Z163–Z167; it renumbers to Z166–Z170 when it is brought up to date with this branch.

# 13 November 2026 · Fable: S4 steps 3 and 4, the island and FART's Inbox (owner OK'd the captures)

- **Island.** `IslandEvents`: the showing time comes from the item (`timeout`: 0 stays until dismissed, absent means our 5 s), a replace-id (same id, new `time`) refreshes the card, an item that leaves the Inbox leaves the island, and only a `live` item offers actions or reply. `IslandExpansion.pictureShown` → `keepImage`. Both shells send the island's and FART's alert-card actions to `notifications.invoke`. No drawing changed: the card already had actions, reply and a picture slot.
- **Inbox.** `view/rooms/InboxAnswer.qml`: a button per action and a reply field for a live item; "Actions in host center" only for mirrored items. The room shows the item's picture (40 px) and hides the host-centre links unless the source is the mirror.
- **Fixture.** `shell-island-fixture.qml` gained `pictureNotification <ms>` and `closeNotifications`; its state counts only real actions.
- **Checks.** `tests/fixtures/island/NoticeTest.qml` (8 checks), `tools/cuetest/InboxAnswerTest.qml` (5 checks); related suites 132 OK. Nested Hyprland: 5 island captures, 0 QML errors. The Inbox frame shown to the owner was offscreen (the nested capture caught FART on Home).
- **Live session, 13 November.** DMS stopped cleanly at 09:13:24 (supervisor: `stopped`, code 0, then `held`) while my notification tests and a full suite run were going. I did not find what sent the stop; nothing in the S4 tests names DMS. `zaetherion start` brings it back. Worth finding before the next long test run.
- **Next.** Going live with the owner: resident view on, `FART_NOTIFICATION_SERVER=1`, DMS's own notification server out of the way. Open: how DMS's server is kept off while DMS runs (it has no switch).

# 13 November 2026 · Fable: S4 step 5, sound; pictures kept; the adapter side of answering

- **Sound (Z170).** `Inbox.ingest` decides what is heard (`on_sound`): not low urgency, not a replace-id, not a sender with `suppress-sound`, and under do-not-disturb only critical. The core emits cue `notify.normal` or `notify.critical` (new kind `notice` in `core/sfx.py`, switched per cue like UI cues; mapped to freedesktop sounds in `adapters/serpantinum/core.py` `NOTICES`).
- **Pictures.** Contract call `keepImage(id, picture)`: a card that draws a notification's picture offers it; `DmsNotifications` saves raw-pixel pictures with `grabToImage` to the path `notif.ingest` returned, then `notif.image`. The contract's `image` is now a URL (`file://…` or the live `image://qsimage/…`). Ids must match `[A-Za-z0-9_-]{1,64}`: they are also the picture's file name (no hashlib: it cost the core 4 MiB and broke its memory budget).
- **Layout law.** `tests/test_layout.py`: only `adapters/quickshell/QuickshellNotificationServer.qml` may hold a `NotificationServer`, it must be off by default, and only `DmsNotifications.qml` may use it, behind `FART_NOTIFICATION_SERVER=1`.
- **Checks.** Matrix now 14 tests (sound for the three urgencies, `suppress-sound` and do-not-disturb, raw pixels kept across a view restart and deleted on dismiss, a private app's pixels never written). Core notification tests 31, sfx tests updated.
- **Waiting for the owner's look.** Steps 3 (island) and 4 (FART's Inbox) are built and tested in the working tree but not committed: captures first.

# 13 November 2026 · Fable: S4 step 2, our notification server; the notify-send matrix passes offscreen

- **Built.** `adapters/quickshell/QuickshellNotificationServer.qml` (Quickshell's server, the live notifications, a flood guard), `QuickshellNotification.qml` (one live notification: its Inbox fields, actions, reply, dismiss, the transient timer) and `NotificationTiming.qml` (default showing times). `adapters/dms/DmsNotifications.qml` joins the server to the core: `notif.serve` on connect, `notif.ingest` on arrival and on replace-id, `notif.closed` on close. The contract gained `source` and `invoke(id, action, reply)`; do-not-disturb is real (`notif.dnd`).
- **Off by default.** The server runs only with `FART_NOTIFICATION_SERVER=1` (Z169). The live session is unchanged and DMS still owns the name.
- **Taking the name.** Quickshell waits behind a running owner and takes the name when it leaves. The core compares the name holder's pid with the view's (`Inbox.holder_pid`), so the mirror keeps working until our server really holds the name, then stands aside.
- **The matrix.** `tests/test_notification_server.py` (11 tests, about 6 s): a private dbus-daemon, a private core, the harness as that core's resident view (`tools/notiftest.py`, `tools/dmstest/NotificationHarness.qml`), senders `notify-send` and `gdbus`. Covered: three urgencies and their showing times, the sender's expiry time, transient leaving, two actions answered back to `notify-send`, inline reply (`NotificationReplied` seen on the bus), images as a file, an icon name and raw pixels, replace-id, close from either side, do-not-disturb, items outliving the view and the core, and waiting behind another server then taking over.
- **Found.** The core accepts only the view it spawned, so the tests run the harness as the resident view. Quickshell uses the reply action's label as the reply placeholder. A replace-id changes the live notification's properties in place.
- **Not yet.** Raw-pixel pictures are shown from the view while live but not yet saved to disk (step 3, when a card draws them). The island and FART's Inbox do not use actions, reply, images or the showing time yet. No sound yet.
- **Checks.** Notification, bus, adapter, contract, architecture and island tests: 97 OK. qmllint: no syntax diagnostics on the new files. Full suite on that commit (`41f56bf`): 865 of 866; the one failure was the inherited layout law "no QML claims the notification server", replaced in the next commit by a law that allows exactly our one gated file.
- **Next.** Step 3, the island: showing time from the item, actions, reply, picture. Captures to the owner before that commit.

# 13 November 2026 · Astra: S8 palette picker complete on `s8-palette`

- **Built.** One stored palette and published topic; `zaetherion palette <name>` / `palette list`; settings section inside FART with hover/arrow preview, click/Enter save, and rollback on close, fold or disconnect. Installed palette readers live in the read-only common adapter. Missing/invalid sources are silently omitted; Amoled Black remains the default. Z162–Z165 record the choices.
- **Checked.** 15 palette tests cover storage, topic, CLI process, missing entries, preview ownership/cancel, keyboard selection and Design colour changes. The 69 related core/view/island/layout/architecture checks pass after enabling `QT_LOGGING_RULES=qml.debug=true` for the architecture harness (its markers were otherwise suppressed). Ten offscreen smoke rooms pass with that logging enabled; no binding/type/reference errors. Qt 6 qmllint: zero `syntax*` diagnostics. Nested captures were shown before the UI commits; the owned nested session is no longer running.
- **Look/evidence.** Ten original true-black studies and five installed-palette readability checks are in `docs/captures/s8-palette/`; normal/muted/accent text meets 4.5:1 on those five. `tools/palette_capture.py` reproduces the comparison in nested Hyprland using inert fixtures. The local install supplied 94 static presets plus Matugen's existing generated colours; its empty Nightfox file was omitted without error. No host files copied or changed, live controls actuated, installs, push or merge.
- **Left / next.** The owner chooses which AMOLED studies to retain; none was chosen as a new default. Opus reviews and merges `s8-palette`. Catalogue changes are picked up on core restart; DMS themes currently use their declared dark default flavour/accent. Existing unrelated island-diagnosis files remain uncommitted.

# 12 November 2026 · Fable: S4 step 1, the Inbox in the core

- **Plan agreed with the owner.** S4 in six steps: core store, server in the adapter, island, Inbox room, sound, the `notify-send` matrix. Decisions Z166–Z168. Work is on branch `s4-notifications` (worktree `zaetherion-shell-s4`, cut from `s0-seed` `e868b7d`).
- **Built (step 1).** `core/notifications.py` is now the `Inbox`, the one list. The busctl `Mirror` and `BusctlSource` moved to `core/notification_mirror.py` and feed it; the mirror ignores calls while our server is attached. New operations: `notif.serve {ids}`, `notif.ingest {id, appName, summary, body, urgency, actions, reply, icon, image, timeout, transient}` (returns `imagePath`, empty when the item is never written), `notif.image {id}`, `notif.closed {id}`, `notif.dnd {on}`. Items gained `actions` [{id, label}], `reply`, `icon`, `image`, `timeout` (ms, -1 = ours), `live`, and urgency `low`. The snapshot gained `source` ("server" or "mirror") and `dnd`.
- **Rules.** The view forms ids that are unique across its restarts; the core treats them as opaque. Only the serving client may ingest, close or attach an image. When that client disconnects, items stay but stop being live, and transient ones go.
- **Checks.** `tests/test_core_notifications.py` 28 tests (11 mirror, 17 server) and `tests/test_core_busctl.py` pass. The full suite on that commit (`c80db40`): 853 of 854; the one failure was the core's memory budget (29.4 MiB, limit 25), fixed in step 2 by not importing hashlib.
- **Live session.** Untouched. DMS still owns the notification name, and it has no switch to give it up; going live is a later step with the owner present.
- **Next.** Step 2: `adapters/dms/NotificationServer.qml` on a private bus (check how Quickshell treats replace-id and whether it can take the name from a running owner), then the island, the Inbox room, sound and the matrix.

# 12 November 2026 · Astra: current-code plateau rechecked; CAVA-inclusive CPU still over budget

- **Scope/source.** Measured detached `eb09501`, excluding concurrent shared edits. The allocator default and 20 Hz settings were already applied in `946feb7`. `DmsAdapter` uses `QuickshellMedia`, which launches `tools/cava.conf`; the resident view uses `spawn_quickshell`'s child-only allocator default.
- **Results.** After 100 Home open/fold cycles: **328.1 MiB RSS / 127.5 PSS / 101.4 Private_Dirty**, including 225.7 MiB shared mappings. Three 30-second windows at 20 Hz with private synthetic PCM: **view 4.90%, CAVA 1.47%, combined 6.36%** of one core (combined range 6.09–6.83%). The 30 Hz control averaged 9.45% combined. Existing 24-bin fixture: 4.72%; rest: 0.02%. The **5% live media budget is not passed**; real audio capture and full DMS remain unmeasured.
- **Artifacts.** Updated [diagnosis](docs/ISLAND_DIAGNOSIS.md); [samples/method](docs/measurements/island-eb09501.json), [already-applied measured runtime diff](docs/measurements/island-eb09501-runtime-already-applied.patch), [proposed empty-owner-value regression test](docs/measurements/island-eb09501-proposed.patch), and [experimental CAVA fixture diff](docs/measurements/island-eb09501-experiment.patch). No new runtime patch is needed to obtain these results.
- **Checks/cleanup.** 28 core-view, five offscreen island and three DMS-entry tests passed; ten offscreen rooms passed; zero Qt 6 `syntax*` diagnostics; nested configerrors empty. Known private-home/font/portal/text-input warnings only. Owned views, CAVA, PCM feeders, private bus/services and nested compositor stopped; detached worktree removed. Shared runtime files untouched; no installs, live playback/audio/config/power changes, staging, commits or pushes.
- **Next.** Profile the remaining view-update/render cost with the saved synthetic CAVA fixture; recheck newer shared edits separately. Do not infer a live-session pass from the simulated fixture.

# 12 November 2026 · Opus: Z161, DMS's frontend logic with our look; only critical interrupts a panel

- **Owner's answers.** The owner decides the look only; Opus makes the behaviour and structure calls and records them. Only critical events interrupt an open panel.
- **Decision.** Z161 (DECISIONS.md): S4–S8 start from DMS 2.1.0's QML (MIT), redrawn in our design. The island keeps our queue (Z23); DMS's `IslandController` keeps one face plus one return slot and would drop waiting events. To take from it later: load-before-open panels dropped when idle (S6), the media blip delay, hover held after a face swap.
- **Built.** `IslandQueue.ceiling`: entries below it wait, their dwell banked. While docked (FART grown from the island) the island sits under FART, so before this an event shown there spent its time unseen: now ordinary events wait, and a critical one is handed to FART (`IslandSurface.coveredEvent`, through `IslandWindow` to `Overlay.islandAlert`), where `FartAlertDrop` flashes the header red once and drops the card from under it. At rest a critical event flashes the island red once (a second `IslandFrame` in `Design.danger`; `IslandFrame.fill` is new). Motion off: a 600 ms red hold, no fade. Tray menu and session card moved from -1 to `priority.held` (5), so a critical event now interrupts them (the tray menu closes as Z157 says; the session card returns after).
- **Licence.** DMS's relicensing note's two adapted files are `Common/suncalc.js` (BSD-2, V. Agafonkin) and `DCommon/Common/fzf.js` (BSD-3, fzf-for-js). DMS's MIT text is already in `licenses/DUX-SHELL-MIT` (since `03a54d4`, for `IslandTrayMenu.qml`); checked byte-identical to upstream `duxlabs-dev/dux-shell` `LICENSE` on 12 November 2026 (sha256 `4cee9628…26bfa`; the old AvengeMedia/DankMaterialShell address redirects there). Upstream is now v2.2-beta; the unpacked QML here is v2.1.0. Each new copy adds its file and source commit to NOTICE's Dux Shell section. If `suncalc.js` or `fzf.js` is copied, add their BSD notices to `licenses/` too.
- **Checks.** Full suite 837 OK with `FART_*` unset; island tests gained 4 queue checks (critical interrupts a held face, a panel holds an ordinary event with its time banked, critical shows over a panel, the event resumes with its time after). qmllint 0 syntax diagnostics. Nested Hyprland (`shell-island-fixture.qml`, ZTEST, no D-Bus/Pipewire), 13 captures shown to the owner, 0 QML errors: ordinary waits behind the tray menu, critical interrupts and closes it, ordinary shows after; critical over the session card, card returns; nothing shows over a grown FART (shots identical), the waiting notice shows after the fold, then rest. No power action ran.
- **Nested (critical look).** Second run, 0 QML errors, 4/4: the island flashes red then shows the critical card; FART open: the ordinary notice is not handed over, the critical one is, the header flashes red, the card drops from under it, expires after 5 s, the ordinary notice shows on the island after the fold.
- **Maintenance.** The flash is one component (`CriticalFlash`) used by the island and FART; FART's drop reads `Shell.headerBottom`, the same edge the empty-header fold uses. `SurfaceTest` covers the handover (critical handed to FART, ordinary held, events resume in order after the fold).
- **Known flake.** `test_astra_cues` `temporal.done.finite` fails about 1 run in 3–6, on the previous HEAD too (1/6), so it is not from this change. Full suite: 836 OK plus that flake.
- **Next.** S4 notifications from DMS's notification QML, recording each copied file and its upstream commit in NOTICE.

# 12 November 2026 · Opus: the view follows DMS's socket through the core (S2 merged)

- **Merged.** `s2-host-adapter` into `s0-seed` (`f2d9969`) with the owner's OK; 837 tests OK on the merged tree.
- **DMS's socket.** The core always offers the `supervisor` topic (`{"children": {}}` when it does not supervise DMS), and `CoreClient` subscribes to it (`supervisorData`). `shell-dms.qml` binds `DmsAdapter.socketPath` to `children.dms.socket` while a core is connected, else to `DMS_SOCKET`. A subscription naming an unknown topic fails whole, hence the always-offered topic.
- **Checks.** Full suite 837 OK. Nested Hyprland, real core with `FART_RESIDENT_VIEW=1` and `FART_VIEW_ENTRY=shell-dms.qml`, supervising a real DMS (private home, bus and folders, no system bus): 11/11. The view connects to DMS's socket; DMS killed → back under a new socket → the same view process reconnects; the bar stays hidden through it (the new DMS reads the saved setting); core stop shows the bar, nothing left running.
- **Turning it on (owner's go, owner present).** `tools/zaetherion.py` `start_core` sets `FART_RESIDENT_VIEW=1` and `FART_VIEW_ENTRY=<repo>/shell-dms.qml`; then `zaetherion restart` or a fresh login, and the real checks listed in the S2 entry. Rollback: unset both.

# 12 November 2026 · Opus (S2, taking over from Sonnet): step 6, `shell-dms.qml`; review

- **Built (Sonnet).** `shell-dms.qml` is `shell.qml` with `DmsAdapter { id: adapter; core: client; role: "shell" }`; `tests/test_shell_dms.py` fails when the two drift apart. Nothing starts it yet. Committed by Opus after the full suite (824 OK, with this file present).
- **Nested check (Opus).** Against the DMS stand-in, no core, no D-Bus or Pipewire: the island at rest on `ZTEST`, a click grows FART, an empty header click folds it, the process stays up, the stand-in sees one subscription (`network`), no QML errors and no `serpantinum` call. Sonnet's blank capture was the setup, not the adapter: without a core or `ZAETHERION_ISLAND_OUTPUT=ZTEST` the island goes to the focused output, which is the hidden nested window, not `ZTEST`. A click sent 50 ms after the pointer arrives is dropped while the island grows (the known first-click limit); after 0.9 s of hover it opens. The Pipewire connection error in that log is the test cutting Pipewire off.
- **Review (Opus).** Link machine: the event connection is reopened only from `closed`, so a close and the stale `eventsDown` it posts cannot hit a new connection; every request replies once (`reply` deletes the callback first). Leases: `spectrum`, `position`, `mixer` and `menus` run only while held; network state is un-leased (`wanted: true`) as the island shows it at rest; `details` and `scan` follow their leases. Contract: `test_contract` checks `DmsAdapter` like Serpantinum. Session actions match Z158.
- **Not built.** Step 5: bluetooth, `power.brightness`, `power.nightLight`, idle inhibit (`DmsPower`'s setters are empty). Weather, osd, capture, palette (the built-in Amoled Black applies), motion, sfx, clockGeometry, hostActions, the equalizer. Do-not-disturb (`setDnd` only logs).
- **For the switch-over (Opus).** The core does not hand the view DMS's socket. `DMS_SOCKET` is unset for a view spawned by `fartd`, so network would read offline. The resident view outlives DMS restarts, so it must follow `supervisor.children.dms.socket` (SUPERVISOR.md §13, F2's first ask); `CoreClient` does not subscribe to `supervisor` yet. The resident view's entry is `shell-dms.qml` (`FART_VIEW_ENTRY`).
- **Needs the owner present.** Real `network.wifi.toggle`, `connect` and `scan`; `dms ipc call lock lock` and `hl.dsp.exit()` on the live session; the tray with a real item and submenus; media, audio and UPower with real D-Bus and Pipewire. Z9 should say at the merge that a newer DMS keeps working (marked untested) and an older one is switched off.

# 12 November 2026 · Sonnet (S2): step 4, notifications

- **Built.** `DmsNotifications` reads the core's mirror (`core.notificationsData`) exactly as the Serpantinum one does; `markAllRead` and `dismiss` go to the core. `openHost` runs `dms ipc call notifications toggle`, the session's own Super+Shift+N bind. **Do-not-disturb is not wired**: `setDnd` only logs a warning, since there is no notification server of ours until S4 and I did not guess a DMS call. `dnd` stays false. No notification server was built.
- **Tests.** Contract and static checks as for the other domains; the adapter test confirms the domain is `DmsNotifications` and reads unavailable when there is no core.
- **A flake to know about.** The step 3 full run failed once on `test_core_ignite.InCore.test_a_release_with_the_view_absent` (core code, untouched by this branch). It passed 15 of 15 on its own and in the full runs before and after; it looks like a timing flake under load. Step 3 was committed before I looked at it; the step 4 run below is the confirmation.
- **Suite.** 824 tests OK with `FART_*` unset (run by Opus on this tree after Sonnet stopped); `test_core_ignite` passed.

# 12 November 2026 · Sonnet (S2): step 3, the session actions

- **Built.** `DmsPower`: `suspend`, `reboot`, `powerOff` run `systemctl suspend|reboot|poweroff`; `logout` is `Hyprland.dispatch("hl.dsp.exit()")` (Z158). **`lock` runs `dms ipc call lock lock`**, the command the session's keybinds already use; this is a stand-in until S7 decides lock (OPEN F2-5), and the island's Lock button depends on it.
- **Tests.** `test_dms_adapter.SessionActions` runs the four command actions with stub `systemctl` and `dms` as the only things on PATH, and checks each stub saw exactly its arguments; logout is checked from the log of the refused dispatch (no compositor in the run). A static test pins the exact command list. Nothing real was suspended, locked or dispatched.
- **Not checked.** `dms ipc call lock lock` against a live DMS, and `hl.dsp.exit()` on the live session: both only with the owner present.
- **Next.** Step 4, notifications from the core's mirror.

# 12 November 2026 · Sonnet (S2): step 2, the Quickshell and Hyprland pieces

- **Built.** `adapters/quickshell/`: `QuickshellMedia` (MPRIS, the `position` and `spectrum` leases), `QuickshellAudio` (Pipewire, the `mixer` lease), `QuickshellTray` (SystemTray; the `menus` lease opens the item named by `menu(id)` through `QuickshellMenuNode`, one node per menu level, entry ids are index paths such as `2.0`), `QuickshellPowerSource` (UPower battery and profile). `adapters/hyprland/`: `HyprlandWorkspaces`, `HyprlandKeybinds`. `adapters/dms/DmsPower` (battery and profile for now) and `DmsAdapter` now fills media, audio (deferred), network, workspaces, keybinds, power, tray, system, lyrics (deferred) and clipboard (deferred, cliphist).
- **Reuse, not move.** The Quickshell-only Serpantinum files were copied with the host calls dropped (listed in NOTICE). The Serpantinum adapter is untouched; it is deleted only with the owner's approval.
- **One change from the copy.** `switchTo` no longer calls the `serpantinum` CLI. It runs `hl.dsp.focus({ workspace = "<id>" })`, the form the session's own binds use, after checking the id against `[A-Za-z0-9_.:-]+`.
- **Checked live, in the hidden nested Hyprland only.** The harness ran against the nested compositor: `switchTo("2")` made workspace 2 active and `switchTo("1")` moved back; an id carrying a command is refused before anything is dispatched. The nested instance has no described binds, so the keybind list read 0 there (the copy of the parser is unchanged).
- **Not exercised.** The tray: the offscreen runs have no StatusNotifier host, so `QuickshellTray` and `QuickshellMenuNode` load and report no items, but a real item with a menu and submenus has not been clicked through. Check it with a real tray application in the nested session. Media, audio and UPower were loaded with no D-Bus or Pipewire, so only their wiring is covered.
- **Tests.** `test_contract` now also checks `DmsAdapter` (every contract method implemented; the domains left on their placeholders are listed in `DMS_UNBUILT` and a test fails when one is built but still listed). `test_dms_adapter.Composition` loads the adapter and checks each domain's implementation and that nothing logs an error.
- **Next.** Step 3, the session actions of `DmsPower`.

# 12 November 2026 · Sonnet (S2, branch `s2-host-adapter`): step 1, the DMS link and network

- **Built.** `adapters/dms/`: `DmsLinkMachine.js` (the pure link machine, DMS_ADAPTER.md §2, every row), `DmsLink.qml` (the only file with a `Socket`; runs the machine's effects, one timer, replies exactly once), `DmsFeed.qml` (one per service; `wanted` is a lease expression), `DmsNetwork.qml` with `DmsNetworkMap.js` (§4) and `DmsToggle.js` (the toggle pattern of §1, kept pure so Node can test it), and `DmsAdapter.qml` (so far: `network` only). `tools/dms_replay.py` now honours `services` on subscribe, writes a request log and takes a script (synthetic replies, silent methods, events after a method). `tools/dmstest.py` and `tools/dmstest/*.qml` drive the adapter over `qs ipc` against the stand-in. `tools/dms_smoke.py` loads all rooms with DMS's network domain.
- **Tests.** `test_dms_link_machine` (44: one per row L1–L10, R1–R5, S1–S11, one per invariant), `test_dms_network_map` (24, expected values computed from the fixture), `test_dms_replay`, `test_dms_contract` (static), `test_dms_adapter` (17: contract, leases, restart with SIGKILL, same-path return, old and newer DMS). Full suite 815 OK with `FART_*` unset. `tools/dms_smoke.py` exits 0 (no binding errors, `details` held on Devices and released, no action sent). qmllint 0 syntax diagnostics.
- **Choices the note left open.** The event connection's retry counter resets on the first event after a reconnect (not on connect), so a server that accepts and drops cannot make a tight loop. A dropped event connection keeps the last snapshots (stale for at most the 2 s backoff); a lost request connection clears them. DMS greets every connection, the event one too; that line is ignored. `done(result, error)` passes `""` for no error.
- **Not checked against a real DMS (owner present).** `network.wifi.toggle`, `network.wifi.connect`, `network.wifi.scan`: shapes come from DMS's QML. `hostActions.open("wifi")` (an unknown network) does nothing until the host actions exist (S6).
- **Next.** Step 2: `adapters/quickshell` and `adapters/hyprland`.

# 12 November 2026 · Opus: interim switch-over built, off by default (Z159); Astra's fixes applied

- **Owner's answers.** The interim plan (Z159): DMS keeps its own UI and only its bar is hidden; the island and FART run as one always-on view. The bar is hidden only while the island is up. Astra's proposals applied as written, without re-measuring.
- **Astra's fixes** (`946feb7`). The view starts with `MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000` unless one is set; CAVA and the island fixture's spectrum run at 20 Hz. CAVA's own process is still unmeasured, so the 5% live media budget is not claimed.
- **Resident view.** `FART_RESIDENT_VIEW=1` (read by `core/fartd.py`): the core starts the view at once with `ZAETHERION_ISLAND=1`, never reaps it (idle or PSI), restarts it 1 s after an exit (three quick crashes stop the restarts), and ends it only on its own stop (`ViewManager.resident`, `keep()`, `stop()`). The `view` topic gained `resident`. Unset, nothing changes.
- **DMS's bar** (`core/dms_bar.py`). The owner's Main Bar is a DMS island bar, and DMS's `bar hide` refuses those (`BAR_IS_ISLAND`); `settings set` cannot edit the bar list. DMS watches `settings.json`, so the core sets `visible` on the bar with `id: default` (atomic replace, DMS's 2-space format, nothing else touched). Hidden while the view is `ready`; shown when it is not, at core start and at core stop.
- **Checks.** Unit: view 27 (resident, not resident, spawn env), DMS bar 5, all core tests (348), architecture 8, contract 9. Nested Hyprland, real core supervising a real DMS with its full UI (the owner's theme and wallpaper; private home, XDG folders and session bus, no system bus, weather off): 16/16. Today's bar; resident start hides it; hover, FART grown, header fold; a DMS notification sits top-right clear of the island; Fluid through the `island` verb; view killed → bar back in 10 ms, view back in 1 s → hidden; core stop → bar shown, nothing left running. No QML errors. Captures were shown to the owner and not committed (they hold the owner's wallpaper).
- **Not done.** Turning it on: `tools/zaetherion.py` `start_core` (or `tools/session-start`) sets `FART_RESIDENT_VIEW=1`, after `s2-host-adapter` is reviewed and merged (`shell.qml` still uses the Serpantinum adapter, and any `serpantinum` call restarts Serpantinum's daemon) and with the owner's go. Then a real login/logout check. A core killed with SIGKILL leaves the bar hidden until the next core start.
- **Next.** Review `s2-host-adapter` when Sonnet hands back (contract coverage, leases, the DMS link machine), merge with the owner's OK, then the turn-on above.

# 12 November 2026 · Astra: island memory and CPU diagnosis recorded

- **Report.** [Island memory and CPU diagnosis](docs/ISLAND_DIAGNOSIS.md), measured at `9662778` in a detached worktree. This is evidence for that revision, not a performance pass for the newer island integration. No implementation change was made.
- **Next-session kit.** [Continuation brief](docs/ISLAND_NEXT_SESSION.md) gives the investigation order, measurement controls, synthetic CAVA route, checks and cleanup. [Scrubbed evidence](docs/measurements/island-9662778.json) preserves 10 runs and 108 samples without relying on temporary logs. Preparation HEAD was `4ef6920`; check fresh state before starting. Establish which spectrum source the current resident/DMS path uses before treating a CAVA-rate change as a production fix.
- **Memory.** With default jemalloc settings, folded Private_Dirty was 118.2 MiB idle, 166.3 after one cycle, 193.5 after 21 and 50, and 188.5 after 100: it plateaus. Live allocated bytes stayed around 56–57 MiB after first open. Both rooms release; object, Connection, Loader and Shape counts stay fixed; sampled leases and satellites are empty. Keeping Shell costs roughly 4 MiB of live allocations and room precompilation 2–3 MiB. Disabling island morphing did not help. Allocator/transparent-huge-page overhead dominates the larger resident footprint: the inherited jemalloc tuning reduced cycle-100 PSS/Private_Dirty from 222/188 to 135/101 MiB. The report separates RSS, shared mappings and driver allocations; the island still has no memory budget.
- **CPU.** Rest 0.03% of one core; Fluid media 6.53%; fixture spectrum generation without publishing 0.67%. At 20 Hz, the fixture used 4.33% with 24 bins and 4.37% with 56 active simulated bins. Changing Shape renderer alone still exceeded 5%. CAVA's separate process is unmeasured, so the live media budget is not yet passed.
- **Proposal only.** The report contains a minimal diff for a child-process jemalloc default that preserves an existing value, a 50 ms fixture timer, and CAVA at 20 Hz. None is applied or recorded as an owner decision.
- **Verification and cleanup.** Nested GPU measurements, pointer cycles through 100, IPC control through 200, allocator/GC/cache probes, and morph/room/keepShell/precompiler ablations completed. No unexpected QML errors; nested `hyprctl configerrors` empty. The nested compositor was stopped and detached worktree removed. No live-session changes, staging, commits or pushes. This checkpoint adds documentation and scrubbed measurement evidence only.
- **Next (diagnosis).** Revalidate the proposed allocator settings and 20 Hz source rate on current code, then measure the separate CAVA producer before claiming the 5% live media budget passes. Opus's owner-review/session-enablement task below remains pending.


# 12 November 2026 · Opus (Sol's items): keytest race fixed; island settings in the core

- **`test_keytest` `timers.loaded`.** A timing race, not a broken room: 1 failure in 3 standalone runs, and a failed load skipped the Timers walk. Each room now gets up to 20 ticks of 300 ms; any extra wait logs `KEY_SLOW` (seen once: Timers, 300 ms). 4/4 runs passed 172/172 (`4fa474a`).
- **Island settings (Z155).** `core/island.py` keeps `form`, `edge`, `placement` and `screen` in `island.json`, published as the `island` topic (`CoreClient.islandData`). The `island` verb sets them from FART's command line or `zaetherion island fluid|angular|top|bottom|notch|floating|screen <name>|screen auto`. `shell.qml` binds `Design.form`, edge, placement and screen to it; the `ZAETHERION_ISLAND_*` variables only stand in while no core is connected. Tests: `tests/test_core_island.py`.
- **Checks.** Core, verb, contract and CLI tests OK; nested `shell.qml` wiring 11/11; qmllint 0 syntax diagnostics.
- **Next.** Turning the island on in the ZÆTHERION session, after the owner sees how it will look.

# 12 November 2026 · Opus: tray menu and session card grow from the island (Z157, Z158)

- **Tray menu.** No longer a popup window: a `tray` queue entry (priority -1, no dwell) whose face is `IslandTrayMenu` (unframed, capped at the 160 px depth). `IslandWindow` gained a `HyprlandFocusGrab` for held faces, armed 100 ms after the island holds the keyboard (Hyprland clears a grab while focus is moving); `tests/test_contract.py` allows `Quickshell.Hyprland` there for that grab only.
- **Session card.** A `session` queue entry from the island's power glyph. `PowerDomain` gained `suspend`, `logout`, `reboot`, `powerOff`; Serpantinum runs `systemctl suspend|reboot|poweroff` and Hyprland's `hl.dsp.exit()`; the fixture records only. **The DMS adapter (`f2-dms-adapter`) must implement the four new calls.** The island's `openPower` signal and the fixture's floating session-card preview are gone; the fixture gained `power` and reports `powerCalls`.
- **Checks.** Nested, both forms: session card 18/18 (0.4 s and 0.65 s presses do nothing, a full hold fires, click locks, Esc and click outside fold, Enter hold on Reboot), tray 10/10, `shell.qml` wiring 11/11, docked focus 6/6. Island, contract, layout, qmldirs OK; qmllint 0 syntax diagnostics. The virtual pointer in the nested kit gained `hold:<ms>`.
- **Next.** Opus took over Sol's items: `test_keytest` `timers.loaded`, storing the island's settings with FART's, and turning the island on in the ZÆTHERION session (show the owner first).

# 12 November 2026 · Opus: Super+Shift+I bound, island actions confirmed (Z156)

- **Owner.** Confirmed long-press `sticky` ignite, power to the host's power menu, and notification actions waiting for S4 (Z156). Sol is no longer on the project; Sol's open items (the `test_keytest` `timers.loaded` failure, storing the island's settings with FART's, and turning the island on in the ZÆTHERION session) have no owner yet.
- **Bind.** `shell.qml` has an `island` IPC target with `focus()`. Super+Shift+I runs `qs -p <repo>/shell.qml ipc call island focus`. Added to `session/hypr/zaetherion/fart.lua` and, with the owner's go-ahead, to the installed copy; `hyprctl configerrors` empty and the bind is listed. It does nothing until the island runs in the session (the view is not started there yet: `FART_RESIDENT_DIR` is unset, so DMS draws its own UI).
- **Fixture.** The session-card preview is a fixed layer card under the island instead of a floating window that Hyprland tiled to full height.
- **Checks.** Nested `shell.qml` wiring 11/11, including the focus call with the island on and off; qmllint 0 syntax diagnostics.

# 12 November 2026 · Opus: island in shell.qml (opt-in), island measured

- **Island in `shell.qml`.** Opt-in with `ZAETHERION_ISLAND=1`; without it the shell is the panel alone, so FART-next under Serpantinum is unchanged. Wired as the fixture: `adjacentIslandGap`, `islandRect`, `companionWindows`, `islandHasKeyboard`, `keyboardPeer`, `docked`. Until the daemon stores the owner's choices (Z155), `ZAETHERION_ISLAND_OUTPUT` (default: focused screen), `_EDGE` (`bottom`), `_PLACEMENT` (`floating`) and `_FORM` (`fluid`|`angular`) come from the environment. The ids in `shell.qml` are now `adapter` and `client`: inside the island's LazyLoader, `host: host` bound the island's own empty property.
- **Choices to confirm with the owner.** Island long-press ignites `sticky` Overdrive, or cuts a running one (the core's `panel` mode would end with the folded panel). Power opens `actions.open("power")`. Notification actions and replies only log a warning: the contract has no call for them until S4.
- **Checks.** Nested, with the fixture adapter swapped into a copy of `shell.qml`: off by default, on shows the island, click grows FART, empty header click folds it, Fluid form; 8/8, no QML errors. Full suite 707/708 with `FART_*` unset; the one failure is the known `test_keytest` `timers.loaded` (Sol).
- **For Sol.** The ZÆTHERION session (supervisor or launcher) should set `ZAETHERION_ISLAND=1` for the view. The Angular/Fluid choice and the island's screen, edge and placement belong in FART's settings (Z155). The Super+Shift+I bind is still the owner's to add.
- **Measured** (`docs/BUDGETS.md`, GPU sample). Rest CPU passes. Media in Fluid used 6.37% of a core against 5%, fixture timer included. Memory grows with open/fold cycles (+46 MiB PSS on the first, +27 over the next 20) and does not return to idle; the owner is giving that diagnosis to Astra.

# 12 November 2026 · Opus: header click folds FART, Framed only (Z155)

- **Owner's answers (Z155).** A click on empty space in FART's header folds it back into the island when FART grew from it (Z134 extended). Super+Shift+I keeps Z148. Fluid forgets the right-click clock/media choice on restart and shows media only while playing.
- **Removed.** `IslandWings.qml`, the Mirror and Sides arrangements, the fixture's `layout` call and `ZAETHERION_FIXTURE_LAYOUT`. Framed is the only arrangement.
- **Header click.** `Shell.qml` gained `headerEmptyClicked()`, from a MouseArea under the header's controls, enabled once the header is fully revealed. `PanelBody` closes on it only when grown from the island and open. Without an adjacent island nothing changes.
- **Checks.** Island, layout, contract and qmldirs 23/23; `qmllint` 0 syntax diagnostics. Nested: header fold 8/8 twice (three empty spots fold, command line and two chips keep FART open), docked focus 6/6, exact reply once.
- **For Sol.** The owner wants the Angular/Fluid choice (`Design.form`) stored with FART's settings by the daemon, so every surface reads one value. Opus will read it once you expose it. `test_keytest`'s `timers.loaded` failure (previous entry) is still yours.
- **Next.** Opus wires the island into `shell.qml`; island memory against `docs/BUDGETS.md` is measured separately.

# 12 November 2026 · Opus: FARTland // Fluid, even spacing (Z153, Z154)

- **Built and owner-approved.** FARTland // Fluid as a second form of the island (Z153), and one spacing rhythm with an optical lift for the flush notch (Z154). Captures and calls are in `docs/ui/README.md`.
- **Checks.** `test_island` 5/5, including the new `FluidTest.qml`. Layout, contract and qmldirs OK. `qmllint` reported 0 syntax diagnostics. Nested: docked focus passed 6/6, and an exact reply arrived once.
- **For Sol.** The full suite had one failure: `test_keytest` reported `timers.loaded` with an empty value, so the Timers room did not load in time. It fails the same way on `5f86e7e` and on `bd4ebdb`, which passed earlier the same day, so it looks environmental, not caused by the island. `BatteryMark` gained `rounded` (default off, so FART's header is unchanged), and `MaterialSymbol` gained `fill` and `weight` (defaults render as before).
- **Open for the owner.** Z134 (should a click on FART's header fold it back?), Z148 (should Super+Shift+I fold FART back and focus the island?), whether the right-click choice should survive a restart, whether Fluid shows media while paused, deleting `IslandWings.qml` along with the Mirror and Sides arrangements, and where the Angular/Fluid switch is stored.
- **Next.** See the owner's next-chat prompt: commit cleanup, the open questions, persisting the form, wiring the island into `shell.qml` with Sol, and island budgets.

# 12 November 2026 · Opus: island grows into FART; Framed, matte, Amoled Black

- **Owner-approved** (Z149–Z152): the Framed layout; the island widening into a bar and dropping into FART, then folding back; a matte fill; DMS Amoled Black as the built-in palette. The layout review and growth animation are in `docs/ui/` (see its README).
- **Jitter fixed.** The island's surface no longer resizes during morphs, and the island holds its shape while FART grows from it. Recorded at 60 fps in nested Hyprland: the centre held within 0.5 px, and both open and fold were monotonic.
- **Checks.** `test_island` 4/4, layout, contract and qmldirs OK, `qmllint` 0 syntax diagnostics. Nested: the docked focus handover passed 6/6, and an exact reply arrived once.
- **Open for the owner.** Z134: FART's header now covers the island, so should a click on the header's empty area fold FART back? Z148: should Super+Shift+I fold FART back into the island and focus it? The island is hidden while FART is open.
- **For Sol.** `Overlay` and `PanelBody` gained an island-growth path (`islandMorph`, `islandRect`, `islandFrom`, `morphRect`); without an adjacent island the panel behaves as before. When the island joins `shell.qml`, wire `docked`, `islandRect` and `keyboardPeer` as the fixture does. `IslandWings.qml` is unused now; deleting it waits for the owner's word. The Mirror and Sides arrangements are still selectable for comparison.
- **Next.** FARTland // Fluid (Z145) as a second form of the same island.

# 12 November 2026 · Opus: island reply fix, Angular pass and wider media pill

- **Reply bug fixed.** When an OSD covered a notification, keyboard interactivity dropped to None and then returned to OnDemand. Hyprland gives click focus to an OnDemand layer only after the pointer moves, so the field took focus in Qt while the window stayed inactive and Enter delivered nothing. A queued reply draft now keeps OnDemand. A field that takes focus in an inactive window briefly claims Exclusive. The field regains focus when its notification returns, and Send dismisses the notification. Hidden nested Hyprland ran Sol's exact steps 3 times and the no-second-click path 3 times. Each run delivered `Synthetic reply` once, and `configerrors` was empty. Hyprland still drops the first click when the island grows under a pointer that has not moved.
- **Look.** Brought the island up to the approved study and FART. The changes are the app name on an inverted ink tag, the fixed-light rim, face and facet, shoulder-safe insets, the notched rule, an ink tag for the first action, a full-width reply field, a blade meter and readout for volume and memory, a track tile, and ink-plane keyboard focus. The new shared parts are `FTag` and `FBlades`. Captures and notes are in `docs/ui/README.md` (Opus pass).
- **Owner review: media pill.** The pill now runs up to the centred clock instead of a fixed 104 px. Network moved to the right group beside the bell and battery, which keeps the resting width at Z66's 420 px. Hovered, the centre opens to 500 px, so the title keeps its room when the clock gains seconds and the wings sit outside it. With the synthetic title `Synthetic Fixture Track With A Long Title`, the visible text grew from 9 to 14 characters at rest and from 9 to 18 on hover. The clock stays on the screen centre. Captures are in `docs/ui/island-s3-media-pill.png`. Island, layout, contract and qmldirs checks passed 22/22. Nested checks passed docked focus 6/6, and an exact reply arrived once.
- **Checks.** `test_island` 4/4, including the new `ReplyTest.qml`. Layout, contract and qmldirs 18/18. `qmllint` reported 0 syntax diagnostics on the changed files. The full suite passed 707/707 in 581 s with `FART_*` unset. No daemon or test-infrastructure files were changed.
- **Docked focus (Z148, owner's choice).** Super+Shift+I with the panel open now moves the keyboard to the island and keeps the panel open. The first Esc returns the keyboard to the panel and the second closes it. `Overlay` gained `islandHasKeyboard` and `holdsKeyboard`, and the island gained `keyboardPeer` and `wantsKeyboard`. Only the fixture wires the two, because `shell.qml` has no island yet. Hidden nested Hyprland passed 6/6 three times with Esc. Separate runs confirmed that typing reaches the panel's command line after Esc and that a click outside still closes the panel. The reply check and plain island focus pass again. The full suite passed 707/707 again after this change, with `FART_*` unset.
- **For Sol.**
  - **Commit split.** At the owner's request, Opus committed only its own island files and its own HANDOFF entry. Sol's working-tree changes stay uncommitted and untouched. Opus's files:
    - Modified: `view/shell/IslandExpansion.qml`, `IslandSurface.qml`, `IslandWindow.qml`, `IslandRest.qml`, `IslandGlyph.qml`, `Overlay.qml`; `view/ui/IslandFrame.qml`, `view/ui/qmldir`; `shell-island-fixture.qml`; `tests/test_island.py`.
    - New: `view/ui/FTag.qml`, `view/ui/FBlades.qml`, `tests/fixtures/island/ReplyTest.qml`, `docs/ui/island-s3-opus-review.png`, `docs/ui/island-s3-opus-docked.png`, `docs/ui/island-s3-media-pill.png`.
    - Shared: the Opus sections of `docs/ui/README.md` and `HANDOFF.md`, and Z148 in `docs/DECISIONS.md`.
    - Opus did not change daemon, launcher, faces or test-infrastructure files. Never push.
  - **Nested kit.** `/tmp/zi-reply-opus/` holds `check.py` (modes `exact`, `noclick`, `wiggle`), `docked_focus.py` (Z148, add `outside` for the click-outside close), and `pointer.c` with its built `pointer`. `pointer` is a virtual pointer on the nested display that takes `click` or `move`. Run each script from the repo root with nested Hyprland started. `/tmp` does not survive a reboot. If these checks should stay, they belong in `tools/`, which is Sol's to decide.
  - **Fixture IPC.** `state` also reports `lastReply` (synthetic text only) and `keyboard` (`none`, `ondemand` or `exclusive`). `title <text>` sets a synthetic track title.
  - **Timing in the Z148 handover.** The island waits 60 ms after the panel releases before it requests Exclusive. The panel resumes its focus grab 100 ms after it retakes the keyboard. Both delays were measured in nested Hyprland 0.57.1 and are not tuned. Recheck them on the real session and with a slow frame. While the island holds the keyboard, a click outside does not close the panel.
  - **Still open.** When the island joins `shell.qml`, wire `Overlay.islandHasKeyboard` to the island's `wantsKeyboard` and `IslandWindow.keyboardPeer` to `Overlay.holdsKeyboard`, as the fixture does. The Super+Shift+I compositor bind is still unset.

# 12 November 2026 · Daemon shutdown and Angular reply checks

- Pausing the fixture daemon after `core.sock` disappeared but before it released `core.lock` reproduced a failed stop-then-start at `0baeef2`. The existing `tools/fart_next.py` diff waited for the lock and restarted cleanly under the same check. The separate `zaetherion` entry point still failed under the forced timing. The earlier reply-ordering failure’s exact cause remains unconfirmed.
- Added a launcher regression test for the shutdown gap and made the reply-ordering test print `core.log` if startup fails. All 12 daemon and 8 launcher tests passed. The first private full run found that the Faces smoke test loaded the installed Mocha preset. The test now supplies a synthetic preset from a private home, and the focused rerun passed.
- In hidden nested Hyprland, a typed draft kept its text through a synthetic volume OSD with the pointer held still. Enter submitted the original text exactly once, including leading and trailing spaces. Fullscreen hide and remap passed. The nested `configerrors` output was empty, Quickshell logged a Qt Wayland warning about disabling an unfocused text-input surface, and the compositor was stopped. The first click under a stationary pointer on a newly shown layer remains a separate compositor limitation, recorded in `docs/ui/README.md`.
- Rechecked Opus’s Z148 handoff in hidden nested Hyprland. The fixture focus request kept the docked panel open and moved the keyboard to the island. The first Esc returned focus to the panel and the second closed it. Exact reply submission and fullscreen hide and remap passed again. Nested `configerrors` was empty and the compositor was stopped. Qt logged text-input focus warnings during the run.
- The full private suite on the Z148 handoff (`0baeef2` plus overlay `27e186cf`) discovered 707 tests in 581.330 s, with 703 passed and zero failures. Four checks skipped because the private home omitted the installed Serpantinum clock and FART archive. All 4 offscreen island tests and 10 room smoke checks passed. Qt 6 `qmllint` reported zero syntax diagnostics across 103 QML files. Issue #23 was closed after checking the owner’s recorded keyboard layout decision in OPEN 11.
- The owner set DMS functionality and responsiveness as the baseline, with measured performance gains as the goal. `docs/VISION.md` records the control centre’s scope and `docs/BUDGETS.md` records the priorities for idle CPU and wakeups, presented frame pacing, memory growth, state-driven widgets and hidden rooms. The fixture checks establish behavior. The DMS comparison and resident performance measurements remain open.
- Next, review Opus’s Angular captures with the owner and carry the shutdown wait over to the public launcher using the same private fixture check. Wire the island and panel together when the island joins `shell.qml`, then verify the compositor binding and measure the resident against DMS on the same workflows.

# 12 November 2026 · Island UI handed to Opus, daemon test isolated

- The owner assigned the S3 island UI and interaction work to Opus and left daemon and test infrastructure with Sol. In hidden nested Hyprland, a 15-character reply draft survived a synthetic volume pop-up. After the notification resumed, clicking the field and pressing Enter recorded no action. The nested compositor was stopped. Opus has the reproduction.
- The daemon tests inherited desktop settings, including `FART_SUPERVISE=dms`, which can start a real DMS child even with the fixture host. The tests now construct a private environment, and the reply ordering test checks the CLI startup result before opening the socket. All 12 daemon tests passed with the fix under the ordinary desktop environment. The earlier socket failure's exact cause remains unconfirmed.
- Next, rerun the full suite once the UI changes are ready. Verify exact reply submission in the nested fixture and review the updated Angular captures with the owner.

# 11 November 2026 · S3 Angular fixture checkpoint

- The Angular fixture now includes the resting modules, hover wings, tray menus, panel docking and keyboard navigation. It queues fixture notifications, OSD, memory pressure and workspace changes, and shows recording, timer, battery and backend status. The owner chose Roboto Condensed, omitted the keyboard layout indicator, and chose Super+Shift+I for island focus. The focus target is available over IPC. Launch and fixture commands are in `docs/ui/README.md`.
- Offscreen island and contract checks passed. Nested Hyprland confirmed the island layout, tray submenu, fullscreen hide and remap, notification preemption and resume, and the panel open and dismissal paths. Nested `configerrors` was empty. The combined fixture measurements are in `docs/BUDGETS.md`.
- The latest full suite passed 704 of 705 tests. The core daemon reply test failed because `core.sock` was missing. That test passed in the preceding full run. The preceding run's night log failure was fixed in the test and passed a focused rerun.
- The owner paused work here. On resumption, verify that a typed notification reply survives OSD preemption and reaches the fixture intact, then recheck the daemon socket test. The live adapter, compositor binding and resident performance checks are still pending. FARTland // Fluid remains a separate future mode.

# 11 November 2026 · S3 step 2 fixture shell ready for review

- **Built.** `IslandFrame` draws the Angular 420 × 36 trapezoid, 84° shoulders and 4 px bevel. `Design.islandFill` picks the darkest blue palette role, or the darkest role when no blue exists. `IslandWindow` uses the Top layer and `zaetherion-island` namespace. It unloads the surface for fullscreen on its active workspace.
- **Fixture.** `shell-island-fixture.qml` supports top and bottom notch and floating placement. The gap is 16 px in this preview, while both placements reserve 36 px. Launch and fullscreen fixture commands are in `docs/ui/README.md`.
- **Verified.** Offscreen frame and palette smoke, layout and contract tests, generated qmldirs, and Qt 6 qmllint with zero syntax diagnostics. The hidden nested compositor confirmed all four placements, 36 px reserved, the bevel, and fullscreen unload, release and remap. Its config error list was empty and the compositor was stopped after capture.
- **Full suite.** All 703 tests passed in 575.885 s with QML debug messages enabled for the test process. The first run inherited `*.debug=false`, which hid the markers expected by the older fixture tests.
- **Next.** Review the fixture shell. After review, begin UI_BRIEF step 3 with the resting modules and hover wings.

# 11 November 2026 · S3 step 1 approved

- **Look.** The owner approved the Angular island with the shallow 4 px bevel and inverted app tag (Z144). One navy trapezoid widens into hover wings and deepens into notification, volume or memory pressure. `docs/ui/island-s3-review.svg` compares it with FART's fixture Timers screenshot. `docs/ui/island-s3-motion.gif` shows the morph and a volume event interrupting a notification, then the notification resuming.
- **Future direction.** Angular keeps the approved look. The future rounded mode is named **FARTland // Fluid** and depends on **FART // Fluid**, which the owner plans to develop later. Recorded in `docs/VISION.md`.
- **Fluid island approved (Z145).** A compact matte edge notch with a 3 px underside, just the clock at rest, track and waveform during playback, and other controls on hover. `docs/ui/fartland-fluid-study.svg` shows the approved look and `docs/ui/fartland-fluid-motion.gif` animates it with synthetic playback. The 100 px idle and 224 px playing widths are mock-up proposals. SVG, PNG and GIF verified and layout tests 7/7. The S3 implementation uses Z144.
- **Owner decisions.** Roboto Condensed for the mock-ups (Z52). Power opens the session card and notifications open Inbox (Z143). Memory trigger, priority and pin remain OPEN 14. Expansion sizes and floating gap are visual proposals.
- **Checks.** Layout tests 7/7, static render and motion frames visually checked, review-palette text contrast passes. The repository contrast audit is absent. The previous screenshot runner reported `0/1 rooms saved` despite writing a PNG. The fixture render was independently verified in that review and is reused here. The full suite was not run for this documentation checkpoint.
- **Next.** UI_BRIEF step 2 with the fixture adapter. Build the island window, trapezoid and fill, notch and floating modes, top and bottom placement, and fullscreen hiding. Stop for review at the end of step 2.

# 11 November 2026, night: first login on the supervisor; F2-3 checked

- **Login on the new setup is clean:** one core, one `dms`, one UI, all fresh. Owner pressed Super+R four times in four seconds: each was adopted, never doubled. **Found:** each restart counts as a failure (`failures=4`, wait 4 s), so quick repeated owner restarts lengthen the wait; reset after 60 s up. Consider not counting a clean exit that has a new DMS.
- **Old core survived a logout once** (the previous session-start's stop). The runtime folder is wiped at logout, so the leftover record is now written to `~/.local/state/zaetherion/logout.log`; read it after the next login.
- **F2-3 done with the owner present:** scan, toggle and connect (saved network) answer as designed; see OPEN.md.

# 11 November 2026, night: switch-over built (not yet logged into)

- `zaetherion start` now sets `FART_SUPERVISE=dms`; `tools/session-start` only starts the core and waits (no DMS loop, no `pkill`); `stop_core` waits up to 12 s. **The owner's running session still uses the old loop until the next login.**
- Owner's answers built in `core/supervisor.py`: new state `held` (clean exit and no new DMS within 3 s = stays down; `zaetherion start` or a new DMS brings it back) and a duplicate DMS is swept with ours, then one fresh start. Tests: 26 OK in `tests/test_core_supervisor.py`; `tools/supervisor_check.py` 16/16.
- **Still to do:** the real login/logout test (owner present: log out, log in, check one `dms`, `Super+R` keeps one, `dms kill`/stop stays down, logout leaves no processes); live checks for `held` and the duplicate sweep; measure `dms kill`; OPEN 17, 19; named clients (SUPERVISOR.md §12 items 2–5).

# 11 November 2026, evening: F1 delivered (Fable 5.2): the supervisor

- **Design:** `docs/SUPERVISOR.md` (states, transition table, backoff, crash verdicts, owner restarts, logout sequence, `dms.path`, lock hand-over, named clients, each recon finding). New questions for the owner: OPEN 15–18.
- **Slice, finished:** `fartd` supervises `dms run` when `FART_SUPERVISE=dms` (`core/supervisor.py`, wired in `core/fartd.py` and `core/app.py`). **Off by default: the owner's session still runs on `tools/session-start`.**
- **Verified:** `tests/test_core_supervisor.py` 24 OK; `python3 tools/supervisor_check.py` 16/16 (twice) in the nested Hyprland with private folders: start, UI crash back in 0.37 s, DMS kill with orphan sweep, owner restart adopted in 0.8 s and not doubled, waits 0.25/1/3/4, shutdown and compositor exit leave no processes, the session's DMS untouched. Full unit suite on the F1 tree, from the repo root: 700 run, 698 OK; the 2 failures were the fixture ones that `7f24a1f` fixed afterwards (both pass now).
- **Measured, new:**
  - `dms restart` = SIGUSR1; the old one exits 0 in 0.07 s; a detached `dms run -d --daemon-child` appears 0.36 s later and **keeps the environment but drops the flags**. So the UI folder goes in `DMS_SHELL_DIR`, never `-c`, or Super+R would bring back DMS's stock UI.
  - `pgrep -x dms` (the interim loop) also matches `dms cl copy` and other one-shot commands; the supervisor uses pid files plus a liveness check.
  - Apps launched from DMS (`Quickshell.execDetached`) get parent 1 and their own session, so the tree sweep cannot reach them. Today's DMS (started by `session-start`) shares Hyprland's session with every app: an adopted DMS that does not lead its session is swept by descendants only.
- **The pattern, for whoever continues (Sonnet):**
  - Behaviour lives in `TABLE` in `core/supervisor.py`; the same table is in `docs/SUPERVISOR.md` §2 between `<!-- table:start/end -->` and a test compares them. **Change both together, table first.**
  - `Machine` is pure. `Child` runs actions named `_do_<action>`. Everything that touches real processes is a *port* (`DmsPorts`); tests use `FakePorts` and the fake clock. A new supervised thing = new ports + a `Policy`, not a new machine.
  - Anything involving a real DMS is checked with `tools/supervisor_check.py`: add a check there. Never run a test DMS in the session's own runtime folder.
  - Run the suite from the repo root: `python3 -m unittest discover -s tests` (from inside `tests/` three modules fail to import).
- **Next, in order (docs/SUPERVISOR.md §12):**
  1. **Switch-over, needs the owner's go:** `start_core` in `tools/zaetherion.py` sets `FART_SUPERVISE=dms`; `tools/session-start` becomes "start the core and wait" (drop the DMS loop and `pkill -x dms`); raise `stop_core`'s wait from 6 s to 12 s. No Hyprland config change. **Build the owner's answers with it, from `docs/SUPERVISOR.md` §13:** OPEN 16 (a DMS stopped on purpose stays down: state `held`) and OPEN 18 (a second DMS: stop both, start one). Ask OPEN 19 first (a deliberate stop while locked, before S7). Then a real login/logout test.
  2. Named clients `resident`/`panel` and the panel's snapshot adapter (§9), with `DMS_SOCKET` for the panel from the `supervisor` topic (F2's need, §13); `tests/test_core_view.py` must stay green.
  3. `session.log` trimming and `dms.log` rotation; who restarts `fartd`; measure `dms kill` with care (§13).
- The two fixture test failures found on the way were fixed in `7f24a1f`.
- F2 (the `dms` adapter design) ran in parallel: entry below. What it needs from F1 is answered in `docs/SUPERVISOR.md` §13.

# 11 November 2026, F2: `dms` adapter designed (note only, no code)

- **The owner cut F2 to the design note.** `docs/DMS_ADAPTER.md` holds the design (brief points 1–6), the link's transition table (§2), the network mapping (§4), the service ↔ domain ↔ lease table (§5) and the build and test list (§9). No `adapters/dms/` exists yet; nothing was run against a real DMS.
- **Owner's decision:** a DMS newer than the checked one (API 38) keeps working with a note in Settings; an older one is switched off. Z9 needs that sentence at the merge.
- **The pattern to copy per domain:** one `DmsFeed` per DMS service with `wanted:` set to the lease (`holds("…")`, or `true` for un-leased contract state); properties are bindings on `feed.data`; methods go through `link.call` and never update properties themselves; a pure `Dms<Domain>Map.js` does the mapping and is tested under Node against the fixture.
- **Needs from F1** (§7): the DMS socket path for the panel, at spawn and on change; stopping an orphaned resident; the source for Z123's expansions.
- **New open items:** OPEN.md F2-1 to F2-6.
- **Found on the way:** `tests/test_qmldirs.py` fails before any F2 change (`tests/fixtures/nested/{lock,pamcheck}/qmldir` missing). Left alone.
- **Next:** build §9 in order (stand-in, link machine with its row tests, network, smoke), then roll the pattern out to bluetooth, brightness and the rest.

# 11 November 2026, afternoon: nested Hyprland check (Z109) passed

- **Nested Hyprland is viable for tests.** `tools/nested_hypr.py` (start / run / shot / stop / selftest) parks a nested Hyprland on a hidden special workspace with a headless `ZTEST` output that renders while hidden. Self-test 9/9 twice: fake lock shows and clears, a crashed lock client keeps the screen covered, a new client takes over, fake PAM permit/deny work from private config files, real session untouched. Details: docs/NESTED.md. Fixtures in `tests/fixtures/nested/`; `tests/test_nested_fixtures.py` 3 OK.
- **F1 prepared for Fable 5.2:** brief `docs/F1_BRIEF.md`; recon `docs/F1_RECON.md` (DMS run nested with private folders: a UI crash takes DMS down and is not respawned; only TERM/INT stop the pair cleanly, HUP/KILL orphan the UI; the shared `dms.path` pointer is taken by any second DMS and deleted on exit).
- **Incident during recon (fixed):** the first test DMS shared the real runtime folder, overwrote `dms.path` and deleted it on exit, so the owner's DMS keybinds pointed nowhere for under a minute. Restored by hand to the real UI path; `dms ipc` lists the real targets again. Tests now use a private `XDG_RUNTIME_DIR`.
- **Next:** the F1 Fable session, from the brief. Also check `zaetherion start/stop/restart/status` fits the session.

# 11 November 2026, ~12:40: S1 session installed and tested; DMS bar tuned

- SDDM entry installed by the owner; the owner now logs into **ZÆTHERION** (Hyprland + `zaetherion.lua` → `session-start` → core → `dms run` with DMS's UI). Login clean; logout + login left no old processes, one fresh set.
- cliphist records in the ZÆTHERION session (owner's choice); DMS clipboard stays off.
- Owner design inputs recorded: Modern Clock widget (PARITY, S10), island module list and memory-pressure expansion (SURFACES §1, OPEN 14).
- DMS bar tuned for the owner (7 workspace dots, power button, CPU off); not in this repo.
- **Next:** nested Hyprland check (Z109), then F1 (supervisor design). See NEXT_CHAT_HANDOFF.md.

# 11 November 2026, midday: S0 done; S1 started (owner approved both parts)

- **S0 done.** Full unit suite in this tree: 673 OK (572 s). Quiet baseline of Serpantinum + FART-next measured with Serpantinum back for ~10 min; **total budget fixed at 768 MiB PSS** (BUDGETS.md). Serpantinum is off again (`*.off`), DMS keybinds back in `config/keybinds.lua` (copy: `keybinds.lua.dms-2026-11-11`). Note: `serpantinumd stop` leaves `serpantinum-audio daemon` running; it had to be killed by hand.
- **S1 so far (not yet installed or logged into):**
  - `~/.config/hypr/zaetherion.lua` + `~/.config/hypr/zaetherion/` (copies in `session/hypr/`): shared look/monitors, DMS keybinds, Super+` on ZÆTHERION's core, `allow_session_lock_restore`, no Serpantinum or cliphist autostart. `Hyprland --verify-config` says ok. `hyprland.lua` (Serpantinum's session) unchanged.
  - `tools/session-start`: interim starter (core, then `dms run` with DMS's own UI until the resident exists at S3; restarts dms with backoff; stops both when the Hyprland socket goes). Roadmap F1 (fartd supervising dms) replaces it.
  - `session/zaetherion.desktop` (template, `@HOME@`), installed by the owner with sudo.
- **Still owed for S1:** install the session file, a real login/logout test (no leftover processes), nested Hyprland check (Z109), F1 supervisor design.

# 11 November 2026: S0 nearly done

- **Done:** scrub test and fixture replay (`tests/test_dms_fixtures.py`, 10 OK; `tools/dms_replay.py`, a stand-in DMS server); the real lyrics, location and weather names (weather is UI-side in DMS); a first memory look. All in `docs/DMS_OBSERVED.md`.
- **Owed for S0:** the quiet baseline of Serpantinum + FART (Serpantinum is off while the owner tries DMS), then BUDGETS.md's total.
- **The owner's desktop now:** full DMS (`dms run`, detached) with their keybinds retargeted to DMS (`~/.config/hypr/config/keybinds.lua`; the Serpantinum version is `keybinds.lua.serpantinum-2026-11-10`). Serpantinum's `bin/serpantinum{,d}` are renamed `*.off`. FART running.
- **Next:** S1 (the session). It needs the owner's approval for the SDDM entry (root) and autostart.

# 10 November 2026, late: S0 started, the seed is in (branch `s0-seed`)

- **Seeded from FART-next tag `FARG`** (`c13d874`): code at the root, FART's docs in `docs/fart/`, its NOTICE as `licenses/FART-NOTICE`. NOTICE records it.
- **`zaetherion` launcher** (`./zaetherion`, `tools/zaetherion.py`): FART's CLI with its own runtime, state and cache folders (`zaetherion`), so it can't touch the everyday `fart`. Checked with `status` only; not started. Still named fart-next in help text and the core's own names.
- `test_orbit` passes from the seeded tree. The full suite hasn't run here yet.
- **OPEN 2 checked (read-only):** tesseract, zbarimg and satty are all installed.
- **OPEN 13 decided:** the heavy layer stays on NVIDIA, Overdrive only (BUDGETS.md changed).
- **DMS run for the first time, read only, with Serpantinum fully stopped and backed up:** see `docs/DMS_OBSERVED.md` (read it before touching DMS). Fixtures in `tests/fixtures/dms/`. **Problem first:** the clipboard manager ignored its off switch.
- **Was waiting on the owner (now partly done):** OPEN 13 (keep the heavy layer and change the "dGPU never woken" budget, or move it to the AMD chip); the first `dms run` for the fixtures; the quiet baseline. The FARG measurements are in FART's `docs/OVERDRIVE.md` §9: NVIDIA asleep in Silent and after release, about 38 % and 12–14 W while Overdrive is on.

# 10 November 2026: the plan says "bring FART over"; DMS installed

**State:** still design only, no shell code. Two things changed:
- **FART-next is past the start line (Z1).** It has built all of M0–M16, including what this plan had moved here (M13 lensing, M14's live previews, M15 discovery and the archive, M16's tiers), plus M11 sessions and the heavy layer on the NVIDIA card. **Z62 now says ZÆTHERION brings FART over:** all of it arrives with the S0 seed and is adapted, not rebuilt. S11 extends FART's Overdrive to the island, launcher, overview and lock card. MILESTONES, DECISIONS (Z1, Z9, Z62), DMS_BACKEND and README updated.
- **DMS is installed: `extra/dux-shell` 2.1.0-1** (the owner, 10 November, 14:18), not `dux-shell-git`. Z9 is changed to match. **Not run yet:** `dms.service` is disabled and inactive, and there's no DMS config directory.

**New open item:** OPEN.md 13, the heavy layer on the NVIDIA card against the "dGPU never woken" budget. The seed brings it in, so it needs the owner's answer at S0.

**Untouched:** `docs/ROADMAP.md` is an uncommitted local file from before this change; it still says `dux-shell-git` and "M13–M16 move here". Left as it is.

**Next task:** S0, when the owner says go:
1. Seed this repo from a tagged FART-next commit. FART-next first takes its 144 Hz measurements and finishes its optimisation pass, then tags.
2. Record and scrub the DMS fixtures (`dms run` for the first time, on the owner's go; check `apiVersion` against 2.1.0).
3. Read-only check for tesseract, zbarimg and satty (OPEN 2).
4. Measure the quiet baseline.

# 8 November 2026: planning complete, design docs published

**State:** design only. No shell code exists. The plan came from one long planning session in which the owner answered every design question: 142 decisions (Z1–Z142), plus 12 open items, each with the test or approval that settles it.

**Done:**
- The docs set: VISION, DECISIONS, SURFACES, ARCHITECTURE, CONTRACT, MILESTONES, BUDGETS, RISKS, PARITY, DMS_BACKEND and OPEN.
- A plain-language overview PDF for non-technical readers.
- The public GitHub repo, with milestones S0–S12 and issues.

**Not done, by design:**
- No package installed. DMS was researched from its source only.
- No Hyprland, SDDM or Serpantinum file touched.
- No FART-next code changed; a docs pointer branch exists there, unmerged.

**Next task:** wait. ZÆTHERION starts when the owner says FART-next's Overdrive has reached about M12. Then begin S0 (docs/MILESTONES.md):
1. Ask for approval to install `dux-shell-git`.
2. Seed this repo from a tagged FART-next commit.
3. Record and scrub the DMS fixtures.
4. Measure the quiet baseline.
