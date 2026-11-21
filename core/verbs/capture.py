"""Capture verbs (S9, Z221): shot, record, and the three shortcuts text, qr and lens. Each starts at once and
answers; the picture's result arrives as a notification (core/capture.py)."""
from __future__ import annotations

from core.capture import ACTIONS, RECORD_MODES, SHOT_MODES
from core.verbs.base import Result, Usage, Verb

# Words the owner may say for an action.
ACTION_WORDS = {"copy": "copy", "edit": "edit", "text": "text", "ocr": "text", "qr": "qr", "lens": "lens",
                "search": "lens"}


def parse_shot(words) -> tuple[str, str]:
    mode, action = "region", "copy"
    for word in (w.lower() for w in words):
        if word in SHOT_MODES:
            mode = word
        elif word in ACTION_WORDS:
            action = ACTION_WORDS[word]
        else:
            raise Usage(f"shot [{'|'.join(SHOT_MODES)}] [{'|'.join(ACTIONS)}], not {word!r}")
    return mode, action


async def shot(ctx, words):
    mode, action = parse_shot(words)
    doing = ctx.core.capture.shoot(mode, action)
    return Result(f"{mode} · {action}: {doing}", "info", {"mode": mode, "action": action})


def shortcut(action: str):
    async def run(ctx, words):
        mode, _ = parse_shot(words)
        doing = ctx.core.capture.shoot(mode, action)
        return Result(f"{mode} · {action}: {doing}", "info", {"mode": mode, "action": action})
    return run


async def record(ctx, words):
    capture = ctx.core.capture
    lowered = [w.lower() for w in words]
    if lowered == ["stop"]:
        out = await capture.record_stop()
        return Result("recording stopped" if out["status"] == "stopped" else "not recording", "info", out)
    mode, sound, mic = "monitor", False, False
    for word in lowered:
        if word in RECORD_MODES:
            mode = word
        elif word in ("sound", "audio"):
            sound = True
        elif word in ("mic", "voice"):
            mic = True
        elif word not in ("start", "toggle"):
            raise Usage(f"record [{'|'.join(RECORD_MODES)}] [sound] [mic] | record stop, not {word!r}")
    if capture.recording and "start" not in lowered:
        out = await capture.record_stop()
        return Result("recording stopped", "info", out)
    out = await capture.record_start(mode, sound, mic)
    if out.get("status") == "cancelled":
        return Result("recording cancelled", "info", out)
    extras = " + ".join(name for name, on in (("sound", sound), ("mic", mic)) if on)
    return Result(f"recording {mode}" + (f" with {extras}" if extras else ""), "ok", out)


VERBS = [
    Verb("shot", "capture", "shot [region|window|monitor|full] [copy|edit|text|qr|lens]",
         "takes a screenshot (a region and copy by default)", ("shot", "shot full", "shot window edit"), shot,
         aliases=("screenshot",)),
    Verb("ocr", "capture", "ocr [region|window|monitor|full]", "copies the text in an area", ("ocr",), shortcut("text"),
         aliases=("text",)),
    Verb("qr", "capture", "qr [region|window|monitor|full]", "copies the QR code in an area", ("qr",), shortcut("qr")),
    Verb("lens", "capture", "lens [region|window|monitor|full]", "searches an area with Google Lens", ("lens",),
         shortcut("lens")),
    Verb("record", "capture", "record [monitor|region] [sound] [mic] | record stop",
         "starts or stops a screen recording", ("record", "record region sound", "record stop"), record,
         aliases=("rec",)),
]
