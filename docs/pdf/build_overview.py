#!/usr/bin/env python3
"""Build docs/ZAETHERION-overview.pdf, a plain-language overview for non-technical readers.

Needs reportlab (pip install reportlab), Inter (Inter.ttc) and JetBrains Mono installed.
Usage: python3 docs/pdf/build_overview.py [output.pdf]
"""
import math
import os
import sys

from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping  # noqa: F401
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.platypus import (Flowable, KeepTogether, PageBreak, Paragraph,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "ZAETHERION-overview.pdf")

INTER = "/usr/share/fonts/inter/Inter.ttc"
MONO = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
pdfmetrics.registerFont(TTFont("Body", INTER, subfontIndex=0))
pdfmetrics.registerFont(TTFont("BodySemi", INTER, subfontIndex=12))
pdfmetrics.registerFont(TTFont("Display", INTER, subfontIndex=32))
pdfmetrics.registerFont(TTFont("DisplayBlack", INTER, subfontIndex=18))
pdfmetrics.registerFont(TTFont("Mono", MONO))
pdfmetrics.registerFont(TTFont("BodyItalic", INTER, subfontIndex=3))
registerFontFamily("Body", normal="Body", bold="BodySemi", italic="BodyItalic", boldItalic="BodySemi")
registerFontFamily("BodySemi", normal="BodySemi", bold="BodySemi", italic="BodySemi", boldItalic="BodySemi")

NAVY = HexColor("#1b2537")      # the island ("Performance Blue")
INK = HexColor("#151a24")
PAPER = HexColor("#f5f2ec")
SIGNAL = HexColor("#d9483b")
MUTED = HexColor("#5d6575")
FAINT = HexColor("#c9c4ba")
STAR = HexColor("#f3ead2")

PAGE_W, PAGE_H = A4
MARGIN = 20 * mm
SLANT = math.tan(math.radians(12))   # the -12 degree family

styles = {
    "h1": ParagraphStyle("h1", fontName="Display", fontSize=26, leading=30, textColor=INK, spaceAfter=10),
    "h2": ParagraphStyle("h2", fontName="Display", fontSize=15, leading=19, textColor=INK, spaceBefore=10, spaceAfter=5),
    "body": ParagraphStyle("body", fontName="Body", fontSize=11, leading=16.5, textColor=INK, spaceAfter=7, alignment=TA_LEFT),
    "lead": ParagraphStyle("lead", fontName="Body", fontSize=13, leading=19, textColor=INK, spaceAfter=10),
    "small": ParagraphStyle("small", fontName="Body", fontSize=9, leading=12.5, textColor=MUTED),
    "kicker": ParagraphStyle("kicker", fontName="Mono", fontSize=8.5, leading=11, textColor=SIGNAL, spaceAfter=4),
    "cell": ParagraphStyle("cell", fontName="Body", fontSize=10, leading=14, textColor=INK),
    "cellb": ParagraphStyle("cellb", fontName="BodySemi", fontSize=10, leading=14, textColor=INK),
}


def P(text, style="body"):
    return Paragraph(text, styles[style])


def slanted_plane(c, x, y, w, h, fill, slant=SLANT):
    """A parallelogram leaning along the -12 degree family."""
    d = h * slant
    p = c.beginPath()
    p.moveTo(x + d, y + h)
    p.lineTo(x + w + d, y + h)
    p.lineTo(x + w, y)
    p.lineTo(x, y)
    p.close()
    c.setFillColor(fill)
    c.drawPath(p, stroke=0, fill=1)


def notch(c, cx, top, w, h, fill=NAVY, angle=84):
    """Trapezoid island: flat edge at the top (against the screen), sides at `angle`."""
    d = h / math.tan(math.radians(angle))
    p = c.beginPath()
    p.moveTo(cx - w / 2, top)
    p.lineTo(cx + w / 2, top)
    p.lineTo(cx + w / 2 - d, top - h)
    p.lineTo(cx - w / 2 + d, top - h)
    p.close()
    c.setFillColor(fill)
    c.drawPath(p, stroke=0, fill=1)


class Drawing(Flowable):
    def __init__(self, width, height, fn):
        super().__init__()
        self.width, self.height, self.fn = width, height, fn

    def draw(self):
        self.fn(self.canv, self.width, self.height)


# ---------------------------------------------------------------- diagrams

def screen_frame(c, x, y, w, h, label=None):
    c.setFillColor(HexColor("#dfe6ee"))
    c.roundRect(x, y, w, h, 4, stroke=0, fill=1)
    c.setStrokeColor(INK)
    c.setLineWidth(1.2)
    c.roundRect(x, y, w, h, 4, stroke=1, fill=0)
    if label:
        c.setFont("Mono", 7.5)
        c.setFillColor(MUTED)
        c.drawString(x, y - 11, label)


def island_states(c, W, H):
    """Three small screens: island at rest, on hover, and expanded with a message."""
    gap = 10
    sw = (W - 2 * gap) / 3
    sh = sw * 0.56
    y = H - sh - 4
    titles = ["1  At rest", "2  Mouse hovers", "3  Something happens"]
    for i in range(3):
        x = i * (sw + gap)
        screen_frame(c, x, y, sw, sh)
        top = y + sh
        cx = x + sw / 2
        if i == 0:
            iw = sw * 0.56
            notch(c, cx, top, iw, 13)
            c.setFillColor(white)
            c.setFont("Display", 7.5)
            c.drawCentredString(cx, top - 9.5, "12:48")
            left = cx - iw / 2 + 5
            c.setFillColor(FAINT)
            c.rect(left, top - 10, 6, 6, stroke=0, fill=1)
            c.setStrokeColor(FAINT)
            c.setLineWidth(0.6)
            wave = c.beginPath()
            wave.moveTo(left + 9, top - 7)
            for k in range(1, 9):
                wave.lineTo(left + 9 + k * 1.6, top - 7 + (1.6 if k % 2 else -1.6))
            c.drawPath(wave, stroke=1, fill=0)
            slanted_plane(c, cx + iw / 2 - 17, top - 9.5, 11, 4.5, FAINT)
        elif i == 1:
            notch(c, cx, top, sw * 0.86, 13)
            c.setFillColor(white)
            c.setFont("Display", 7)
            c.drawCentredString(cx, top - 9.5, "12:48:07")
            c.setFont("Mono", 5.2)
            c.setFillColor(FAINT)
            c.drawString(cx - sw * 0.40, top - 9, "wifi  bt  vol")
            c.drawRightString(cx + sw * 0.40, top - 9, "21°  ■ ■")
        else:
            notch(c, cx, top, sw * 0.7, 30)
            c.setFillColor(SIGNAL)
            c.rect(cx - sw * 0.3, top - 11, 3, 7, stroke=0, fill=1)
            c.setFillColor(white)
            c.setFont("BodySemi", 6.5)
            c.drawString(cx - sw * 0.27, top - 10, "New message")
            c.setFont("Body", 5.5)
            c.setFillColor(FAINT)
            c.drawString(cx - sw * 0.27, top - 18, "“Dinner at 8?”")
            c.setFont("Mono", 5)
            c.drawString(cx - sw * 0.27, top - 25.5, "[ REPLY ]   [ OPEN ]")
        c.setFont("BodySemi", 9)
        c.setFillColor(INK)
        c.drawString(x, y - 13, titles[i])


def panel_unfold(c, W, H):
    """The island unfolding into the full control panel."""
    sw, sh = W * 0.62, H - 6
    x, y = (W - sw) / 2, 2
    screen_frame(c, x, y, sw, sh)
    top = y + sh
    cx = x + sw / 2
    pw, ph = sw * 0.72, sh * 0.72
    notch(c, cx, top, pw * 0.42, 10)
    c.setFillColor(HexColor("#eef1f5"))
    c.setStrokeColor(NAVY)
    c.setLineWidth(1)
    p = c.beginPath()
    p.moveTo(cx - pw / 2, top - 10)
    p.lineTo(cx + pw / 2, top - 10)
    p.lineTo(cx + pw / 2, top - ph)
    p.lineTo(cx - pw / 2, top - ph)
    p.close()
    c.drawPath(p, stroke=1, fill=1)
    names = ["HOME", "MEDIA", "TASKS", "TIMERS", "DEVICES", "INBOX"]
    for i, n in enumerate(names):
        bx = cx - pw / 2 + 10 + i * 4
        by = top - 26 - i * 13
        slanted_plane(c, bx, by, 52, 10, NAVY if i == 0 else HexColor("#c8d0db"))
        c.setFont("Mono", 6)
        c.setFillColor(white if i == 0 else INK)
        c.drawString(bx + 5, by + 3, n)
    slanted_plane(c, cx - 4, top - ph + 14, pw / 2 - 12, ph - 40, HexColor("#dde3ea"))
    c.setFont("Display", 16)
    c.setFillColor(INK)
    c.drawString(cx + 6, top - 50, "12:48")
    c.setFont("Body", 7)
    c.drawString(cx + 6, top - 62, "Next task: physics revision")


def sky_chart(c, W, H):
    """A small night-sky chart with horizon, Moon and planets."""
    r = H / 2 - 4
    cx, cy = W / 2, H / 2
    c.setFillColor(INK)
    c.circle(cx, cy, r, stroke=0, fill=1)
    c.setStrokeColor(HexColor("#3a4256"))
    c.setLineWidth(0.5)
    for k in (0.33, 0.66):
        c.circle(cx, cy, r * k, stroke=1, fill=0)
    c.line(cx - r, cy, cx + r, cy)
    c.line(cx, cy - r, cx, cy + r)
    import random
    rnd = random.Random(7)
    pts = []
    for _ in range(140):
        a, d = rnd.uniform(0, 2 * math.pi), r * math.sqrt(rnd.random()) * 0.97
        mag = rnd.random()
        pts.append((cx + d * math.cos(a), cy + d * math.sin(a)))
        c.setFillColor(STAR)
        c.circle(pts[-1][0], pts[-1][1], 0.35 + 1.3 * mag ** 3, stroke=0, fill=1)
    c.setStrokeColor(HexColor("#6c7690"))
    c.setLineWidth(0.4)
    used = 0
    for i, a in enumerate(pts):
        if used >= 9:
            break
        near = min((b for b in pts[i + 1:]), key=lambda b: (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2, default=None)
        if near and (a[0] - near[0]) ** 2 + (a[1] - near[1]) ** 2 < (r * 0.22) ** 2:
            c.line(a[0], a[1], near[0], near[1])
            used += 1
    c.setFillColor(STAR)
    c.circle(cx + r * 0.42, cy + r * 0.38, 7, stroke=0, fill=1)
    c.setFillColor(INK)
    c.circle(cx + r * 0.42 + 3.5, cy + r * 0.38 + 1, 6.3, stroke=0, fill=1)
    for (dx, dy, name) in ((-0.45, -0.2, "Jupiter"), (0.1, -0.55, "Saturn")):
        c.setFillColor(SIGNAL)
        c.circle(cx + r * dx, cy + r * dy, 2.2, stroke=0, fill=1)
        c.setFont("Mono", 6.5)
        c.setFillColor(STAR)
        c.drawString(cx + r * dx + 4, cy + r * dy - 2, name)
    c.setFont("Mono", 6.5)
    c.setFillColor(HexColor("#8f99b0"))
    for lab, (dx, dy) in {"N": (0, 1.06), "S": (0, -1.12), "E": (-1.1, -0.03), "W": (1.05, -0.03)}.items():
        c.drawCentredString(cx + r * dx, cy + r * dy, lab)


def modes(c, W, H):
    """Silent vs Overdrive."""
    half = (W - 16) / 2
    for i, (name, sub, fill, txt) in enumerate((
            ("SILENT", "everyday, still, almost free", HexColor("#e7e3da"), INK),
            ("OVERDRIVE", "for a while, on purpose: motion", NAVY, white))):
        x = i * (half + 16)
        slanted_plane(c, x, 0, half - H * SLANT, H, fill)
        c.setFillColor(txt)
        c.setFont("Display", 17)
        c.drawString(x + 14 + H * SLANT, H - 30, name)
        c.setFont("Body", 9)
        c.drawString(x + 12 + H * SLANT * 0.7, H - 46, sub)
        if i == 1:
            c.setStrokeColor(SIGNAL)
            c.setLineWidth(1.6)
            c.line(x + 14, 14, x + half - 40, 14)
            for k in range(7):
                c.setFillColor(STAR)
                c.circle(x + 24 + k * 20, 22 + 4 * math.sin(k), 1.6, stroke=0, fill=1)
        else:
            c.setStrokeColor(MUTED)
            c.setLineWidth(1)
            c.line(x + 14, 14, x + half - 40, 14)


def layers(c, W, H):
    """Who does what: my part, the borrowed plumbing, Linux."""
    rows = [
        ("Your apps", "browser, music, editor, games", HexColor("#e7e3da"), INK),
        ("ZÆTHERION (my part)", "everything you see: island, launcher, lock screen, sky, panel", NAVY, white),
        ("DMS backend (borrowed, open source)", "Wi-Fi, Bluetooth, brightness, clipboard, night light", HexColor("#7d8799"), white),
        ("Linux + Hyprland", "the operating system and the window manager", INK, white),
    ]
    rh = (H - 3 * 6) / 4
    for i, (t, s, fill, col) in enumerate(rows):
        y = H - (i + 1) * rh - i * 6
        indent = i * 6
        slanted_plane(c, indent, y, W - 30 - indent, rh, fill)
        c.setFillColor(col)
        c.setFont("BodySemi", 10.5)
        c.drawString(indent + 14 + rh * SLANT, y + rh - 16, t)
        c.setFont("Body", 8.5)
        c.drawString(indent + 14 + rh * SLANT, y + 8, s)


def timeline(c, W, H):
    phases = [
        ("Before", "finish FART's\n12th stage"),
        ("Foundation", "S0–S2: set up,\nconnect DMS"),
        ("The look", "S3–S6: island,\nmessages, launcher"),
        ("Safety + sky", "S7–S9: lock screen,\nwallpaper, capture"),
        ("Polish", "S10–S11: widgets,\nsettings, Overdrive"),
        ("Switch", "S12: a test week,\nthen daily use"),
    ]
    n = len(phases)
    bw = (W - 6 * (n - 1)) / n
    bh = 26
    for i, (t, s) in enumerate(phases):
        x = i * (bw + 6)
        y = H - bh - i * 7
        fill = SIGNAL if i == n - 1 else (NAVY if i else MUTED)
        slanted_plane(c, x, y, bw - bh * SLANT, bh, fill)
        c.setFillColor(white)
        c.setFont("BodySemi", 8.5)
        c.drawString(x + 6, y + 9.5, t)
        c.setFillColor(INK)
        c.setFont("Body", 7.5)
        for k, line in enumerate(s.split("\n")):
            c.drawString(x + 2, y - 12 - k * 10, line)


# ---------------------------------------------------------------- pages

def cover(c, doc):
    c.saveState()
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
    # night band with stars
    c.setFillColor(INK)
    c.rect(0, PAGE_H * 0.38, PAGE_W, PAGE_H * 0.62, stroke=0, fill=1)
    import random
    rnd = random.Random(3)
    for _ in range(260):
        c.setFillColor(STAR)
        c.circle(rnd.uniform(0, PAGE_W), rnd.uniform(PAGE_H * 0.38, PAGE_H),
                 0.3 + 1.4 * rnd.random() ** 4, stroke=0, fill=1)
    notch(c, PAGE_W / 2, PAGE_H, 150, 22)
    c.setFillColor(white)
    c.setFont("Display", 11)
    c.drawCentredString(PAGE_W / 2, PAGE_H - 15, "12:48")
    slanted_plane(c, -20, PAGE_H * 0.43, PAGE_W * 0.82, 70, NAVY)
    slanted_plane(c, PAGE_W * 0.55, PAGE_H * 0.43 - 16, PAGE_W * 0.5, 12, SIGNAL)
    c.setFillColor(white)
    c.setFont("DisplayBlack", 54)
    c.drawString(MARGIN + 10, PAGE_H * 0.43 + 16, "ZÆTHERION")
    c.setFillColor(STAR)
    c.setFont("Mono", 10)
    c.drawString(MARGIN + 12, PAGE_H * 0.43 + 82, "> PROJECT OVERVIEW · NOVEMBER 2026")
    c.setFillColor(INK)
    c.setFont("Display", 20)
    c.drawString(MARGIN, PAGE_H * 0.28, "A desktop for my laptop,")
    c.drawString(MARGIN, PAGE_H * 0.28 - 26, "designed from scratch.")
    c.setFont("Body", 12)
    c.setFillColor(MUTED)
    c.drawString(MARGIN, PAGE_H * 0.28 - 56, "What I'm building, why, and how I'm doing it carefully.")
    c.setFont("Mono", 8)
    c.drawString(MARGIN, MARGIN, "zaetherion-shell · design stage · no code yet")
    c.restoreState()


def later(c, doc):
    c.saveState()
    c.setFillColor(PAPER)
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
    notch(c, PAGE_W / 2, PAGE_H, 90, 12)
    c.setFont("Mono", 7.5)
    c.setFillColor(MUTED)
    c.drawString(MARGIN, 12 * mm, "ZÆTHERION · project overview")
    c.drawRightString(PAGE_W - MARGIN, 12 * mm, f"{doc.page}")
    c.restoreState()


def build():
    doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=MARGIN, rightMargin=MARGIN,
                            topMargin=22 * mm, bottomMargin=20 * mm,
                            title="ZÆTHERION — project overview", author="ZÆTHERION project",
                            subject="A plain-language overview of the ZÆTHERION desktop shell")
    W = PAGE_W - 2 * MARGIN
    s: list = [PageBreak()]

    # 2. What is this?
    s += [P("> WHAT IS THIS", "kicker"), P("The part of the computer you actually look at", "h1"),
          P("When you use a phone, there is the home screen, the bar at the top with the time and "
            "battery, the notifications that slide down, the lock screen. None of that is an app: it is "
            "the <b>shell</b>, the frame around the apps. Computers have one too.", "lead"),
          P("My laptop runs Linux, where you can choose, and even build, your own shell. For the past "
            "weeks I have been building a control panel called <b>FART</b> (a codename that stuck): one "
            "panel at the top of the screen with music, timers, tasks, notifications and system "
            "controls, all in my own visual style. It runs next to a ready-made shell that still "
            "handles everything else."),
          P("<b>ZÆTHERION</b> is the next step: turning that panel into the <i>whole</i> shell, the bar, "
            "the app launcher, notifications, the lock screen, the wallpaper, so the entire screen "
            "speaks one design language that I designed."),
          P("Why build it?", "h2"),
          P("Partly because I use it every day and want it to be exactly right. Partly because it is a "
            "serious engineering exercise. It touches interface design, performance measurement, "
            "system programming, security (the lock screen) and open-source licensing, and it has to "
            "be reliable enough to trust with my own work and study."),
          P("Where it stands today", "h2"),
          P("It is fully <b>designed but not yet built</b>. I spent a long session answering every design "
            "question in advance, from how the clock looks to what happens if part of the system "
            "crashes. The result is 142 written decisions, so nothing has to be guessed during "
            "building. Building starts once the current panel project reaches its 12th stage."),
          PageBreak()]

    # 3. The island
    s += [P("> THE CENTREPIECE", "kicker"), P("The island", "h1"),
          P("Instead of a full bar across the top of the screen, there is one small dark shape hugging "
            "the top edge, like the notch on a phone. Its colour is the dark navy of the laptop's own "
            "body. Everything else grows out of it and shrinks back into it.", "lead"),
          Spacer(1, 6), Drawing(W, 110, island_states), Spacer(1, 14),
          P("<b>At rest</b> it shows only the time, the song playing (a tiny cover and a thin moving "
            "line), and the battery. <b>When the mouse hovers</b>, it spreads out sideways like wings to "
            "show Wi-Fi, Bluetooth, volume, the weather and small app icons. <b>When something "
            "happens</b> (a message, a finished timer, the volume changing, a low battery) it grows "
            "to show it, then shrinks back after a few seconds."),
          P("If several things happen at once, a fixed order of importance decides: an urgent alert "
            "beats a timer, which beats a song change, and so on."),
          Spacer(1, 4), Drawing(W, 150, panel_unfold), Spacer(1, 6),
          P("<b>Clicking</b> the island unfolds the full control panel out of it: rooms for music, "
            "tasks, timers, devices, notifications and more. Clicking again folds it back.", "small"),
          PageBreak()]

    # 4. The look
    s += [P("> THE LOOK", "kicker"), P("A real sky, and a bold graphic style", "h1"),
          P("The wallpaper and the lock screen can show the <b>actual sky above where I am</b>, worked "
            "out from astronomy formulas: the stars, the Moon with its current phase, the planets "
            "that are up, and the Sun's height during the day. At night it is drawn like an "
            "astronomer's star chart; in the day it becomes a soft gradient that follows the Sun.", "lead"),
          Drawing(W, 200, sky_chart), Spacer(1, 10),
          P("The graphic style borrows <i>ideas</i> from two video games I like, never their actual "
            "pictures, fonts or names:"),
          Table([[P("<b>Persona</b>", "cell"), P("bold slanted shapes, everything leaning at the same angle, "
                                                 "events that ‘cut in’ like a comic panel", "cell")],
                 [P("<b>NieR: Automata</b>", "cell"), P("the computer speaks in short machine-like lines, "
                                                       "such as <font face='Mono'>&gt; WIFI · ONLINE</font>; "
                                                       "this can be switched off", "cell")],
                 [P("<b>Astronomy</b>", "cell"), P("the real sky, orbits as motion, light bending around "
                                                  "mass as a transition effect", "cell")]],
                colWidths=[42 * mm, W - 42 * mm],
                style=TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                                  ("LINEBELOW", (0, 0), (-1, -2), 0.4, FAINT),
                                  ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)])),
          Spacer(1, 8),
          P("The lock screen becomes a ‘title card’: a large slanted clock and the date over the "
            "sky, the password box underneath, and music controls and the battery along the bottom."),
          PageBreak()]

    # 5. Light on the laptop
    s += [P("> USING LITTLE", "kicker"), P("Beautiful, but light on the laptop", "h1"),
          P("Pretty desktops often waste battery and memory on animations nobody is looking at. "
            "ZÆTHERION has two modes, and the rule is simple: <b>nothing moves unless I ask it to</b>.", "lead"),
          Drawing(W, 84, modes), Spacer(1, 12),
          P("<b>Silent</b> is the everyday mode. The screen is still; the clock changes once a minute; "
            "the sky is redrawn at most once a minute. When nothing is happening, the shell does "
            "essentially no work at all."),
          P("<b>Overdrive</b> is switched on deliberately, by holding a key or pressing and holding the "
            "island, for a set time, for example twenty minutes. Then the sky slowly turns, song "
            "lyrics animate word by word, and transitions get cinematic effects. When the time is up, "
            "everything returns to Silent and the memory it used is given back. It switches itself "
            "off on battery, and it never wakes the laptop's power-hungry gaming graphics card."),
          P("Other habits that keep it light", "h2"),
          P("• Anything not visible is removed from memory, not just hidden. Desktop widgets "
            "disappear completely whenever an app window is open.<br/>"
            "• Every part has a measured budget, and the whole shell must use no more memory "
            "than the setup I use today.<br/>"
            "• Nothing is called ‘faster’ or ‘lighter’ until it has been measured."),
          PageBreak()]

    # 6. Built carefully
    s += [P("> BUILT CAREFULLY", "kicker"), P("How I'm making it safe to rely on", "h1"),
          P("A shell is something you trust all day: if the lock screen fails, the computer is open; "
            "if notifications break, you miss messages. So the plan is cautious by design.", "lead"),
          Drawing(W, 150, layers), Spacer(1, 12),
          P("<b>I don't reinvent the plumbing.</b> Connecting to Wi-Fi, pairing Bluetooth, controlling "
            "brightness and the clipboard are handled by <b>DMS</b>, a well-tested open-source project. "
            "I build the part you see and interact with; proven code does the rest."),
          P("<b>The old desktop stays as a safety net.</b> ZÆTHERION runs as a separate choice on the "
            "login screen. If anything goes wrong, I log out and pick the old one. It is only retired "
            "after a full test week with no problems in the last three days."),
          P("<b>Security parts are tested separately.</b> The lock screen and password prompts are "
            "tested inside a sandboxed copy of the desktop first, never by risking the real one."),
          P("<b>Everything is written down.</b> Every decision, every risk with its fix, and every "
            "feature of the old desktop (kept, replaced or dropped) is recorded in the project's "
            "public documents, so nothing is left to chance or memory."),
          PageBreak()]

    # 7. The plan
    s += [P("> THE PLAN", "kicker"), P("Step by step", "h1"),
          P("The work is split into thirteen stages, S0 to S12. Each one ends with something that "
            "works, checked against written pass/fail criteria, before the next begins.", "lead"),
          Spacer(1, 6), Drawing(W, 105, timeline), Spacer(1, 18),
          P("What I learn along the way", "h2"),
          Table([[P("Design", "cellb"), P("a complete, consistent visual system: shapes, type, colour, motion", "cell")],
                 [P("Engineering", "cellb"), P("several programs working together, recovering on their own when one fails", "cell")],
                 [P("Performance", "cellb"), P("measuring memory, processor time and smoothness instead of guessing", "cell")],
                 [P("Security", "cellb"), P("a lock screen and password prompts that fail safely", "cell")],
                 [P("Open source", "cellb"), P("reusing others' work properly: licences, credit, publishing my own", "cell")],
                 [P("Planning", "cellb"), P("142 decisions made up front, risks listed with their fixes", "cell")]],
                colWidths=[32 * mm, W - 32 * mm],
                style=TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"),
                                  ("LINEBELOW", (0, 0), (-1, -2), 0.4, FAINT),
                                  ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)])),
          Spacer(1, 14),
          P("The whole plan is public on GitHub as <font face='Mono'>zaetherion-shell</font>. For now "
            "it holds the design documents; the code arrives stage by stage.", "small")]

    doc.build(s, onFirstPage=cover, onLaterPages=later)
    print(OUT)


if __name__ == "__main__":
    build()
