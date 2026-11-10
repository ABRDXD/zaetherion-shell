# core

The stdlib Python core daemon (M2): timers, task lists, the notification mirror, Overdrive leases and guards, view spawn and reap, sessions and discovery counters, served as JSON lines on `$XDG_RUNTIME_DIR/fart-next/core.sock` (`fart/core.sock` after cutover). Design and protocol: [docs/CORE.md](../docs/CORE.md).

Run it through `fart-next`, which starts it on demand with the right environment. `core/client/` is the QML side of the protocol that the view imports as `qs.core.client`.
