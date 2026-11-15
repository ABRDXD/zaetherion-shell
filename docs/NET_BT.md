# Wi-Fi and Bluetooth in FART (S10, design, 14 November 2026)

Status: **plan OK'd by the owner (14 November 2026), with VPN on/off added and no enterprise form (the owner has
none). Adapter, tests and the quiet-copy patch are built; the two settings sections are drawn and wait for the owner's
look; nothing is live.** Branch `s10-net-bt`, worktree `~/src/zaetherion-shell-net`. Decisions Z190–Z194.

What changed from this note while building: VPN gets Start/Stop (owner); Forget asks for a second click within 3 s
instead of a hold (the hold lives inside the island's session card, being changed by another agent, and would have to be
copied); the outcome line hides while a password prompt for the same network is open; `vpns` (not `vpn`) and
`preference`/`setPreference` are on the contract; forget, auto-join and the preference re-read DMS's state after the
answer (DMS sends no event for them). Calls not yet seen against a real DMS: OPEN F2-7. Inputs: Z95, Z113, Z126, Z162, Z171, Z176; DMS_ADAPTER.md §1–§4; OPEN F2-3; DMS 2.1.0's
QML under `$XDG_RUNTIME_DIR/dms-shell/9483c24f0a364ed0/` and the JSON field names in `/usr/bin/dms`. The live DMS was not contacted.

## 1. What DMS offers (read, not guessed)

**Wi-Fi** (service `network`, already subscribed). Methods beyond today's three: `network.wifi.connect {ssid, password?,
hidden?, interactive}`, `network.wifi.disconnect {device?}`, `network.wifi.forget {ssid}`, `network.wifi.setAutoconnect
{ssid, autoconnect}`, `network.preference.set`, `network.info {ssid}`. The snapshot already carries what we need: per
network `enterprise`, `hidden`, `autoconnect`, `saved`, `frequency`; and `isConnecting`, `connectingSSID`, `lastError`
(`bad-credentials`, `user-canceled`, …), `ethernetConnected`/`ethernetDevice`, `vpnActive`/`vpnProfiles`.
**Password prompts:** DMS's backend is NetworkManager's secret agent. When NM needs a secret (a wrong password, a saved
network whose secret is gone) it sends a `network.credentials` event `{token, ssid, setting, fields, hints, reason}`;
the answer is `network.credentials.submit {token, secrets, save}` or `.cancel {token}`.

**Bluetooth: DMS's socket has enough.** Service `bluetooth` (snapshot `{powered, discovering, adapters, devices,
pairedDevices, connectedDevices}`; recorded in our fixture, with the radio off), and methods `bluetooth.setPowered
{powered, adapter}`, `togglePowered`, `startDiscovery`, `stopDiscovery`, `pair {device}`, `connect`, `disconnect`,
`trust`, `untrust`, `remove`. A device carries `path, address, name, alias, paired, trusted, blocked, connected, class,
icon, rssi, legacyPairing`. DMS's backend is also a **BlueZ pairing agent**: `bluetooth.pairing` events `{token,
requestType: confirm | display-passkey | authorize | pin | passkey, passkey, deviceName, deviceAddr}`, answered with
`bluetooth.pairing.submit {token, secrets: {pin} | {passkey} | {decision: "yes"}, accept}` or `.cancel {token}`.
**One gap: no battery level** (no `battery` field in the binary).

**Choice (Z190): DMS's socket for all Bluetooth state and actions, Quickshell's Bluetooth module for battery only.**
- Not Quickshell for the rest: it has no pairing agent, so a PIN or passkey device can't pair (DMS's own code says so),
  and it would be a second, unrelated source of truth beside the link we already test and reconnect.
- Not `bluetoothctl`: its agent lives in an interactive process whose text output we would have to parse; no answers to
  wait on, no tokens, nothing recordable for fixtures.
- Battery: Quickshell's `BluetoothDevice.battery` (BlueZ's Battery1), read-only, matched by address. If Quickshell's
  module is absent, battery reads -1 ("unknown") and nothing else changes.

**Conflict with DMS's own dialogs.** DMS's UI shows its own password window on every `network.credentials` event
(`DMSShell.qml`) and its own pairing window on `bluetooth.pairing` while its control centre is loaded. Both would pop
up beside ours, and DMS's would cancel our token. **Z191: the quiet DMS copy (Z171) also removes those two handlers**
(`dms_quiet.py`, same refuse-if-unrecognised rules, with a test). Until that copy is live, FART's flows still work but
DMS's window may appear too; we say so in Settings.

## 2. The contract, grown (core and view stay host-free)

`NetworkDomain` gains (all plain values; no tokens, no device paths, no secrets):
- `networks[]` rows gain `enterprise`, `hidden`, `autoconnect`, `band` ("2.4" | "5" | "6" | "").
- `saved[]` (lease `saved`): `{id, ssid, autoconnect, inRange}`, for the settings list.
- `wired` `{connected, name}` and `vpn` `{active: [names], available}`: status only.
- `attempt` `{ssid, phase, message}` or null. Phases: `connecting`, `connected`, `wrong-password`, `timeout`,
  `failed`, `cancelled`, `lost` (DMS went away mid-attempt).
- `prompt` `{id, ssid, reason, kind: "psk" | "unsupported"}` or null: NM asks for a password.
- Methods: `join(ssid, secret, hidden)`, `disconnect()`, `forget(id)`, `setAutoconnect(id, on)`,
  `answerPrompt(id, secret)`, `cancelPrompt(id)`. `connect(id)` stays (saved networks).

`BluetoothDomain` gains:
- `devices[]` rows gain `trusted`, `busy` (connecting, disconnecting or pairing), `audio` (by class/icon), `kind` from
  DMS's `icon` mapped to our own glyph set (headset, headphones, speaker, mouse, keyboard, phone, gamepad, computer,
  watch, other). Order: connected first, then audio, then the rest by name.
- `discovering`, `nearby[]` (lease `scan`: unpaired devices with a real name, strongest first).
- `attempt` `{id, action, phase, message}` and `pairing` `{id, deviceName, kind, passkey}` (passkey only for
  confirm/display kinds; it's a number to compare, not a secret).
- Methods: `pair(id)`, `trust(id, on)`, `forget(id)`, `answerPairing(id, accept, code)`, `cancelPairing(id)`;
  `setEnabled`, `connect`, `disconnect` stay.

Adapter files: `DmsNetwork.qml` grows; new `DmsWifiAttempt.js` (pure machine), `DmsBluetooth.qml`,
`DmsBluetoothMap.js`, `DmsBluetoothAttempt.js`, `DmsPrompts.qml` (the two prompt feeds). Serpantinum and the fixture
adapter get the new members as stand-ins.

## 3. "Reliable", defined (Z192). Each line is a test.

1. **Every action gets an answer or a timeout, and the user sees which.** Wi-Fi join or connect: 40 s; Bluetooth
   connect 20 s, pair 60 s (a person may be typing a PIN), power 10 s, a prompt left unanswered 90 s, then cancelled.
   A timeout says what timed out and offers "Try again".
2. **The UI never shows a state the system doesn't have.** Only snapshots move `connected`, `enabled`, `paired`, etc.
   An attempt's `connected` phase is set only when the snapshot shows the network connected *with an address*; an
   answer of "connecting" from DMS means only "asked". No optimistic ticks.
3. **One action per target at a time; a double-click does nothing extra.** A second `join`/`connect` for the same
   network while one runs is dropped; a different network while one runs is refused (the rows are disabled and say
   "joining …"). Bluetooth: one action per device; power uses the §1 toggle pattern.
4. **DMS restarts are survived.** In-flight calls answer `offline`; the attempt goes `lost` ("DMS restarted, checking…");
   after the link is back the first snapshot decides `connected` or `failed`. Prompts are dropped with their token
   (a dead token can't be answered). Nothing is replayed (§1 of DMS_ADAPTER.md). Within 5 s of DMS's return, held scans
   run again.
5. **Clear failure messages**, from DMS's `lastError` and NM reasons, mapped in one table: wrong password, network out
   of range, timed out, cancelled, enterprise not supported, DMS offline, unknown (with the raw reason in small print).
6. **After resume:** DMS's `loginctl.preparingForSleep` going false starts a 30 s "waking" window: the Wi-Fi line reads
   "reconnecting…" only while NM's snapshot says it is connecting; a held scan runs again. We never issue a connect
   ourselves after resume (NM's autoconnect does it; a second connect would race it). If nothing is connected at the end
   of the window, the line says "not connected" and lists the saved networks in range.

## 4. Passwords and PINs (Z193)

- Typed into a masked field (an eye button shows it while held, never by default). Kept only in that field; cleared on
  submit, cancel, fold, close and disconnect. Never in `ViewState`, the core, a cue, a log line or a fixture.
- Handed straight to DMS (`network.wifi.connect {password, interactive:false}` or `network.credentials.submit`), which
  hands it to NetworkManager. `save: true`: NM keeps it, as with any saved network.
- Tests: a static test fails if any file under `adapters/`, `core/` or `view/` logs or stores a field named
  `password`, `psk`, `secret`, `pin`; a harness test types a fake password and greps all output and the replay log's
  non-request lines for it. The replay's request log does contain the fake value, by design and labelled.
- Enterprise (802.1X) networks: listed with an "enterprise" tag and "not supported in FART yet"; no form.

## 5. Where each thing lives (Z95, Z176)

| Where | What |
|---|---|
| Island hover (Z95) | Wi-Fi and Bluetooth glyphs as today, plus one word when something is happening: "joining", "wrong password", "pairing". Click opens FART on the right settings section. Built 15 November 2026 (`IslandRest`, `NetWords.wifiWord`/`bluetoothWord`): the word shows only while hovered, "wrong password" in accent; glyph and word open the section while a word shows, Devices otherwise |
| Devices room, Wi-Fi tile and "nearby" page | On/off; nearby list with signal, lock, KNOWN/NEW; a known network joins in place. A **new** network's row says "join…" and opens FART's Wi-Fi settings with that name filled in (passwords live in settings). The "host dialog" verb goes |
| Devices room, Bluetooth tile and "paired" page | On/off; connect/release; battery; device glyph; audio first |
| FART settings → **Wi-Fi** | `Wi-Fi` on/off · network list (signal, band, lock, saved, enterprise tag) · Join (password field) · **Join a hidden network…** (name + password) · per saved network: **Auto-join** toggle, **Forget** (click twice) · **Prefer auto / Wi-Fi / wired** (`network.preference.set`) · **Wired** status · **VPN Start/Stop** per profile · the live password prompt when NM asks |
| FART settings → **Bluetooth** | `Bluetooth` on/off · **Scan** (lease `scan`) · nearby list with **Pair** · pairing prompt (compare passkey / type PIN or passkey / allow) · per paired device: **Connect/Disconnect**, **Trusted** toggle, **Forget** (click twice), battery, glyph |
| FART settings, both | "DMS may also show its own window" note until Z191's copy is live |

New FART-stored settings: **none**. Every control above is a system setting held by NetworkManager or BlueZ, so it
survives FART and DMS. The settings sections are their own files (`view/shell/settings/WifiSettings.qml`,
`BluetoothSettings.qml`), joined to `PreferencesPane.qml` by one entry each, kept apart from Claude B's and C's
sections.

A password prompt that arrives while FART is closed (the island's process also holds the prompt feeds): an island event
"‹network› needs a password" whose click opens FART on that prompt. FART never opens by itself.

## 6. Tests (all with DMS fixtures and stand-ins; no real radio is touched)

- Mapping (Node, against the recorded fixture, Z113-scrubbed): network rows, saved list, wired/VPN, Bluetooth
  snapshot. The fixture has Bluetooth off and no devices, so device rows come from a **synthetic, labelled** fixture
  built from the field names above, until a real recording (§7).
- State machines (Node): Wi-Fi attempt (connect, success with address, wrong password then right, timeout, cancel,
  DMS lost, double click, second network refused, resume window); Bluetooth attempt (pair with each of the 5 request
  kinds, wrong PIN, timeout, cancel, connect/disconnect, forget, DMS lost).
- Adapter (offscreen `qs` against `tools/dms_replay.py` with scripts): each method sends exactly the expected call,
  once; nothing while offline; prompts answered with the right token; a SIGKILLed replay mid-pair ends `lost`.
- Static: no secret logged or stored; `dms_quiet.py` patch recognised and refused on an unknown DMS.
- Full suite green, `tools/make_qmldirs.py --check` clean. Nested-Hyprland captures of every new view before any UI commit.

## 7. Real checks (owner present, one at a time, each undone)

1. Record a scrubbed `bluetooth.getState` with Bluetooth on (read-only call; Bluetooth must already be on).
2. Join a new network with a wrong password, then the right one, then Forget it (a phone hotspot is ideal).
3. Auto-join off and back on for a saved network.
4. Pair a device that asks for a PIN or a passkey, connect, disconnect, untrust/trust, forget, and pair it again.
5. Suspend and resume once with Wi-Fi on.
