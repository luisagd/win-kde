#!/usr/bin/env python3
"""Replace the bottom panel's "applet is open" marker (widgets/tabbar.svgz,
south-active-tab) with a Win11 style soft rounded highlight.

Usage: tools/active-applet.py plasma/desktoptheme/*/widgets/tabbar.svgz
"""
import gzip, re, sys
import xml.etree.ElementTree as ET

SVG = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG)
for p, u in {"inkscape": "http://www.inkscape.org/namespaces/inkscape",
             "sodipodi": "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
             "xlink": "http://www.w3.org/1999/xlink"}.items():
    ET.register_namespace(p, u)

PREFIX, R, OPACITY = "south-active-tab", 4, 0.08
PARTS = ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright")
CORNERS = {
    "topleft":     lambda x, y: f"M{x},{y+R} A{R},{R} 0 0 1 {x+R},{y} V{y+R} Z",
    "topright":    lambda x, y: f"M{x},{y} A{R},{R} 0 0 1 {x+R},{y+R} H{x} Z",
    "bottomleft":  lambda x, y: f"M{x},{y} H{x+R} V{y+R} A{R},{R} 0 0 1 {x},{y} Z",
    "bottomright": lambda x, y: f"M{x},{y} H{x+R} A{R},{R} 0 0 1 {x},{y+R} Z",
}


def el(tag, **a):
    e = ET.Element(f"{{{SVG}}}{tag}")
    for k, v in a.items():
        e.set(k, str(v))
    return e


def fill(e):
    e.set("class", "ColorScheme-Text")
    e.set("style", f"fill:currentColor;fill-opacity:{OPACITY}")
    return e


def rebuild(path):
    root = ET.fromstring(gzip.open(path).read())
    pat = re.compile(rf"^{PREFIX}-({'|'.join(PARTS)})$")
    parents = {c: p for p in root.iter() for c in p}
    for e in list(root.iter()):
        if pat.match(e.get("id", "")):
            parents[e].remove(e)
    group = el("g", id=f"win11-{PREFIX}")
    for i, name in enumerate(PARTS):
        x, y = 2000 + (i % 3) * 10, (i // 3) * 10
        w = h = R if name in CORNERS else 1
        if name in ("left", "right"): w = R
        if name in ("top", "bottom"): h = R
        g = el("g", id=f"{PREFIX}-{name}")
        g.append(el("rect", x=x, y=y, width=w, height=h, style="fill:#000;fill-opacity:0"))
        if name in CORNERS:
            g.append(fill(el("path", d=CORNERS[name](x, y))))
        else:
            g.append(fill(el("rect", x=x, y=y, width=w, height=h)))
        group.append(g)
    root.append(group)
    with gzip.open(path, "wb") as f:
        f.write(ET.tostring(root, xml_declaration=True, encoding="utf-8"))
    print(f"{path}: {PREFIX} is now a rounded highlight")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        rebuild(p)
