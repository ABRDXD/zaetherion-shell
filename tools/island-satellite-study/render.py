"""Render the two proposed satellite faces using only invented display data."""
from html import escape
from pathlib import Path
import subprocess

OUT = Path(__file__).parent
PAPER = "#f2eee3"
MUTED = "#b7c4cb"
NAVY = "#111c29"
WARM = "#ffcd8d"
ICE = "#a7d1ee"
MONO = "JetBrainsMono Nerd Font,monospace"


def text(x, y, value, size, color, family=MONO, weight=400, anchor="start"):
    return (f'<text x="{x}" y="{y}" fill="{color}" font-family="{family}" font-size="{size}" '
            f'font-weight="{weight}" text-anchor="{anchor}">{escape(value)}</text>')


def path(d, fill="none", stroke="none", width=1):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def group(x, y, elements):
    return f'<g transform="translate({x} {y})">{"".join(elements)}</g>'


def disc(kind, tone):
    # Three marks that also read without colour: crescent, closed disc, record grooves.
    if kind == "timer":
        return path("M16 2a14 14 0 1 0 0 28A18 18 0 0 1 16 2Z", tone)
    if kind == "done":
        return (f'<circle cx="16" cy="16" r="14" fill="{tone}"/>'
                + path("m9 16 5 5 9-10", stroke=NAVY, width=2.3))
    return (f'<circle cx="16" cy="16" r="14" fill="{tone}"/>'
            + f'<circle cx="16" cy="16" r="7.5" fill="none" stroke="{NAVY}"/>'
            + f'<circle cx="16" cy="16" r="2" fill="{NAVY}"/>')


def shape(w, h, fluid):
    if fluid:
        return f"M0 0H{w}q-13 0-13 13v{h-29}q0 16-17 16H30q-17 0-17-16V13Q13 0 0 0Z"
    return f"M0 0H{w}l-13 {h}H13Z"


def status(x, y):
    return group(x, y, [
        path("M0 4q7-7 14 0M3 7q4-4 8 0m-5 3h2", stroke=MUTED, width=1.4),
        path("M23 2h15v8H23Zm17 2v4", stroke=MUTED),
        path("M25 4h9v4h-9z", MUTED),
    ])


def face(kind, lower, fluid):
    family = "Inter,sans-serif" if fluid else "Roboto Condensed,sans-serif"
    tone = ICE if kind == "track" else WARM
    title, sub, action = {
        "timer": ("12′", "Index the plates", "Timers ↗"),
        "done": ("Focus done", "", "Dismiss"),
        "track": ("After Light", "North Arc", "Media ↗"),
    }[kind]
    if lower:
        # The lower shelf belongs to the island silhouette; the top is the screen edge.
        base = [path(shape(416, 84, fluid), NAVY), text(208, 22, "09:42", 15, PAPER, MONO, 600, "middle"),
                status(330, 11), path("M31 33h354", stroke="#52606c")]
        base.append(group(27, 42, [disc(kind, tone)]))
        if kind == "timer":
            base.extend([text(71, 66, title, 28, tone, family, 700),
                         text(132, 54, "Focus", 12, MUTED, family),
                         text(132, 71, sub, 16, PAPER, family)])
        elif kind == "track":
            base.extend([text(71, 55, title, 20, PAPER, family, 650),
                         text(71, 73, sub, 13, MUTED, family)])
        else:
            base.append(text(71, 67, title, 23, tone, family, 650))
        base.append(text(383, 63, action, 13, PAPER, family, 550, "end"))
        return group(28, 0, base)
    base = [path(shape(438, 49, fluid), NAVY), text(28, 30, "09:42", 14, MUTED, MONO),
            path("M87 9v30", stroke="#576474")]
    if kind == "done":
        base.append(path("M96 0H438l-13 49H86Z" if not fluid else
                         "M94 0H438q-13 0-13 13v20q0 16-17 16H94Z", WARM))
        base.extend([text(116, 31, title, 23, NAVY, family, 700),
                     text(405, 30, action, 13, NAVY, family, 600, "end")])
    else:
        base.append(group(99, 8, [disc(kind, tone)]))
        if kind == "timer":
            base.extend([text(140, 32, title, 25, tone, family, 700),
                         text(191, 20, "Focus", 12, MUTED, family),
                         text(191, 37, sub, 15, PAPER, family, 550)])
        else:
            base.extend([text(141, 22, title, 18, PAPER, family, 650),
                         text(141, 39, sub, 12, MUTED, family)])
        base.append(text(405, 30, action, 13, PAPER, family, 550, "end"))
    return group(17, 0, base)


def sample(row, lower, fluid):
    kind = ["timer", "done", "track"][row]
    x, y = (518 if lower else 24), 103 + row * 142
    # Wallpaper fragment is an original contour drawing, common to both columns.
    background = '<rect width="472" height="108" fill="#89979d"/>'
    contours = [path(f"M0 {94+i*6}Q86 {19+i*4} 199 {79+i*4}T472 {51+i*5}", stroke="#75888f")
                for i in range(9)]
    contents = [background, *contours, face(kind, lower, fluid)]
    return group(x, y, ['<g clip-path="url(#viewport)">', *contents, '</g>'])


def sheet(fluid):
    pieces = ['<defs><clipPath id="viewport"><rect width="472" height="108"/></clipPath></defs>',
              '<rect width="1014" height="513" fill="#1b2327"/>']
    for x, title in [(24, "A   Transit band"), (518, "B   Lower ledge")]:
        pieces.append(text(x, 37, title, 28, PAPER, "Roboto Condensed", 650))
    style = "Fluid" if fluid else "Angular"
    for row, label in enumerate(["Focus timer", "Timer finished", "Track change"]):
        pieces.append(text(24, 93+row*142, f"{style}  /  {label}", 13, MUTED))
        pieces.extend(sample(row, lower, fluid) for lower in (False, True))
    return '<svg xmlns="http://www.w3.org/2000/svg" width="1014" height="513">' + ''.join(pieces) + '</svg>'


if __name__ == "__main__":
    for fluid in (False, True):
        name = "fluid.png" if fluid else "angular.png"
        subprocess.run(["rsvg-convert", "-o", str(OUT/name)], input=sheet(fluid).encode(), check=True)
