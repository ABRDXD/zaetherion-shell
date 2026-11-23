"""Eclipse state studies. Rasterize a pair of entirely invented desktops."""
from pathlib import Path
import subprocess

from render import DEFS, INK, LIME, MONO, SANS, WHITE, frozen_page, line, rect, text

OUT = Path(__file__).resolve().parent
W, H = 800, 416
WINDOW = (42, 27, 546, 307)
SHADE = "#090c10"
FOOT = "#101415"


def ticks(x, y, w, h, length, thickness):
    pieces = []
    for cx, dx in ((x, 1), (x+w, -1)):
        for cy, dy in ((y, 1), (y+h, -1)):
            pieces.append(line(f"M{cx+dx*length} {cy}H{cx}v{dy*length}", LIME, thickness))
    return "".join(pieces)


def scene(other=False):
    # Embedded atlas window has its own clipping space, exactly matching the hover box.
    x, y, w, h = WINDOW
    desktop = rect(0, 0, W, H, "#40495a" if other else "#60584d")
    desktop += '<g opacity=".45">' + "".join(
        line(f"M{-280+i*46} 416 Q{164+i*39} 220 {i*51} -28",
             "#929ba2" if other else "#a39e81", 1) for i in range(26)) + '</g>'
    if not other:
        desktop += f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="0 0 1080 608" preserveAspectRatio="none">' + DEFS + frozen_page() + '</svg>'
    nx, ny = (193, 69) if other else (590, 122)
    desktop += f'<g transform="translate({nx},{ny})">' + rect(0, 0, 378, 212, "#b8c4c1")
    desktop += rect(0, 0, 378, 25, "#394e52") + text(14, 17, "Plate index", 12, WHITE)
    desktop += text(18, 64, "Contact times", 28, INK, SANS)
    for i, (note, time) in enumerate((("First contact","08  14"),("Mid-transit","08  51"),("Last contact","09  28"))):
        ty = 88 + 30*i
        desktop += line(f"M18 {ty}H354", "#788984") + text(18, ty+20, note, 13, INK, SANS) + text(352, ty+20, time, 12, INK, anchor="end")
    return desktop + '</g>'


def shade(box=None):
    outline = f"M0 0H{W}V{H}H0Z"
    if box:
        x, y, w, h = box
        outline += f" M{x} {y}h{w}v{h}h-{w}Z"
    return f'<path d="{outline}" fill="{SHADE}" fill-opacity=".79" fill-rule="evenodd"/>'


def frame(box):
    x, y, w, h = box
    edges = rect(x-1.5, y-1.5, w+3, h+3, "none", 'stroke="#161b19" stroke-width="3"')
    edges += rect(x-.5, y-.5, w+1, h+1, "none", f'stroke="{WHITE}"')
    return edges + ticks(x-3, y-3, w+6, h+6, 19, 3)


def footer(action, identity="Frozen screen"):
    return (rect(0, H-44, W, 44, FOOT) + rect(21,H-28,3,12,LIME) + rect(27,H-28,3,12,LIME)
            + text(40,H-16,identity,13,WHITE) + text(W/2,H-15,action,20,WHITE,SANS,"middle")
            + text(W-20,H-16,"Esc   Cancel",13,WHITE,anchor="end"))


def reticle(x, y):
    path = f"M{x-15} {y}h10m10 0h10 M{x} {y-15}v10m0 10v10"
    return line(path,FOOT,4) + line(path,LIME,2)


def arrow(x, y):
    return f'<path d="M{x} {y}l2 18 5-6 6-1Z" fill="{WHITE}" stroke="{INK}" stroke-width="1.5"/>'


def screen(look, state):
    pilot = look == "pilot"
    box = WINDOW if state == "window" else (220,112,278,162) if state == "drag" else None
    other = state in ("other", "other-drag")
    art = scene(other) + shade(box)
    if other:
        hint = "Selection on other screen" if state == "other-drag" else "Move here to select"
        if pilot:
            return (art + rect(16,H-44,62+len(hint)*8,30,FOOT) + rect(27,H-34,3,10,LIME) + rect(33,H-34,3,10,LIME)
                    + text(46,H-24,hint,12,WHITE))
        return (art + rect(0,H-44,W,44,FOOT) + text(20,H-16,"Screen 2",13,WHITE)
                + text(W/2,H-15,hint,20,WHITE,SANS,"middle"))
    if box:
        x,y,w,h = box
        art += frame(box)
        by = y-34 if y>=34 else y+h+7
        size = f"{w} × {h} px"
        caption = ("Window   " if pilot and state=="window" else "") + size
        art += rect(x-3,by,8*len(caption)+22,26,LIME) + text(x+7,by+18,caption,13,INK)
    if state in ("idle","miss"):
        if not pilot:
            art += ticks(8,8,W-16,H-64,25,2)
        if state == "idle":
            art += reticle(371,172) if pilot else line("M363 172h16m-8 -8v16",WHITE,1)
        else:
            art += arrow(620,71)
    action = {"idle":"Drag to select","miss":"Point at a window","window":"Click this window" if pilot else "Click to select window","drag":"Release to select"}[state]
    return art + footer(action, "Frozen screen" if pilot or state != "drag" else "Screen 1 · Frozen")


def pane(x, y, art, width=W, height=H):
    return f'<svg x="{x}" y="{y}" width="{width}" height="{height}" viewBox="0 0 {W} {H}">{art}</svg>'


def board(look):
    b = [rect(0,0,1664,1506,"#191e20")]
    title = "A   Pilot light" if look=="pilot" else "B   Corner signals"
    b += [text(24,48,title,35,WHITE,SANS,extra='font-weight="bold"')]
    for x,y,state,label in ((24,104,"idle","Before a drag"),(840,104,"miss","Window mode · background"),
                            (24,594,"window","Window mode · over a window")):
        b += [text(x,y-12,label,21,WHITE,SANS),pane(x,y,screen(look,state))]
    # A second desktop pictured beside the active one. Relative placement is an example.
    b += [text(840,582,"Second screen · pointer on the first screen",21,WHITE,SANS),
          pane(840,594,screen(look,"other"))]
    b += [text(24,1056,"Both screens during a drag",21,WHITE,SANS),
          pane(24,1074,screen(look,"drag")),pane(840,1074,screen(look,"other-drag"))]
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1664" height="1506">{"".join(b)}</svg>'


if __name__ == "__main__":
    for name,look in (("a-pilot-light","pilot"),("b-corner-signals","corners")):
        subprocess.run(["rsvg-convert","--output",str(OUT/(name+".png"))],input=board(look).encode(),check=True)
