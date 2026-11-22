"""Render two Fluid Settings compositions using synthetic state and original geometry."""
from math import exp, sqrt
from pathlib import Path
from subprocess import run
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent
W, H = 1064, 608
TABS = ("Palette", "Wallpaper", "Presets", "Island", "Notifications", "Clips", "Wi-Fi", "Bluetooth")
# view/fluid/FluidTokens.qml roles
CAPTION, BODY, HEADING, TITLE = 12, 14, 22, 32
BG, INK, SECONDARY, RULE = "#0e1014", "#f1f0f4", "#b5b3bc", "#373940"
ACCENT, ACTIVE, DANGER = "#d6c3ff", "#322b42", "#e4adaa"


def txt(x, y, value, size=BODY, color=INK, anchor="start", weight=400):
    return (f'<text x="{x}" y="{y}" fill="{color}" font-family="Inter, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" text-anchor="{anchor}">{escape(value)}</text>')


def box(x, y, w, h, color, radius=0):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" fill="{color}"/>'


def circle(x, y, radius, fill, stroke="none", width=1):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def path(d, color, width=1):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'


def button(x, y, label, width, active=False):
    return box(x, y, width, 34, ACCENT if active else "#282930", 17) + txt(
        x + width/2, y+22, label, BODY, BG if active else INK, "middle", 550)


def action(x, y, label, color=ACCENT):
    return txt(x, y, label, BODY, color, weight=550)


def toggle(x, y):
    return (box(x, y, 44, 26, ACCENT, 13) + circle(x+31, y+13, 9, BG)
            + txt(x-10, y+18, "On", BODY, INK, "end"))


def device_icon(x, y, nearby=False):
    glyph = ('M0 -8v16m-4-12 9 8-5 4m-4-4 9-8-5-4' if nearby else
             'M-9 3v-2a9 9 0 0 1 18 0v5m-18-3h4v7h-4zm14 0h4v7h-4z')
    return (circle(x, y, 20, "#25242e")
            + f'<g transform="translate({x} {y})">{path(glyph, ACCENT, 1.6)}</g>')


def limb_x(y):
    return -365 + sqrt(607**2 - (y-302)**2)


def limb(section):
    parts = [circle(-365, 302, 607, "url(#planet)", "#8b829e"),
             txt(36, 61, "Settings", TITLE, weight=550)]
    for i, name in enumerate(TABS):
        y = 116 + i*51
        x = limb_x(y)
        chosen = name == section
        if chosen:
            parts += [box(23, y-18, x-39, 36, "#34303d", 18),
                      circle(x, y, 8, BG, ACCENT, 1.4)]
        parts += [circle(x, y, 3 if chosen else 2, ACCENT if chosen else SECONDARY),
                  txt(43, y+5, name, BODY, INK if chosen else SECONDARY, weight=650 if chosen else 400)]
    parts.append(txt(1027, 54, "Close settings  ×", BODY, SECONDARY, "end"))
    return parts


def spectrum(section):
    parts = [txt(40, 54, "Settings", TITLE, weight=550),
             txt(1024, 50, "Close settings  ×", BODY, SECONDARY, "end")]
    centers = [94, 216, 338, 460, 582, 704, 826, 948]
    index = TABS.index(section)
    center = centers[index]
    # An absorption spectrum built from fine stationary lines; one luminous band under the open tab.
    parts.append(box(37, 111, 990, 45, "#15161c", 10))
    for i in range(40, 1025, 3):
        distance = abs(i-center)
        emission = exp(-(distance/35)**2)
        intensity = (1 + (i*17 % 29))/30
        # The strip is flat like light through a slit, with narrow dark absorption lines.
        strength = (.62 + .38*intensity) * (.22 if i % 17 < 3 else 1)
        rgb = [round(base + strength*(emission*gain + 23)) for base, gain in [(32, 158),(31, 133),(40, 177)]]
        parts.append(box(i, 119, 2, 29, "#" + "".join(f"{v:02x}" for v in rgb)))
    for i, name in enumerate(TABS):
        chosen = i == index
        if chosen:
            parts.append(box(centers[i]-54, 72, 108, 31, ACTIVE, 16))
        parts.append(txt(centers[i], 93, name, BODY, INK if chosen else SECONDARY, "middle", 600 if chosen else 400))
    return parts


def bt_limb():
    p = limb("Bluetooth")
    p += [txt(297, 103, "Bluetooth", TITLE, weight=550), toggle(978, 81),
          path("M297 137h726", RULE), txt(298, 193, "Paired", HEADING, weight=550),
          txt(1023, 192, "1 paired", BODY, SECONDARY, "end"),
          device_icon(323, 248), txt(361, 247, "Headphones", HEADING),
          txt(362, 272, "Connected   ·   72% battery", BODY, SECONDARY),
          button(361, 292, "Disconnect", 108), button(479, 292, "✓  Trusted", 96),
          action(927, 314, "Forget…", DANGER), path("M297 365h726", RULE),
          txt(298, 413, "Nearby", HEADING, weight=550), button(881, 389, "Stop scanning", 142),
          device_icon(323, 472, True), txt(361, 471, "Speaker", HEADING),
          txt(362, 496, "Available to pair", BODY, SECONDARY), button(948, 457, "Pair", 75),
          circle(304, 551, 3, ACCENT), txt(318, 556, "Scanning for devices", BODY, SECONDARY)]
    return p


def bt_spectrum():
    p = spectrum("Bluetooth")
    p += [txt(41, 223, "Bluetooth", TITLE, weight=550), toggle(979, 198),
          box(39, 253, 392, 307, "#1e1c26", 26),
          txt(67, 296, "Paired", HEADING), device_icon(91, 366),
          txt(125, 367, "Headphones", HEADING), txt(126, 393, "Connected   ·   72% battery", BODY, SECONDARY),
          path("M68 433H401", "#47434f"), button(67, 453, "Disconnect", 108),
          button(184, 453, "✓  Trusted", 99), action(70, 532, "Forget…", DANGER),
          txt(472, 296, "Nearby", HEADING), button(878, 273, "Stop scanning", 145),
          circle(476, 324, 3, ACCENT), txt(488, 329, "Scanning for devices", BODY, SECONDARY),
          path("M472 353h550", RULE), device_icon(494, 400, True),
          txt(527, 399, "Speaker", HEADING), txt(528, 422, "Available to pair", BODY, SECONDARY),
          button(948, 385, "Pair", 75)]
    return p


def reading(x, y, w, label, value, size=HEADING):
    return (txt(x, y, label, CAPTION, SECONDARY) + txt(x, y+28, value, size)
            + path(f"M{x+w-14} {y+17}l4 4 4-4", SECONDARY, 1.5)
            + path(f"M{x} {y+40}h{w}", RULE))


def island_limb():
    p = limb("Island")
    p += [txt(297, 103, "Island", TITLE, weight=550), path("M297 137h726", RULE),
          txt(297, 188, "At rest", HEADING), txt(1023, 188, "Hover shows everything", BODY, SECONDARY, "end"),
          reading(298, 229, 724, "Preset", "All · Everything")]
    for i, label in enumerate(("Power", "Wi-Fi", "Battery", "Notifications")):
        p.append(reading(298 + 373*(i%2), 310 + 69*(i//2), 350, label, "Always"))
    p.append(txt(298, 478, "Place", HEADING))
    for i, (label, value) in enumerate((("Edge", "Top"), ("Placement", "Notch"), ("Screen", "Focused"))):
        p.append(reading(298 + i*247, 522, 228, label, value))
    return p


def island_spectrum():
    p = spectrum("Island")
    p += [txt(41, 223, "Island", TITLE, weight=550), box(39, 253, 392, 307, "#1e1c26", 26),
          txt(68, 297, "At rest", HEADING), reading(68, 347, 334, "Preset", "All · Everything"),
          txt(68, 452, "Place", HEADING)]
    for i, (label, value) in enumerate((("Edge", "Top"), ("Placement", "Notch"), ("Screen", "Focused"))):
        p.append(reading(68+116*i, 492, 98, label, value, BODY))
    p += [txt(472, 296, "Visible at rest", HEADING), txt(1023, 296, "Hover shows everything", BODY, SECONDARY, "end")]
    for i, label in enumerate(("Power", "Wi-Fi", "Battery", "Notifications")):
        p.append(reading(472+283*(i%2), 351+98*(i//2), 259, label, "Always"))
    return p


def render(parts):
    defs = ('<defs><radialGradient id="planet" cx="0.47" cy=".45" r=".57">'
            '<stop offset=".69" stop-color="#101114"/><stop offset=".88" stop-color="#212027"/>'
            '<stop offset=".96" stop-color="#393440"/><stop offset="1" stop-color="#625969"/>'
            '</radialGradient></defs>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">'
            + defs + box(0, 0, W, H, BG) + "".join(parts) + "</svg>").encode()


if __name__ == "__main__":
    for name, draw in [("a-limb-bluetooth", bt_limb), ("a-limb-island", island_limb),
                       ("b-spectrum-bluetooth", bt_spectrum), ("b-spectrum-island", island_spectrum)]:
        run(["rsvg-convert", "-o", str(OUT / f"{name}.png")], input=render(draw()), check=True)
