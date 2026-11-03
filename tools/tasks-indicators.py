#!/usr/bin/env python3
"""Rebuild the bottom-panel task frames in widgets/tasks.svgz as Win11 indicators.

Running apps get a short grey pill, the focused app a longer accent pill on a
subtle highlight. Pills are centered by making the 9-patch corners wide and
transparent, so only the stretched middle piece is drawn.

Usage: tools/tasks-indicators.py plasma/desktoptheme/*/widgets/tasks.svgz
"""
import gzip, re, sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
for p, u in {"inkscape": "http://www.inkscape.org/namespaces/inkscape",
             "sodipodi": "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
             "xlink": "http://www.w3.org/1999/xlink"}.items():
    ET.register_namespace(p, u)

STATES = ("normal", "minimized", "focus", "hover", "attention", "progress")
PARTS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
TOP, PILL, GAP, R = 4, 3, 2, 4          # row heights, pill thickness, gap under pill, corner radius
BOTTOM = PILL + GAP

# state -> (corner width, background, pill)   colors are (css class, opacity)
DESIGN = {
    "normal":    (20, None,                           ("ColorScheme-Text", 0.55)),
    "minimized": (20, None,                           ("ColorScheme-Text", 0.55)),
    "focus":     (15, ("ColorScheme-Text", 0.09),      ("ColorScheme-Highlight", 1.0)),
    "hover":     (11, ("ColorScheme-Text", 0.06),      None),
    "attention": (11, ("ColorScheme-NeutralText", 0.20), ("ColorScheme-NeutralText", 1.0)),
    "progress":  (11, ("ColorScheme-Highlight", 0.25), None),
}


# Rounded outer corner for each corner piece (h >= R).
CORNERS = {
    "topleft":     lambda x, y, w, h: f"M{x},{y+h} V{y+R} A{R},{R} 0 0 1 {x+R},{y} H{x+w} V{y+h} Z",
    "topright":    lambda x, y, w, h: f"M{x},{y} H{x+w-R} A{R},{R} 0 0 1 {x+w},{y+R} V{y+h} H{x} Z",
    "bottomleft":  lambda x, y, w, h: f"M{x},{y} H{x+w} V{y+h} H{x+R} A{R},{R} 0 0 1 {x},{y+h-R} Z",
    "bottomright": lambda x, y, w, h: f"M{x},{y} H{x+w} V{y+h-R} A{R},{R} 0 0 1 {x+w-R},{y+h} H{x} Z",
}


def el(tag, **a):
    e = ET.Element(f"{{{SVG}}}{tag}")
    for k, v in a.items():
        e.set(k.replace("_", "-"), str(v))
    return e


def paint(e, color):
    cls, op = color
    e.set("class", cls)
    e.set("style", f"fill:currentColor;fill-opacity:{op}")
    return e


def box(x, y, w, h):
    """Invisible rect that fixes an element's bounding box."""
    return el("rect", x=x, y=y, width=w, height=h, style="fill:#000;fill-opacity:0")


def part(state, name, x, y, w, h, cw, bg, pill):
    g = el("g", id=f"{state}-{name}")
    g.append(box(x, y, w, h))
    if bg:
        if name in CORNERS:
            g.append(paint(el("path", d=CORNERS[name](x, y, w, h)), bg))
        else:
            g.append(paint(el("rect", x=x, y=y, width=w, height=h), bg))
    if pill and name.startswith("bottom"):
        if name == "bottom":
            g.append(paint(el("rect", x=x, y=y, width=w, height=PILL), pill))
        else:  # half-round pill cap on the inner edge of the corner
            r = PILL / 2
            cx = x + w if name == "bottomleft" else x
            sweep = 0 if name == "bottomleft" else 1
            d = f"M{cx},{y} A{r},{r} 0 0 {sweep} {cx},{y + PILL} Z"
            g.append(paint(el("path", d=d), pill))
    return g


def frame(state, ox, oy):
    cw, bg, pill = DESIGN[state]
    rows = [(TOP, ("topleft", "top", "topright")), (1, ("left", "center", "right")),
            (BOTTOM, ("bottomleft", "bottom", "bottomright"))]
    group = el("g", id=f"win11-{state}")
    y = oy
    for h, names in rows:
        x = ox
        for name in names:
            w = 1 if name in ("top", "center", "bottom") else cw
            group.append(part(state, name, x, y, w, h, cw, bg, pill))
            x += w + 4  # spacing between pieces so bounding boxes never touch
        y += h + 4
    # content margins: keep the icon full size, just clear of the pill
    for side, w, h in (("left", 2, 1), ("right", 2, 1), ("top", 1, 2), ("bottom", 1, BOTTOM + 1)):
        group.append(el("rect", id=f"{state}-hint-{side}-margin", x=ox + 80, y=y, width=w, height=h,
                        style="fill:#000;fill-opacity:0"))
        y += h + 2
    return group


def rebuild(path):
    root = ET.fromstring(gzip.open(path).read())
    pat = re.compile(rf"^({'|'.join(STATES)})-({'|'.join(PARTS)}|hint-(left|right|top|bottom)-margin)$")
    parents = {c: p for p in root.iter() for c in p}
    removed = 0
    for e in list(root.iter()):
        if pat.match(e.get("id", "")):
            parents[e].remove(e)
            removed += 1
    for i, state in enumerate(STATES):
        root.append(frame(state, 1000, i * 60))
    with gzip.open(path, "wb") as f:
        f.write(ET.tostring(root, xml_declaration=True, encoding="utf-8"))
    print(f"{path}: replaced {removed} elements with {len(STATES)} Win11 frames")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        rebuild(p)
