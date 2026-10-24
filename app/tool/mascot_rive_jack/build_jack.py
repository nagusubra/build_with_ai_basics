"""Build Jack the wingman: registered image parts -> layered Rive rig with reusable segment artboards.

Every raw render lives in design/mascots/jack_rig/raw/ (flat green background, generated piece by piece with
Gemini from one master pose, see docs/mascot-animation-pipeline.md). This script:

1. keys and registers each render into the master's 1024x1024 space,
2. cuts the rig parts (body, head + expressions, hat, stem, three arm poses, light bulb),
3. writes the parts at full resolution to design/mascots/jack_rig/parts/ with jack_rig.json (boxes + pivots),
4. writes 0.75x runtime layers to assets/ and generates scene.rml for the Rive CLI.

Run:  python app\\tool\\mascot_rive_jack\\build_jack.py   then   python app\\tool\\mascot_rive_jack\\verify_jack.py
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from parts import bbox, key, load, save, warp

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RIG = REPO / "design" / "mascots" / "jack_rig"
RAW = RIG / "raw"
PARTS = RIG / "parts"
ASSETS = HERE / "assets"
BUILD = HERE / "build"

S = 0.75                      # runtime scale: master px -> artboard px
CROP = (60, 0, 924, 950)      # master-space window the artboards show
ARTBOARD_W = round((CROP[2] - CROP[0]) * S)
ARTBOARD_H = round((CROP[3] - CROP[1]) * S)

# head_v1 was rendered zoomed in; master = HEAD_T[0] * head + HEAD_T[1:] (NCC 0.98 on the face).
HEAD_T = (0.606, 205.85, 165.8)

# Pivots in master space.
ROOT = (512, 930)        # between the shoes: squash and stretch grow from the floor
NECK = (520, 592)        # under the chin
HAT = (372, 318)         # where the hat band meets the head
STEM = (536, 300)        # stem base in the head dimple
L_SHOULDER = (398, 636)  # viewer-left shoulder (thinking / pencil arm)
R_SHOULDER = (650, 626)  # viewer-right shoulder (notepad arm)
IDEA_SHOULDER = (402, 628)
BULB = (178, 188)        # light bulb glass centre
BULB_H = 178             # bulb height in master px

FPS = 60
LOOP = 480               # 8 s wingman loop
T_IDEA, T_WRITE, T_SMILE, T_BACK = 126, 216, 372, 450

GOLD, PINK, CREAM, CHERRY, INK = "FFFFC94D", "FFFF8FA3", "FFFFF9F3", "FFE83D55", "FF6E5257"


def art(p):
    """Master-space point -> artboard point."""
    return ((p[0] - CROP[0]) * S, (p[1] - CROP[1]) * S)


# --------------------------------------------------------------------------------------------- parts


def ellipse_mask(size, center, rx, ry, feather):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse((center[0] - rx, center[1] - ry, center[0] + rx, center[1] + ry), fill=255)
    return np.asarray(m.filter(ImageFilter.GaussianBlur(feather)), np.float32) / 255.0


def grow(alpha, px):
    im = Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.MaxFilter(px * 2 + 1)), np.float32)


def with_alpha(rgba, alpha):
    out = rgba.copy()
    out[..., 3] = np.clip(alpha, 0, 255)
    return out


def build_parts() -> dict[str, np.ndarray]:
    """All rig parts as float RGBA in master space (1024x1024)."""
    k = lambda n, g=0.0: key(load(RAW / f"{n}.png"), g)
    yy, xx = np.mgrid[0:1024, 0:1024]
    p: dict[str, np.ndarray] = {}

    # Body: legs, apron, shoulder stubs. Gemini left a blank head on it; the real head covers y > 470.
    body = k("body_v1")
    body[..., 3] *= yy >= 470
    p["body"] = body

    # Heads: neutral + four expressions + a blink-eyes overlay, all from head_v1 edits (silhouette IoU 0.998).
    for name in ("think", "idea", "write", "smile"):
        p[f"face_{name}"] = warp(k(f"face_{name}_v1"), *HEAD_T)
    blink = k("face_blink_v1")
    eyes = np.maximum(
        ellipse_mask((1024, 1024), (388, 470), 80, 74, 6), ellipse_mask((1024, 1024), (659, 470), 80, 74, 6)
    )
    blink[..., 3] *= eyes
    p["blink"] = warp(blink, *HEAD_T)
    head_alpha = p["face_think"][..., 3]

    # Hat and stem come from one render; split where they do not touch.
    hat = k("hatstem_v1")
    hat[..., 3] *= xx < 505
    p["hat"] = hat
    stem = k("hatstem_v1", 60.0)
    stem[..., 3] *= xx >= 505
    p["stem"] = stem

    # Arms: the isolation render is only a matte; colours come from the full pose (both at offset 0).
    think = k("pose_think_v1")
    matte = k("arms_think_v1")[..., 3]
    arms = with_alpha(think, np.minimum(matte, think[..., 3]))
    p["think_hand"] = with_alpha(arms, arms[..., 3] * (xx < 590))
    p["pad"] = with_alpha(arms, arms[..., 3] * (xx >= 590))

    write = k("pose_write_v1")
    matte = k("arms_write_v1")[..., 3]
    arms = with_alpha(write, np.minimum(matte, write[..., 3]))
    r, g, b = arms[..., 0], arms[..., 1], arms[..., 2]
    sleeve = (r > g + 60) & (r > b + 60)
    pad_side = (xx >= 640) | ((xx >= 600) & sleeve)
    p["write_arm"] = with_alpha(arms, arms[..., 3] * ~pad_side)
    p["write_pad"] = with_alpha(arms, arms[..., 3] * pad_side)

    # The raised idea arm sits behind the head: take the pose pixels left of the body, minus head and hat.
    idea = k("pose_idea_v1")
    region = (yy >= 340) & (((xx < 420) & (yy < 600)) | ((xx < 396) & (yy < 652)))
    blocked = np.maximum(grow(head_alpha, 2), grow(p["hat"][..., 3], 3))
    p["idea_arm"] = with_alpha(idea, idea[..., 3] * region * (1 - blocked / 255.0))
    return p


def bulb_layer() -> tuple[np.ndarray, tuple[float, float]]:
    """Keyed bulb resized for runtime; returns RGBA and the glass centre inside it (runtime px)."""
    b = key(load(RAW / "bulb_v1.png"))
    x0, y0, x1, y1 = bbox(b[..., 3], 8)
    b = b[y0:y1, x0:x1]
    scale = BULB_H * S / (y1 - y0)
    pm = b.copy()
    pm[..., :3] *= pm[..., 3:4] / 255
    im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA")
    im = im.resize((round((x1 - x0) * scale), round((y1 - y0) * scale)), Image.LANCZOS)
    out = np.asarray(im, np.float32).copy()
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 0, out[..., :3] * 255 / np.maximum(a, 1e-3), 0)
    glass = ((512 - x0) * scale, (385 - y0) * scale)
    return out, glass


def downscale(rgba: np.ndarray) -> np.ndarray:
    pm = rgba.copy()
    pm[..., :3] *= pm[..., 3:4] / 255
    im = Image.fromarray(np.clip(pm, 0, 255).round().astype(np.uint8), "RGBA")
    out = np.asarray(im.resize((round(1024 * S),) * 2, Image.LANCZOS), np.float32).copy()
    a = out[..., 3:4]
    out[..., :3] = np.where(a > 0, out[..., :3] * 255 / np.maximum(a, 1e-3), 0)
    return out


LAYERS = ("body", "idea_arm", "face_think", "face_idea", "face_write", "face_smile", "blink",
          "hat", "stem", "pad", "think_hand", "write_pad", "write_arm")


def write_layers() -> dict[str, tuple[float, float, int, int]]:
    """Writes parts (full res) and runtime assets; returns runtime boxes in artboard space."""
    PARTS.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    p = build_parts()
    boxes, rig = {}, {"master": "design/mascots/jack_rig/master.png", "space": "1024x1024 master px",
                      "head_transform": HEAD_T, "pivots": {}, "parts": {}}
    for name in LAYERS:
        rig["parts"][name] = save(p[name], PARTS / f"{name}.png")
        x, y, w, h = save(downscale(p[name]), ASSETS / f"jack_{name}.png")
        boxes[name] = (x - CROP[0] * S, y - CROP[1] * S, w, h)
    bulb, glass = bulb_layer()
    Image.fromarray(np.clip(bulb, 0, 255).round().astype(np.uint8), "RGBA").save(ASSETS / "jack_bulb.png", optimize=True)
    Image.open(ASSETS / "jack_bulb.png").save(PARTS / "bulb.png")
    boxes["bulb"] = (-glass[0], -glass[1], bulb.shape[1], bulb.shape[0])
    rig["pivots"] = {n: v for n, v in (("root", ROOT), ("neck", NECK), ("hat", HAT), ("stem", STEM),
                                        ("l_shoulder", L_SHOULDER), ("r_shoulder", R_SHOULDER),
                                        ("idea_shoulder", IDEA_SHOULDER), ("bulb", BULB))}
    rig["bulb_height"] = BULB_H
    (RIG / "jack_rig.json").write_text(json.dumps(rig, indent=2), encoding="utf-8")
    return boxes


# --------------------------------------------------------------------------------------------- RML

ASSET_IDS = {name: 100 + i for i, name in enumerate(LAYERS + ("bulb",))}

# Local object ids inside each artboard (artboard base is added).
O = dict(root=1, fx=2, bulb=3, glow=4, rays=5, write_arm=10, write_pad=11, think_hand=12, pad=13, head=14,
         hat=15, stem=16, blink=17, face_smile=18, face_write=19, face_idea=20, face_think=21, idea_arm=22,
         notes=23, body=24)
DOTS = [(268, 404, 9), (234, 346, 13), (205, 280, 18)]           # thought bubbles, master px + radius
SPARKLES = [(232, 318, 30, GOLD), (826, 336, 26, PINK), (190, 520, 22, CREAM), (860, 470, 30, GOLD),
            (318, 96, 22, PINK), (760, 250, 18, CREAM)]
RAYS = [-168, -132, -90, -48, -12]
# Notepad scribbles: start (master px), length, along the pad's top-edge slope.
PAD_SLOPE = math.atan2(17, 115)
NOTE_LINES = [((744, 604), 56), ((730, 631), 48), ((717, 657), 40)]
NOTE_HEART = (712, 694)


def ease_key(frame, value, interp):
    if interp in ("linear", "hold"):
        return f'<KeyFrameDouble value="{value:.6g}" frame="{frame}" interpolationType="{interp}"/>'
    if interp == "out":
        handles = 'x1="0.2" y1="0.8" x2="0.4" y2="1"'
    elif interp == "back":
        handles = 'x1="0.3" y1="1.45" x2="0.5" y2="1"'
    else:
        handles = 'x1="0.42" y1="0" x2="0.58" y2="1"'
    return (f'<KeyFrameDouble value="{value:.6g}" frame="{frame}" interpolationType="cubic">'
            f'<CubicEaseInterpolator {handles}/></KeyFrameDouble>')


def keyed(out, object_id, prop, keys, duration):
    """Emit one track. "flow" tracks get C1-continuous handles that also wrap across the loop seam."""
    merged = {f: (f, v, i) for f, v, i in keys}
    frames = sorted(merged)
    assert frames[0] == 0 and frames[-1] == duration, (object_id, prop, frames)
    assert abs(merged[0][1] - merged[duration][1]) < 1e-9, ("loop seam", object_id, prop)
    out.append(f'      <KeyedObject objectId="0:{object_id}"><KeyedProperty propertyKey="{prop}">')
    flow = all(merged[f][2] == "flow" for f in frames)
    slopes = [0.0] * len(frames)
    if flow:
        for i in range(len(frames) - 1):
            prev = i - 1 if i else len(frames) - 2
            span = frames[i] - frames[prev] if i else duration - frames[prev]
            before = (merged[frames[i]][1] - merged[frames[prev]][1]) / span
            after = (merged[frames[i + 1]][1] - merged[frames[i]][1]) / (frames[i + 1] - frames[i])
            if before * after > 0:
                slopes[i] = 2 * before * after / (before + after)
        slopes[-1] = slopes[0]
    for i, f in enumerate(frames):
        _, v, interp = merged[f]
        if flow and i + 1 < len(frames):
            dt, dv = frames[i + 1] - f, merged[frames[i + 1]][1] - v
            y1 = slopes[i] * dt / (3 * dv) if dv else 0
            y2 = 1 - slopes[i + 1] * dt / (3 * dv) if dv else 1
            out.append(f'        <KeyFrameDouble value="{v:.6g}" frame="{f}" interpolationType="cubic">'
                       f'<CubicEaseInterpolator x1="{1 / 3:.6f}" y1="{y1:.6f}" x2="{2 / 3:.6f}" y2="{y2:.6f}"/>'
                       '</KeyFrameDouble>')
        else:
            out.append("        " + ease_key(f, v, "linear" if interp == "flow" else interp))
    out.append("      </KeyedProperty></KeyedObject>")


def holds(points, duration):
    """Opacity switches: [(frame, value)] -> hold keys incl. the loop end."""
    ks = [(f, v, "hold") for f, v in points]
    if ks[-1][0] != duration:
        ks.append((duration, ks[0][1], "hold"))
    return ks


def flow(points):
    return [(f, v, "flow") for f, v in points]


def wave(start, end, period, amp, base=0.0, phase=0.0):
    """Sine-like flow keys between start and end (both at base)."""
    pts, f = [(start, base)], start + period / 4
    sign = 1 if phase == 0 else -1
    while f < end - period / 4:
        pts.append((round(f), base + sign * amp))
        sign, f = -sign, f + period / 2
    pts.append((end, base))
    return pts


# Which layers are visible per pose.
POSES = {
    "think": dict(think_hand=1, pad=1, idea_arm=0, write_arm=0, write_pad=0, face_think=1, face_idea=0,
                  face_write=0, face_smile=0),
    "idea": dict(think_hand=0, pad=1, idea_arm=1, write_arm=0, write_pad=0, face_think=0, face_idea=1,
                 face_write=0, face_smile=0),
    "write": dict(think_hand=0, pad=0, idea_arm=0, write_arm=1, write_pad=1, face_think=0, face_idea=0,
                  face_write=1, face_smile=0),
    "smile": dict(think_hand=0, pad=0, idea_arm=0, write_arm=1, write_pad=1, face_think=0, face_idea=0,
                  face_write=0, face_smile=1),
}


def rig_xml(base: int, name: str, boxes, pose: str, duration: int) -> list[str]:
    vis = POSES[pose]
    rx, ry = art(ROOT)
    L = [f'  <Artboard width="{ARTBOARD_W}" height="{ARTBOARD_H}" name="{name}" '
         f'defaultStateMachineId="0:{base + 900}" id="0:{base}">']

    def img(layer, node_world, oid=None, opacity=None, indent=8):
        x, y, w, h = boxes[layer]
        attrs = f'x="{x - node_world[0]:.3f}" y="{y - node_world[1]:.3f}" originX="0" originY="0"'
        if oid:
            attrs += f' id="0:{base + oid}"'
        if opacity is not None:
            attrs += f' opacity="{opacity}"'
        L.append(" " * indent + f'<Image {attrs} assetId="0:{ASSET_IDS[layer]}" name="{layer}"/>')

    def star(x, y, size, color, oid, label):
        L.append(f'      <Node x="{x:.2f}" y="{y:.2f}" opacity="0" scaleX="0.3" scaleY="0.3" name="{label}" '
                 f'id="0:{base + oid}"><Shape name="StarShape">'
                 f'<Star width="{size}" height="{size}" points="4" innerRadius="0.34" cornerRadius="2" name="Path"/>'
                 f'<Fill name="Fill"><SolidColor colorValue="{color}"/></Fill></Shape></Node>')

    # FX first: RML paints the first child on top.
    for i, (x, y, size, color) in enumerate(SPARKLES):
        star(*art((x, y)), size * S, color, 40 + i, f"Sparkle{i + 1}")
    for i, (x, y, r) in enumerate(DOTS):
        ax, ay = art((x, y))
        L.append(f'      <Node x="{ax:.2f}" y="{ay:.2f}" opacity="0" scaleX="0.2" scaleY="0.2" name="Thought{i + 1}" '
                 f'id="0:{base + 50 + i}"><Shape name="Dot"><Ellipse width="{2 * r * S:.2f}" height="{2 * r * S:.2f}"/>'
                 f'<Fill><SolidColor colorValue="{CREAM}"/></Fill>'
                 f'<Stroke thickness="{2.2:.2f}"><SolidColor colorValue="FFF3B8C2"/></Stroke></Shape></Node>')
    bx, by = art(BULB)
    L.append(f'    <Node x="{bx:.2f}" y="{by:.2f}" opacity="0" scaleX="0.2" scaleY="0.2" name="Bulb" '
             f'id="0:{base + O["bulb"]}">')
    L.append(f'      <Node opacity="0" scaleX="0.5" scaleY="0.5" name="Rays" id="0:{base + O["rays"]}">')
    for angle in RAYS:
        L.append(f'        <Node rotation="{math.radians(angle):.5f}" name="Ray"><Shape name="RayShape">'
                 f'<Rectangle x="{62 * S * 1.45:.2f}" width="{30 * S * 1.2:.2f}" height="{8 * S * 1.2:.2f}" originX="0" '
                 f'cornerRadiusTL="{4 * S * 1.2:.2f}"/><Fill><SolidColor colorValue="FFFFD45C"/></Fill></Shape></Node>')
    L.append("      </Node>")
    img("bulb", (0, 0), indent=6)
    glow_r = 105 * S
    L.append(f'      <Node opacity="0" name="Glow" id="0:{base + O["glow"]}"><Shape name="GlowShape">'
             f'<Ellipse width="{2 * glow_r:.1f}" height="{2 * glow_r:.1f}"/><Fill>'
             f'<RadialGradient startX="0" startY="0" endX="{glow_r:.1f}" endY="0">'
             '<GradientStop colorValue="CCFFE27A" position="0"/><GradientStop colorValue="66FFE9A0" position="0.55"/>'
             '<GradientStop colorValue="00FFF3C4" position="1"/></RadialGradient></Fill></Shape></Node>')
    L.append("    </Node>")

    L.append(f'    <Node x="{rx:.3f}" y="{ry:.3f}" name="Jack" id="0:{base + O["root"]}">')

    def group(label, pivot, layers, parent=(rx, ry), extra=None):
        px, py = art(pivot)
        L.append(f'      <Node x="{px - parent[0]:.3f}" y="{py - parent[1]:.3f}" opacity="{vis[label]}" '
                 f'name="{label}" id="0:{base + O[label]}">')
        if extra:
            extra((px, py))
        for layer in layers:
            img(layer, (px, py))
        L.append("      </Node>")

    def notes(pivot):
        L.append(f'        <Node name="Notes" id="0:{base + O["notes"]}">')
        for i, (start, length) in enumerate(NOTE_LINES):
            sx, sy = art(start)
            L.append(f'          <Node x="{sx - pivot[0]:.2f}" y="{sy - pivot[1]:.2f}" rotation="{PAD_SLOPE:.5f}" '
                     f'scaleX="0" name="Line{i + 1}" id="0:{base + 60 + i}"><Shape name="Ink">'
                     f'<Rectangle width="{length * S:.2f}" height="{3.4 * S:.2f}" originX="0" '
                     f'cornerRadiusTL="{1.7 * S:.2f}"/><Fill><SolidColor colorValue="{INK}"/></Fill></Shape></Node>')
        hx, hy = art(NOTE_HEART)
        L.append(f'          <Node x="{hx - pivot[0]:.2f}" y="{hy - pivot[1]:.2f}" rotation="{PAD_SLOPE:.5f}" '
                 f'scaleX="0" scaleY="0" name="Heart" id="0:{base + 63}"><Shape name="HeartShape">'
                 f'<PointsPath isClosed="true" name="HeartPath">')
        for point, incoming, outgoing in (((0, -4), (5, -11), (-5, -11)), ((-10, -5), (-10, -13), (-10, 1.5)),
                                          ((0, 9), (-3, 7), (3, 7)), ((10, -5), (10, 1.5), (10, -13))):
            ix, iy = incoming[0] - point[0], incoming[1] - point[1]
            ox, oy = outgoing[0] - point[0], outgoing[1] - point[1]
            L.append(f'            <CubicDetachedVertex x="{point[0]}" y="{point[1]}" inRotation="{math.atan2(iy, ix):.5f}" '
                     f'inDistance="{math.hypot(ix, iy):.4f}" outRotation="{math.atan2(oy, ox):.5f}" '
                     f'outDistance="{math.hypot(ox, oy):.4f}"/>')
        L.append(f'          </PointsPath><Fill><SolidColor colorValue="{CHERRY}"/></Fill></Shape></Node>')
        L.append("        </Node>")

    group("write_arm", L_SHOULDER, ["write_arm"])
    group("write_pad", R_SHOULDER, ["write_pad"], extra=notes)
    group("think_hand", L_SHOULDER, ["think_hand"])
    group("pad", R_SHOULDER, ["pad"])

    nx, ny = art(NECK)
    L.append(f'      <Node x="{nx - rx:.3f}" y="{ny - ry:.3f}" name="Head" id="0:{base + O["head"]}">')
    for label, pivot in (("hat", HAT), ("stem", STEM)):
        px, py = art(pivot)
        L.append(f'        <Node x="{px - nx:.3f}" y="{py - ny:.3f}" name="{label}" id="0:{base + O[label]}">')
        img(label, (px, py), indent=10)
        L.append("        </Node>")
    img("blink", (nx, ny), O["blink"], 0)
    for face in ("face_smile", "face_write", "face_idea", "face_think"):
        img(face, (nx, ny), O[face], vis[face])
    L.append("      </Node>")
    group("idea_arm", IDEA_SHOULDER, ["idea_arm"])
    img("body", (rx, ry), indent=6)
    L.append("    </Node>")
    return L


def node_base(name):
    """Rest x/y of animated nodes, relative to their parents, in artboard px."""
    rx, ry = art(ROOT)
    nx, ny = art(NECK)
    return {"root": (rx, ry), "head": (nx - rx, ny - ry), "bulb": art(BULB),
            "write_pad": (art(R_SHOULDER)[0] - rx, art(R_SHOULDER)[1] - ry),
            "pad": (art(R_SHOULDER)[0] - rx, art(R_SHOULDER)[1] - ry)}[name]


class Timeline:
    def __init__(self, base, duration):
        self.base, self.duration, self.tracks = base, duration, {}

    def add(self, obj, prop, keys):
        oid = self.base + (O[obj] if isinstance(obj, str) else obj)
        self.tracks[(oid, prop)] = keys

    def xml(self, name, anim_id):
        out = [f'    <LinearAnimation name="{name}" duration="{self.duration}" loopValue="loop" '
               f'id="0:{anim_id}">']
        for (oid, prop), keys in sorted(self.tracks.items()):
            keyed(out, oid, prop, keys, self.duration)
        out.append("    </LinearAnimation>")
        return out


# Property keys
X, Y, ROT, SX, SY, OP = 13, 14, 15, 16, 17, 18


def squash(t: Timeline, swaps, extra_y=()):
    """Body squash/stretch from the floor around every pose swap (the cut hides inside the squash)."""
    sy, sx = [(0, 1.0)], [(0, 1.0)]
    breath = 1.012
    for f in swaps:
        sy += [(f - 10, breath), (f - 1, 0.955), (f + 7, 1.045), (f + 18, 0.99), (f + 28, 1.0)]
        sx += [(f - 10, 1.0), (f - 1, 1.03), (f + 7, 0.98), (f + 18, 1.006), (f + 28, 1.0)]
    sy.append((t.duration, 1.0))
    sx.append((t.duration, 1.0))
    t.add("root", SY, flow(sorted(dict(sy).items())))
    t.add("root", SX, flow(sorted(dict(sx).items())))


def bob_head(t: Timeline, keys_rot, keys_dy):
    hx, hy = node_base("head")
    t.add("head", ROT, flow(keys_rot))
    t.add("head", Y, flow([(f, hy + dy * S) for f, dy in keys_dy]))


def follow(t: Timeline, obj, keys, gain):
    """Hat/stem follow-through: a lagged, amplified copy of the head's rotation keys."""
    lagged = {0: 0.0, t.duration: 0.0}
    for f, v in keys:
        if 0 < f + 7 < t.duration:
            lagged[f + 7] = v * gain
    t.add(obj, ROT, flow(sorted(lagged.items())))


def pose_holds(t: Timeline, schedule):
    """schedule: [(frame, pose)] starting at 0."""
    for layer in POSES["think"]:
        pts, last = [], None
        for f, pose in schedule:
            v = POSES[pose][layer]
            if v != last:
                pts.append((f, float(v)))
                last = v
        t.add(layer, OP, holds(pts, t.duration))


def blinks(t: Timeline, frames):
    pts = [(0, 0.0)]
    for f in frames:
        pts += [(f, 1.0), (f + 6, 0.0)]
    t.add("blink", OP, holds(pts, t.duration))


def thought_dots(t: Timeline, start, end):
    for i in range(3):
        a, oid = start + 14 * i, 50 + i
        ks_op = [(0, 0.0), (a, 0.0), (a + 8, 1.0), (end - 10 + 3 * i, 1.0), (end + 2 + 3 * i, 0.0), (t.duration, 0.0)]
        ks_sc = [(0, 0.2), (a, 0.2), (a + 9, 1.15), (a + 16, 1.0), (end - 10 + 3 * i, 1.0), (end + 2 + 3 * i, 0.3),
                 (t.duration, 0.2)]
        t.add(oid, OP, [(f, v, "cubic") for f, v in ks_op])
        t.add(oid, SX, [(f, v, "cubic") for f, v in ks_sc])
        t.add(oid, SY, [(f, v, "cubic") for f, v in ks_sc])
        x, y = art(DOTS[i][:2])
        t.add(oid, Y, [(0, y, "cubic"), (a, y, "cubic"), (end + 2 + 3 * i, y - 10, "cubic"), (t.duration, y, "cubic")])


def bulb_pop(t: Timeline, start, leave, gone, pulse_until=None):
    """Bulb pops in at `start`, glows, floats away from `leave` to `gone`."""
    bx, by = node_base("bulb")
    d = t.duration
    sc = [(0, 0.2, "hold"), (start, 0.2, "cubic"), (start + 10, 1.18, "cubic"), (start + 18, 0.94, "cubic"),
          (start + 26, 1.0, "cubic")]
    op = [(0, 0.0, "hold"), (start, 0.0, "cubic"), (start + 6, 1.0, "cubic")]
    yk = [(0, by, "hold"), (start, by + 14, "cubic"), (start + 12, by - 4, "cubic"), (start + 24, by, "cubic")]
    if leave is not None:
        sc += [(leave, 1.0, "cubic"), (gone, 0.55, "cubic"), (gone + 1, 0.2, "hold")]
        op += [(leave, 1.0, "cubic"), (gone, 0.0, "hold")]
        f = start + 24
        while f + 24 < leave:
            yk.append((f + 12, by - 3.5, "cubic"))
            f += 24
        yk += [(leave, by, "cubic"), (gone, by - 46, "cubic"), (gone + 1, by, "hold")]
    else:
        f = start + 24
        while f + 24 <= d:
            yk.append((f + 12, by - 3.5, "cubic"))
            f += 24
    for ks in (sc, op, yk):
        if ks[-1][0] != d:
            ks.append((d, ks[0][1], "hold"))
    t.add("bulb", SX, sc)
    t.add("bulb", SY, sc)
    t.add("bulb", OP, op)
    t.add("bulb", Y, yk)
    end = leave if leave is not None else d
    glow = [(0, 0.0, "hold"), (start + 2, 0.0, "cubic"), (start + 12, 1.0, "cubic")]
    f, hi = start + 12, False
    while f + 20 < end:
        f += 20
        glow.append((f, 1.0 if hi else 0.62, "cubic"))
        hi = not hi
    if leave is not None:
        glow += [(gone - 8, 0.0, "cubic"), (d, 0.0, "hold")]
    else:
        glow.append((d, 0.0, "cubic"))
    t.add("glow", OP, glow)
    rays_op = [(0, 0.0, "hold"), (start + 4, 0.0, "cubic"), (start + 12, 1.0, "cubic"),
               (start + 46, 1.0, "cubic"), (start + 66, 0.0, "cubic"), (d, 0.0, "hold")]
    rays_sc = [(0, 0.5, "hold"), (start + 4, 0.5, "cubic"), (start + 16, 1.12, "cubic"),
               (start + 30, 1.0, "cubic"), (start + 66, 1.25, "cubic"), (d, 0.5, "hold")]
    t.add("rays", OP, rays_op)
    t.add("rays", SX, rays_sc)
    t.add("rays", SY, rays_sc)


def scribble(t: Timeline, start, line_times, heart_at, clear):
    """Pencil scribbles; each line grows while the pencil wiggles; the heart pops last."""
    rot = [(0, 0.0)]
    for a, b in line_times:
        rot += [(a - 4, 0.0)] + wave(a, b, 10, 0.028, 0.0)[1:-1] + [(b + 2, 0.0)]
    rot += [(heart_at - 2, 0.0), (heart_at + 3, 0.04), (heart_at + 9, -0.015), (heart_at + 16, 0.0), (t.duration, 0.0)]
    t.add("write_arm", ROT, flow(sorted(dict(rot).items())))
    for i, (a, b) in enumerate(line_times):
        t.add(60 + i, SX, [(0, 0.0, "hold"), (a, 0.0, "linear"), (b, 1.0, "hold"), (clear, 0.0, "hold"),
                           (t.duration, 0.0, "hold")])
    hs = [(0, 0.0, "hold"), (heart_at, 0.0, "cubic"), (heart_at + 8, 1.3, "cubic"), (heart_at + 15, 1.0, "cubic"),
          (clear, 0.0, "hold"), (t.duration, 0.0, "hold")]
    t.add(63, SX, hs)
    t.add(63, SY, hs)


def sparkle_burst(t: Timeline, start):
    d = t.duration
    for i in range(len(SPARKLES)):
        a = start + 7 * i
        b = a + 34
        sc = [(0, 0.3, "hold"), (a, 0.3, "cubic"), (a + 9, 1.1, "cubic"), (b, 0.3, "cubic"), (d, 0.3, "hold")]
        t.add(40 + i, OP, [(0, 0.0, "hold"), (a, 0.0, "cubic"), (a + 7, 1.0, "cubic"), (b, 0.0, "cubic"),
                           (d, 0.0, "hold")])
        t.add(40 + i, SX, sc)
        t.add(40 + i, SY, sc)
        t.add(40 + i, ROT, [(0, 0.0, "hold"), (a, 0.0, "cubic"), (b, 0.9, "cubic"), (d, 0.0, "hold")])


def hops(t: Timeline, start, count, height=16):
    rx, ry = node_base("root")
    pts = [(0, ry)]
    f = start
    for i in range(count):
        h = height * (0.65 ** i)
        pts += [(f, ry), (f + 10, ry - h * S * 1.6), (f + 20, ry)]
        f += 22
    pts.append((t.duration, ry))
    t.add("root", Y, flow(sorted(dict(pts).items())))
    return f


def timeline_wingman(base) -> Timeline:
    t = Timeline(base, LOOP)
    pose_holds(t, [(0, "think"), (T_IDEA, "idea"), (T_WRITE, "write"), (T_SMILE, "smile"), (T_BACK, "think")])
    blinks(t, (70, 300))
    squash(t, (T_IDEA, T_WRITE, T_BACK))
    hops(t, T_SMILE + 4, 2)
    rot = [(0, 0.0), (36, -0.045), (64, -0.03), (96, -0.05), (T_IDEA - 2, -0.02), (T_IDEA + 8, 0.03), (T_IDEA + 22, -0.01),
           (T_IDEA + 40, 0.012), (T_IDEA + 66, 0.0), (T_WRITE + 10, 0.045), (260, 0.03), (300, 0.05), (340, 0.035),
           (T_SMILE + 4, 0.0), (T_SMILE + 22, -0.06), (T_SMILE + 44, 0.055), (T_SMILE + 66, -0.03), (T_BACK - 6, 0.0),
           (LOOP, 0.0)]
    dy = [(0, 0), (40, 3), (90, 0), (T_IDEA + 6, -10), (T_IDEA + 20, 2), (T_IDEA + 34, 0), (T_WRITE + 12, 5),
          (290, 3), (T_SMILE + 6, 0), (T_SMILE + 16, 6), (T_SMILE + 28, -2), (T_SMILE + 38, 4), (T_SMILE + 50, 0),
          (LOOP, 0)]
    bob_head(t, rot, dy)
    follow(t, "hat", rot, -0.9)
    follow(t, "stem", rot, -2.4)
    t.add("think_hand", ROT, flow([(0, 0.0)] + wave(18, 110, 22, 0.022)[0:] + [(LOOP, 0.0)]))
    t.add("idea_arm", ROT, flow([(0, -0.36), (T_IDEA, -0.36), (T_IDEA + 9, 0.06), (T_IDEA + 18, -0.02),
                                 (T_IDEA + 28, 0.0), (T_IDEA + 46, 0.03), (T_IDEA + 58, -0.02), (T_IDEA + 70, 0.0),
                                 (T_WRITE, -0.05), (LOOP, -0.36)]))
    px, py = node_base("pad")
    t.add("pad", Y, flow([(0, py), (30, py - 2.5), (60, py), (90, py - 2.5), (T_IDEA, py), (T_IDEA + 12, py + 3),
                          (T_IDEA + 30, py - 1.5), (T_IDEA + 50, py), (LOOP, py)]))
    wx, wy = node_base("write_pad")
    t.add("write_pad", Y, flow([(0, wy), (T_WRITE, wy + 6), (T_WRITE + 14, wy - 2), (T_WRITE + 26, wy),
                                (T_SMILE, wy), (T_SMILE + 14, wy - 4), (T_SMILE + 30, wy), (LOOP, wy)]))
    t.add("write_pad", ROT, flow([(0, 0.0), (T_WRITE + 30, 0.0), (300, -0.012), (350, 0.0), (T_SMILE + 18, 0.03),
                                  (T_SMILE + 40, -0.02), (T_SMILE + 60, 0.0), (LOOP, 0.0)]))
    thought_dots(t, 16, T_IDEA - 4)
    bulb_pop(t, T_IDEA, T_WRITE + 6, T_WRITE + 40)
    scribble(t, T_WRITE, [(236, 262), (272, 296), (306, 326)], 338, T_BACK)
    sparkle_burst(t, T_SMILE + 2)
    return t


def timeline_think(base) -> Timeline:
    t = Timeline(base, 150)
    blinks(t, (96,))
    rot = [(0, -0.03), (40, -0.05), (75, -0.025), (110, -0.05), (150, -0.03)]
    bob_head(t, rot, [(0, 0), (38, 3), (75, 0), (112, 3), (150, 0)])
    follow(t, "stem", [(40, 0.02), (110, -0.02)], 1.0)
    t.add("think_hand", ROT, flow([(0, 0.0)] + wave(10, 140, 22, 0.022)[0:] + [(150, 0.0)]))
    t.add("root", SY, flow([(0, 1.0), (75, 1.012), (150, 1.0)]))
    thought_dots(t, 12, 128)
    return t


def bulb_steady(t: Timeline):
    """Idea segment: the bulb is already lit; it floats, breathes and its rays twinkle."""
    d = t.duration
    bx, by = node_base("bulb")
    t.add("bulb", OP, [(0, 1.0, "hold"), (d, 1.0, "hold")])
    t.add("bulb", Y, flow([(0, by), (d // 4, by - 4), (d // 2, by), (3 * d // 4, by - 4), (d, by)]))
    sc = flow([(0, 1.0), (d // 4, 1.04), (d // 2, 1.0), (3 * d // 4, 1.04), (d, 1.0)])
    t.add("bulb", SX, sc)
    t.add("bulb", SY, sc)
    t.add("glow", OP, flow([(0, 0.7), (d // 4, 1.0), (d // 2, 0.7), (3 * d // 4, 1.0), (d, 0.7)]))
    t.add("rays", OP, flow([(0, 0.35), (d // 4, 1.0), (d // 2, 0.35), (3 * d // 4, 1.0), (d, 0.35)]))
    rs = flow([(0, 0.92), (d // 4, 1.1), (d // 2, 0.92), (3 * d // 4, 1.1), (d, 0.92)])
    t.add("rays", SX, rs)
    t.add("rays", SY, rs)


def timeline_idea(base) -> Timeline:
    t = Timeline(base, 120)
    rot = [(0, 0.0), (30, 0.018), (60, 0.0), (90, -0.012), (120, 0.0)]
    bob_head(t, rot, [(0, 0), (30, -3), (60, 0), (90, -3), (120, 0)])
    follow(t, "stem", rot, -2.4)
    t.add("idea_arm", ROT, flow([(0, 0.0)] + wave(6, 114, 27, 0.03) + [(120, 0.0)]))
    t.add("root", SY, flow([(0, 1.0), (30, 1.012), (60, 1.0), (90, 1.012), (120, 1.0)]))
    bulb_steady(t)
    return t


def timeline_write(base) -> Timeline:
    t = Timeline(base, 180)
    blinks(t, (120,))
    bob_head(t, [(0, 0.04), (45, 0.05), (90, 0.03), (135, 0.05), (180, 0.04)],
             [(0, 4), (45, 2), (90, 5), (135, 2), (180, 4)])
    follow(t, "stem", [(45, 0.01), (135, -0.01)], -2.0)
    scribble(t, 0, [(16, 42), (52, 76), (86, 106)], 118, 168)
    t.add("root", SY, flow([(0, 1.0), (90, 1.01), (180, 1.0)]))
    return t


def timeline_smile(base) -> Timeline:
    t = Timeline(base, 120)
    hops(t, 6, 2)
    rot = [(0, 0.0), (20, -0.06), (42, 0.055), (64, -0.03), (90, 0.0), (120, 0.0)]
    bob_head(t, rot, [(0, 0), (12, 6), (24, -2), (34, 4), (46, 0), (120, 0)])
    follow(t, "hat", rot, -0.9)
    follow(t, "stem", rot, -2.4)
    t.add("root", SY, flow([(0, 1.0), (5, 0.96), (14, 1.04), (26, 0.97), (36, 1.03), (48, 1.0), (120, 1.0)]))
    sparkle_burst(t, 4)
    wx, wy = node_base("write_pad")
    t.add("write_pad", ROT, flow([(0, 0.0), (18, 0.03), (40, -0.02), (60, 0.0), (120, 0.0)]))
    t.add(63, SX, [(0, 1.0, "hold"), (120, 1.0, "hold")])
    t.add(63, SY, [(0, 1.0, "hold"), (120, 1.0, "hold")])
    for i in range(3):
        t.add(60 + i, SX, [(0, 1.0, "hold"), (120, 1.0, "hold")])
    return t


ARTBOARDS = [  # name, base id, pose at frame 0, timeline factory
    ("JackWingman", 10000, "think", timeline_wingman),
    ("JackThink", 20000, "think", timeline_think),
    ("JackIdea", 30000, "idea", timeline_idea),
    ("JackWrite", 40000, "write", timeline_write),
    ("JackSmile", 50000, "smile", timeline_smile),
]


def build_scene(boxes) -> str:
    lines = ['<Rive version="1" kind="fragment">']
    for name, aid in ASSET_IDS.items():
        lines.append(f'  <ImageAsset file="assets/jack_{name}.png" name="jack_{name}" id="0:{aid}"/>')
    for name, base, pose, factory in ARTBOARDS:
        t = factory(base)
        lines += rig_xml(base, name, boxes, pose, t.duration)
        lines += t.xml(name, base + 800)
        lines += [f'    <StateMachine name="{name}" id="0:{base + 900}">',
                  f'      <StateMachineLayer name="Layer 1" id="0:{base + 901}">',
                  '        <AnyState x="-200" y="-120"/>', '        <ExitState x="400" y="-120"/>',
                  f'        <EntryState><StateTransition stateToId="0:{base + 902}"/></EntryState>',
                  f'        <AnimationState x="0" animationId="0:{base + 800}" id="0:{base + 902}"/>',
                  "      </StateMachineLayer>", "    </StateMachine>", "  </Artboard>"]
    lines.append("</Rive>")
    return "\n".join(lines) + "\n"


def main():
    boxes = write_layers()
    (HERE / "scene.rml").write_text(build_scene(boxes), encoding="utf-8")
    (HERE / "rive.yaml").write_text("name: jack_wingman\nmain: JackWingman\n", encoding="utf-8")
    print(f"Wrote {HERE / 'scene.rml'} ({ARTBOARD_W}x{ARTBOARD_H}, {len(ARTBOARDS)} artboards)")


if __name__ == "__main__":
    main()
