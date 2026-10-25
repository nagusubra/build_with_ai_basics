"""Build Jill's isolated, registered wingwoman rig from approved image edits."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE.with_name("mascot_rive_jack")))
from parts import key, load, register, save, warp
from build_jack import bulb_layer, flow, holds, keyed, downscale

RIG = REPO / "design" / "mascots" / "jill_rig"
RAW, PARTS, ASSETS = RIG / "raw", RIG / "parts", HERE / "assets"
S = 0.75
CROP = (80, 0, 944, 970)
WIDTH, HEIGHT = 648, 728
ROOT, NECK, STEM = (520, 950), (520, 615), (480, 325)
LEFT, RIGHT = (428, 626), (610, 626)
WRITE_TIP = (602, 648)
POSES = ("think", "idea", "write", "smile")
LAYERS = ("body", "stem", "blink") + tuple(f"face_{p}" for p in POSES) + tuple(
    f"{p}_{side}" for p in ("think", "idea", "write") for side in ("left", "right"))
IDS = {name: i + 100 for i, name in enumerate(LAYERS)}
IDS["bulb"] = 200
O = {"root": 1, "head": 2, "stem": 3, "blink": 4, "bulb": 5,
     **{f"face_{p}": 10 + i for i, p in enumerate(POSES)},
     **{f"{p}_{side}": 20 + i for i, (p, side) in enumerate(
         (p, side) for p in ("think", "idea", "write") for side in ("left", "right"))}}
X, Y, ROT, SX, SY, OP = 13, 14, 15, 16, 17, 18


def art(point):
    return ((point[0] - CROP[0]) * S, (point[1] - CROP[1]) * S)


def polygon(points):
    image = Image.new("L", (1024, 1024))
    ImageDraw.Draw(image).polygon(points, fill=255)
    return np.asarray(image, np.float32) / 255


def build_parts():
    master = load(RIG / "master.png")
    yy, xx = np.mgrid[:1024, :1024]
    metadata = {"master": "master.png", "space": "1024x1024 master px", "registration": {}, "parts": {},
                "pivots": {"root": ROOT, "head": NECK, "stem": STEM, "left": LEFT, "right": RIGHT}}

    def aligned(name, box, reference=None):
        version = "v2" if name == "pose_write" else "v1"
        source = load(RAW / f"{name}_{version}.png")
        target = master if reference is None else reference
        score, scale, dx, dy = register(source, target, box, scales=(0.99, 1.0, 1.01), search=12)
        if score < 0.95:
            raise ValueError(f"{name} registration NCC {score:.4f} below 0.95")
        metadata["registration"][name] = {"ncc": score, "scale": scale, "dx": dx, "dy": dy,
                                          "source": f"raw/{name}_{version}.png"}
        return warp(key(source), scale, dx, dy)

    p = {"body": aligned("body", (410, 815, 665, 942))}
    p["body"][..., 3] *= yy >= 550
    head = aligned("head", (350, 370, 665, 590))
    head_source = load(RAW / "head_v1.png")
    head_alpha = head[..., 3].copy()
    stem = key(master, 85)
    stem[..., 3] *= polygon([(290, 20), (580, 20), (580, 110), (532, 125), (512, 195),
                            (508, 275), (520, 342), (448, 342), (458, 275), (456, 204), (290, 235)])
    p["stem"] = stem
    for pose in ("think", "idea", "write"):
        image = aligned(f"pose_{pose}", (410, 815, 665, 942))
        version = "v2" if pose == "write" else "v1"
        matte = key(load(RAW / f"arms_{pose}_{version}.png"))
        if pose == "idea":
            # The isolation was enlarged. Register each hand back to the full
            # pose; retain the full pose's pixels, never the isolation's color.
            left, right = matte.copy(), matte.copy()
            left[..., 3] *= xx < 512
            right[..., 3] *= xx >= 512
            left = warp(left, 0.514, 240.2, 411.0)
            right = warp(right, 0.484, 300.5, 403.0)
            matte = np.maximum(left, right)
            metadata["registration"]["arms_idea"] = {
                "left": {"scale": 0.514, "dx": 240.2, "dy": 411.0, "ncc": 0.937639},
                "right": {"scale": 0.484, "dx": 300.5, "dy": 403.0, "ncc": 0.960199},
            }
        # The full pose supplies color; the isolation is only an alpha matte.
        transform = metadata["registration"][f"pose_{pose}"]
        matte = warp(matte, transform["scale"], transform["dx"], transform["dy"])
        arms = image.copy()
        arms[..., 3] = np.minimum(image[..., 3], matte[..., 3])
        non_red_prop = (image[..., 1] > 80) & (image[..., 2] > image[..., 0] * 0.5)
        arms[..., 3] *= np.maximum(1 - head_alpha / 255, non_red_prop)
        min_y = 520 if pose == "think" else 495 if pose == "idea" else 540
        arms[..., 3] *= yy >= min_y
        left_side = xx < (757.5 - 0.25 * yy) if pose == "write" else xx < 505
        for side, mask in (("left", left_side), ("right", ~left_side)):
            part = arms.copy()
            part[..., 3] *= mask
            if pose == "write" and side == "left":
                part = warp(part, 1, 28, -4)
            p[f"{pose}_{side}"] = part
    metadata["writing_contact"] = {"arm_translation": (28, -4), "tip_pivot": WRITE_TIP}
    for pose in POSES:
        p[f"face_{pose}"] = aligned(f"face_{pose}", (535, 200, 735, 340), head_source)
        p[f"face_{pose}"][..., 3] = np.minimum(p[f"face_{pose}"][..., 3], head_alpha)
    blink = aligned("face_blink", (535, 200, 735, 340), head_source)
    eyes = Image.new("L", (1024, 1024))
    draw = ImageDraw.Draw(eyes)
    draw.ellipse((355, 402, 490, 534), fill=255)
    draw.ellipse((540, 380, 675, 518), fill=255)
    blink[..., 3] *= np.asarray(eyes.filter(ImageFilter.GaussianBlur(5)), np.float32) / 255
    p["blink"] = blink
    return p, metadata


def write_layers():
    PARTS.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    parts, metadata = build_parts()
    boxes = {}
    for name in LAYERS:
        metadata["parts"][name] = save(parts[name], PARTS / f"{name}.png")
        x, y, w, h = save(downscale(parts[name], keep_green=name == "stem"), ASSETS / f"jill_{name}.png")
        boxes[name] = (x - CROP[0] * S, y, w, h)
    bulb, glass = bulb_layer()
    Image.fromarray(np.clip(bulb, 0, 255).round().astype(np.uint8), "RGBA").save(ASSETS / "jill_bulb.png")
    boxes["bulb"] = (-glass[0], -glass[1], bulb.shape[1], bulb.shape[0])
    metadata["reused_prop"] = "Jack's approved glossy bulb, rebuilt from his raw/bulb_v1.png"
    (RIG / "jill_rig.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return boxes


class Timeline:
    def __init__(self, base, duration):
        self.base, self.duration, self.tracks = base, duration, {}

    def add(self, name, prop, keys):
        self.tracks[(self.base + (O[name] if isinstance(name, str) else name), prop)] = keys

    def xml(self, name):
        lines = [f'    <LinearAnimation name="{name}" duration="{self.duration}" loopValue="loop" id="0:{self.base + 800}">']
        for (oid, prop), keys in sorted(self.tracks.items()):
            keyed(lines, oid, prop, keys, self.duration)
        return lines + ["    </LinearAnimation>"]


def timeline(base, duration, schedule):
    t = Timeline(base, duration)
    for pose in POSES:
        t.add(f"face_{pose}", OP, holds([(f, float(p == pose)) for f, p in schedule], duration))
    for pose in ("think", "idea", "write"):
        for side in ("left", "right"):
            t.add(f"{pose}_{side}", OP, holds([
                (f, float(p == pose or p == "smile" and pose == "write")) for f, p in schedule], duration))
    rotations = [(0, 0.0)]
    heights = [(0, 0.0)]
    for f in range(20, duration, 40):
        rotations.append((f, 0.022 if (f // 40) % 2 else -0.022))
        heights.append((f, -2.0 if (f // 40) % 2 else 2.0))
    rotations.append((duration, 0.0))
    heights.append((duration, 0.0))
    _, ry = art(ROOT)
    t.add("head", ROT, flow(rotations))
    t.add("head", Y, flow([(f, (NECK[1] - ROOT[1] + value) * S) for f, value in heights]))
    t.add("stem", ROT, flow([(f, -value * 1.7) for f, value in rotations]))
    squash_y = [(0, 1.0), (duration // 4, 1.008), (duration // 2, 1.0),
                (3 * duration // 4, 1.008), (duration, 1.0)]
    squash_x = [(0, 1.0), (duration, 1.0)]
    for f, _ in schedule[1:]:
        squash_y += [(f - 10, 1.008), (f - 1, 0.963), (f + 7, 1.035), (f + 18, 1.0)]
        squash_x += [(f - 10, 1.0), (f - 1, 1.022), (f + 7, 0.984), (f + 18, 1.0)]
    t.add("root", SY, flow(sorted(dict(squash_y).items())))
    t.add("root", SX, flow(sorted(dict(squash_x).items())))
    hop_y = [(0, ry), (duration, ry)]
    for f, p in schedule:
        if p == "smile":
            hop_y += [(f + 4, ry), (f + 15, ry - 14 * S), (f + 26, ry),
                      (f + 30, ry), (f + 40, ry - 8 * S), (f + 50, ry)]
    t.add("root", Y, flow(sorted(dict(hop_y).items())))
    for pose in ("think", "idea", "write"):
        for side in ("left", "right"):
            amp = (0.009 if side == "left" else 0.0) if pose == "write" else 0.018
            t.add(f"{pose}_{side}", ROT, flow([(0, 0.0), (duration // 4, amp), (duration // 2, 0.0),
                                             (3 * duration // 4, -amp), (duration, 0.0)]))
    blink_frames = (70, 300) if duration == 480 else ((96,) if duration == 150 else (120,) if duration == 180 else ())
    blink_keys = [(0, 0.0)]
    for f in blink_frames:
        blink_keys += [(f, 1.0), (f + 6, 0.0)]
    t.add("blink", OP, holds(blink_keys, duration))
    for i in range(3):
        t.add(50 + i, OP, holds([(f, float(p == "think")) for f, p in schedule], duration))
        t.add(50 + i, SY, flow([(0, 0.9), (duration // 2, 1.08), (duration, 0.9)]))
        t.add(50 + i, SX, flow([(0, 0.9), (duration // 2, 1.08), (duration, 0.9)]))
    t.add("bulb", OP, holds([(f, float(p == "idea")) for f, p in schedule], duration))
    t.add("bulb", SY, flow([(0, 1.0), (duration // 2, 1.05), (duration, 1.0)]))
    t.add("bulb", SX, flow([(0, 1.0), (duration // 2, 1.05), (duration, 1.0)]))
    for i in range(4):
        t.add(60 + i, OP, holds([(f, float(p == "smile")) for f, p in schedule], duration))
        t.add(60 + i, ROT, flow([(0, 0.0), (duration // 2, 0.3), (duration, 0.0)]))
    start = 216 if duration == 480 else 0
    clear = 450 if duration == 480 else duration - 12
    for i in range(3):
        if schedule[0][1] == "smile":
            keys = holds([(0, 1.0)], duration)
        elif duration == 480 or schedule[0][1] == "write":
            a, b = start + 20 + i * 30, start + 42 + i * 30
            keys = [(0, 0.0, "hold"), (a, 0.0, "linear"), (b, 1.0, "hold"),
                    (clear, 0.0, "hold"), (duration, 0.0, "hold")]
        else:
            keys = holds([(0, 0.0)], duration)
        t.add(70 + i, SX, keys)
    return t


def wingwoman(base):
    return timeline(base, 480, [(0, "think"), (126, "idea"), (216, "write"), (372, "smile"), (450, "think")])


def think(base):
    return timeline(base, 150, [(0, "think")])


def idea(base):
    return timeline(base, 120, [(0, "idea")])


def write(base):
    return timeline(base, 180, [(0, "write")])


def smile(base):
    return timeline(base, 120, [(0, "smile")])


ARTBOARDS = [
    ("JillWingwoman", 10000, "think", wingwoman), ("JillThink", 20000, "think", think),
    ("JillIdea", 30000, "idea", idea), ("JillWrite", 40000, "write", write),
    ("JillSmile", 50000, "smile", smile),
]


def rig_xml(name, base, pose, boxes):
    lines = [f'  <Artboard width="{WIDTH}" height="{HEIGHT}" name="{name}" defaultStateMachineId="0:{base + 900}" id="0:{base}">']

    def node(label, point, parent=(0, 0), opacity=1):
        x, y = point[0] - parent[0], point[1] - parent[1]
        oid = O[label] if isinstance(label, str) else label
        lines.append(f'    <Node name="{label}" x="{x:.3f}" y="{y:.3f}" opacity="{opacity}" id="0:{base + oid}">')

    def image(layer, pivot, oid=None, opacity=None):
        x, y, w, h = boxes[layer]
        attrs = f' id="0:{base + O[oid]}"' if oid else ""
        if opacity is not None:
            attrs += f' opacity="{opacity}"'
        lines.append(f'      <Image name="{layer}" x="{x - pivot[0]:.3f}" y="{y - pivot[1]:.3f}" originX="0" originY="0" assetId="0:{IDS[layer]}"{attrs}/>')

    # First RML children paint on top; effects sit in front of the character.
    for i, point in enumerate(((255, 420), (230, 365), (220, 305))):
        node(50 + i, art(point), opacity=int(pose == "think"))
        radius = (8 + i * 3) * S
        lines.append(f'      <Shape><Ellipse width="{radius * 2}" height="{radius * 2}"/><Fill><SolidColor colorValue="FFFFF9F3"/></Fill><Stroke thickness="1.5"><SolidColor colorValue="FFE83D55"/></Stroke></Shape></Node>')
    for i, point in enumerate(((245, 260), (790, 330), (265, 540), (820, 540))):
        node(60 + i, art(point), opacity=int(pose == "smile"))
        lines.append('      <Shape><Star width="19" height="19" points="4" innerRadius="0.3"/><Fill><SolidColor colorValue="FFFFC94D"/></Fill></Shape></Node>')
    node("bulb", art((805, 195)), opacity=int(pose == "idea"))
    image("bulb", (0, 0))
    lines.append("    </Node>")
    root, neck = art(ROOT), art(NECK)
    node("root", root)
    for p in ("think", "idea", "write"):
        for side, pivot in (("left", WRITE_TIP if p == "write" else LEFT), ("right", RIGHT)):
            label = f"{p}_{side}"
            node(label, art(pivot), root, int(pose == p or pose == "smile" and p == "write"))
            if label == "write_right":
                for i, point in enumerate(((624, 620), (620, 644), (616, 668))):
                    node(70 + i, art(point), art(pivot))
                    lines.append('      <Shape><Rectangle width="30" height="2" originX="0" cornerRadiusTL="1"/><Fill><SolidColor colorValue="FFA71938"/></Fill></Shape></Node>')
            image(label, art(pivot))
            lines.append("    </Node>")
    node("head", neck, root)
    image("blink", neck, "blink", 0)
    for p in POSES:
        image(f"face_{p}", neck, f"face_{p}", int(pose == p))
    node("stem", art(STEM), neck)
    image("stem", art(STEM))
    lines += ["    </Node>", "    </Node>"]
    image("body", root)
    lines.append("    </Node>")
    return lines


def main():
    boxes = write_layers()
    lines = ['<Rive version="1" kind="fragment">']
    for layer, oid in IDS.items():
        lines.append(f'  <ImageAsset file="assets/jill_{layer}.png" name="jill_{layer}" id="0:{oid}"/>')
    for name, base, pose, factory in ARTBOARDS:
        lines += rig_xml(name, base, pose, boxes) + factory(base).xml(name)
        lines += [f'    <StateMachine name="{name}" id="0:{base + 900}">',
                  f'      <StateMachineLayer name="Loop" id="0:{base + 901}">',
                  '        <AnyState x="-200" y="-120"/>', '        <ExitState x="400" y="-120"/>',
                  f'        <EntryState><StateTransition stateToId="0:{base + 902}"/></EntryState>',
                  f'        <AnimationState animationId="0:{base + 800}" id="0:{base + 902}"/>',
                  "      </StateMachineLayer>", "    </StateMachine>", "  </Artboard>"]
    lines.append("</Rive>")
    (HERE / "scene.rml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (HERE / "rive.yaml").write_text("name: jill_wingwoman\nmain: JillWingwoman\n", encoding="utf-8")
    print(f"Wrote Jill: {WIDTH}x{HEIGHT}, five artboards")


if __name__ == "__main__":
    main()
