"""Generate transparent rest posters for the Jack/Jill wingman rigs.

Parses each rig's generated scene.rml for the emotion artboards, composites the
visible runtime image layers at their frame-0 positions onto a transparent
artboard-sized canvas (the rigs use translate-only image placement, verified:
origin 0,0, unit scale, no rotation), and writes the PNGs into
app/assets/mascots/ for the Flutter fallback (web / reduced motion / failed
load). The hero artboards reuse the calm rest smile as their fallback poster.

Run from the repo root: python app/tool/mascot_posters.py
"""
from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
SHIPPED = HERE.parent / "assets" / "mascots"
ARTBOARDS = ("Think", "Idea", "Write", "Smile")


def main() -> None:
    for rig in ("jack", "jill"):
        scene = ET.parse(HERE / f"mascot_rive_{rig}" / "scene.rml")
        assets = HERE / f"mascot_rive_{rig}" / "assets"
        for pose in ARTBOARDS:
            art = next(
                a
                for a in scene.getroot().iter("Artboard")
                if a.attrib.get("name") == f"{rig.capitalize()}{pose}"
            )
            canvas = Image.new(
                "RGBA", (round(float(art.attrib["width"])), round(float(art.attrib["height"]))), (0, 0, 0, 0)
            )
            placed = 0

            def walk(node, x, y, opacity):
                nonlocal placed
                if float(node.attrib.get("opacity", 1.0)) * opacity <= 0:
                    return  # hidden at frame 0
                if node.attrib.get("name") in ("Notes", "Bulb", "Glow", "Rays"):
                    return  # mid-beat overlays, never part of the resting pose
                lx = float(node.attrib.get("x", 0.0))
                ly = float(node.attrib.get("y", 0.0))
                if node.tag == "Image":
                    asset = assets / f"{rig}_{node.attrib['name']}.png"
                    if not asset.exists():
                        raise SystemExit(f"missing runtime layer {asset}")
                    canvas.alpha_composite(
                        Image.open(asset).convert("RGBA"), (round(x + lx), round(y + ly))
                    )
                    placed += 1
                    return
                # Rive paints a node's first child on top, so composite children last-to-first.
                for child in reversed(list(node)):
                    walk(child, x + lx, y + ly, opacity * 1.0)

            for child in reversed(list(art)):
                walk(child, 0.0, 0.0, 1.0)
            if placed == 0:
                raise SystemExit(f"{rig} {pose}: no layers composed; check the walk")
            target = SHIPPED / f"{rig}_{pose.lower()}.png"
            canvas.save(target, optimize=True)
            print(target, canvas.size, f"{placed} layers")


if __name__ == "__main__":
    main()
