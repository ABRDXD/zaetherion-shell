"""Draw the S9 comparison from an invented page. Run with Python and rsvg-convert."""
import math
from pathlib import Path
import random
import subprocess
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent
W, H = 1080, 608
X, Y, WIDTH, HEIGHT = 323, 178, 444, 300
RIGHT, BOTTOM = X + WIDTH, Y + HEIGHT
INK, WHITE, LIME = "#151918", "#f7f7ed", "#d6ff74"
MONO, SANS, SERIF = "JetBrainsMono Nerd Font, monospace", "Roboto Condensed, sans-serif", "Georgia, serif"
# Overlay roles mirror the Angular scale in view/ui/Design.qml.
CAPTION, CONTROL, READOUT = 11, 13, 20


def text(x, y, words, size, color, family=MONO, anchor="start", extra=""):
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
            f'fill="{color}" text-anchor="{anchor}" {extra}>{escape(words)}</text>')


def rect(x, y, width, height, fill, extra=""):
    return f'<rect x="{x}" y="{y}" width="{width}" height="{height}" fill="{fill}" {extra}/>'


def line(path, color, width=1, extra=""):
    return f'<path d="{path}" fill="none" stroke="{color}" stroke-width="{width}" {extra}/>'


def frozen_page():
    # A small atlas article, drawn at its source size. No captured or external assets.
    rng = random.Random(47)
    parts = [rect(0, 0, W, H, "#dad7c9"), rect(0, 0, W, 32, "#292d29"),
             text(22, 21, "Field notes", 13, WHITE, SANS),
             text(540, 21, "Observation atlas", 12, WHITE, SANS, "middle"),
             text(1056, 21, "Reading view", 12, WHITE, SANS, "end"),
             text(40, 82, "Celestial mechanics", 38, INK, SERIF),
             text(1040, 77, "OBSERVATION ATLAS    /    VOL. II", 12, INK, anchor="end"),
             line("M40 101H1040", INK), text(40, 146, "CONTENTS", 11, INK),
             text(40, 182, "01   Orbit", 15, "#465049", SANS),
             text(40, 213, "02   Transit", 16, INK, SANS, extra='font-weight="bold"'),
             rect(29, 201, 3, 14, INK), text(40, 244, "03   Shadow", 15, "#465049", SANS),
             line("M194 125V567", "#a7a99a"),
             text(223, 150, "The transit of a small body", 32, INK, SERIF),
             rect(223, 166, 575, 335, "#181e25"), '<g clip-path="url(#plate)">']
    for _ in range(450):
        x, y = rng.uniform(222, 799), rng.uniform(165, 501)
        r = rng.choice([0.45, 0.55, 0.8, 1.05])
        parts.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="#d3dcd2" opacity="{rng.uniform(.2,.8):.2f}"/>')
    parts += ['<circle cx="552" cy="327" r="126" fill="url(#sun)"/>', '<g clip-path="url(#disc)">']
    for row in range(-130, 140, 2):
        wave = []
        for col in range(-138, 144, 4):
            wiggle = (4 * math.sin(col / 25 + row / 12) + 2 * math.cos(col / 14 - row / 19)
                      + 2 * math.sin(col / 10 + row / 30) + rng.uniform(-1, 1))
            wave.append(f'{552+col},{327+row+wiggle:.1f}')
        parts.append(line("M" + " ".join(wave), rng.choice(["#ffe4ad", "#6f3433", "#aa4c36"]),
                          rng.choice([0.65, 1.1, 1.5]), 'opacity=".53"'))
    parts += ['</g>', line("M247 449L765 225", "#ded5b4", 1, 'stroke-dasharray="3 6" opacity=".7"'),
              '<circle cx="611" cy="292" r="18" fill="#1b2021" stroke="#eac19a" stroke-width="1"/>',
              text(239, 484, "PL. 02", 11, "#d4d3c8"), '</g>',
              text(823, 199, "Contact", 25, INK, SERIF), line("M823 213H1039", "#889186")]
    for i, words in enumerate(["A dark disc crosses", "the bright face of a star.",
                               "The track marks its path", "between the two limbs."]):
        parts.append(text(823, 239 + i * 22, words, 16, INK, SERIF))
    parts += [text(823, 369, "LIGHT CURVE", 11, INK), line("M823 448H1039", "#9ba091"),
              line("M823 396h44q8 0 12 20t14 19h52q10 0 15-20t12-19h65", INK, 2),
              text(223, 530, "Fig. 2", 18, INK, SERIF, extra='font-style="italic"'),
              text(281, 530, "A planet seen against its star at mid-transit.", 17, INK, SERIF),
              line("M40 569H1040", "#969c8c"), text(1040, 591, "02 / 03", 11, INK, anchor="end")]
    return "".join(parts)


def surround(fill, opacity):
    path = f"M0 0H{W}V{H}H0Z M{X} {Y}h{WIDTH}v{HEIGHT}h-{WIDTH}Z"
    return f'<path d="{path}" fill="{fill}" fill-opacity="{opacity}" fill-rule="evenodd"/>'


def edge(color, width):
    # Stroke ends exactly at the outer boundary of the kept pixels.
    half = width / 2
    return rect(X-half, Y-half, WIDTH+width, HEIGHT+width, "none",
                f'stroke="{color}" stroke-width="{width}"')


def corners(color, length, width, offset):
    marks = []
    for x, dx in [(X-offset, 1), (RIGHT+offset, -1)]:
        for y, dy in [(Y-offset, 1), (BOTTOM+offset, -1)]:
            marks.append(line(f"M{x+dx*length} {y}H{x}v{dy*length}", color, width))
    return "".join(marks)


def footer(fill, fg, accent):
    return "".join([rect(0, 560, W, 48, fill), rect(27, 578, 3, 11, accent),
                    rect(33, 578, 3, 11, accent), text(49, 589, "Frozen screen", CONTROL, fg),
                    text(540, 590, "Release to select", READOUT, fg, SANS, "middle"),
                    text(1053, 589, "Esc   Cancel", CONTROL, fg, anchor="end")])


def eclipse():
    return "".join([surround("#090c10", .79), edge("#161b19", 3), edge(WHITE, 1),
                    corners(LIME, 21, 3, 3), rect(X-4, Y-34, 154, 26, LIME),
                    text(X+6, Y-15, "444 × 300 px", CONTROL, INK),
                    footer("#101415", WHITE, LIME)])


def transit():
    # Extending both pairs of edges lets the eye sight across the surrounding page.
    guides = f"M{X} 0V{Y} M{RIGHT} 0V{Y} M0 {Y}H{X} M{RIGHT} {Y}H{W} M0 {BOTTOM}H{X} M{RIGHT} {BOTTOM}H{W} M{X} {BOTTOM}V560 M{RIGHT} {BOTTOM}V560"
    return "".join([surround("#18212a", .31), line(guides, "#161b1c", 3),
                    line(guides, "#dae9de", 1), edge(INK, 3), edge(WHITE, 1),
                    rect((X+RIGHT)/2-44, Y-26, 88, 25, "#cdeee5"),
                    text((X+RIGHT)/2, Y-9, "444 px", CONTROL, INK, anchor="middle"),
                    rect(RIGHT+1, (Y+BOTTOM)/2-13, 84, 26, "#cdeee5"),
                    text(RIGHT+43, (Y+BOTTOM)/2+5, "300 px", CONTROL, INK, anchor="middle"),
                    footer("#162425", WHITE, "#cdeee5")])


def proof():
    ticks = "".join(rect(x, Y-10, 5, 4, "#d5d1c6") for x in range(X+9, RIGHT-3, 15))
    return "".join([surround("#f4f1e7", .84), edge("#252523", 13), ticks,
                    rect(RIGHT-148, BOTTOM+6, 161, 28, "#252523"),
                    text(RIGHT+3, BOTTOM+25, "444 × 300 px", CONTROL, WHITE, anchor="end"),
                    rect(63, 552, 954, 1, "#535651"),
                    text(64, 582, "Frozen screen", CONTROL, INK),
                    text(540, 585, "Release to select", READOUT, INK, SANS, "middle"),
                    text(1016, 582, "Esc   Cancel", CONTROL, INK, anchor="end")])


DEFS = """<defs>
<clipPath id="plate"><rect x="223" y="166" width="575" height="335"/></clipPath>
<clipPath id="disc"><circle cx="552" cy="327" r="126"/></clipPath>
<radialGradient id="sun" cx=".38" cy=".34" r=".72">
<stop stop-color="#ffc985"/><stop offset=".55" stop-color="#e78655"/>
<stop offset=".91" stop-color="#b15841"/><stop offset="1" stop-color="#823d35"/></radialGradient>
</defs>"""


def render(page, overlay):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}">{DEFS}{page}{overlay}</svg>'


if __name__ == "__main__":
    page = frozen_page()
    for name, draw in [("a-eclipse", eclipse), ("b-transit", transit), ("c-proof", proof)]:
        subprocess.run(["rsvg-convert", "--output", str(OUT / f"{name}.png")],
                       input=render(page, draw()).encode(), check=True)
