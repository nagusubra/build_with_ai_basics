"""Build the isolated layered DuoWelcome proof.

This is a one-off art/proof pipeline, not part of the Flutter app. It reads the
1024x1024 transparent cutout in design/mascots, extracts four layers, writes
768px assets and scene.rml, and leaves the shipped seven-pose asset alone.

Run from the repo root:
    python app/tool/mascot_rive_duo/build_proof.py
"""

from __future__ import annotations

import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
APP = HERE.parents[1]
REPO = APP.parent
SRC = REPO / "design" / "mascots" / "cherry_duo_welcome.png"
ASSETS = HERE / "assets"
BUILD = HERE / "build"

ARTBOARD = 768
SOURCE_SIZE = 1024
DURATION = 192

# Artboard-space pivots. The arm layers are rotated around these points. Each
# cut is a disk centred on its pivot, so rotating the layer cannot open a gap
# at the joint: a disk is invariant under rotation about its own centre.
JACK_PIVOT = (305, 580)
JACK_DISK_R = 24
JILL_PIVOT = (895, 635)
JILL_DISK_R = 30
MOTION_PIVOT = (384, 660)


def arc_points(cx, cy, radius, start_deg, end_deg, steps=20):
    angles = np.linspace(math.radians(start_deg), math.radians(end_deg), steps)
    return [(cx + radius * math.cos(a), cy + radius * math.sin(a)) for a in angles]


# Jack's pan arm: pan, vegetables, handle, glove and forearm. The right edge
# follows the apron edge down to the forearm, so no apron strip travels with
# the arm. The shoulder disk is fully inside the torso red.
JACK_ARM_POLY = (
    [(305, 556), (300, 560), (285, 572), (272, 585), (258, 592), (243, 592),
     (228, 585), (215, 575), (207, 558), (198, 545), (185, 535), (172, 522),
     (168, 505), (172, 488), (178, 470), (180, 452), (175, 435), (170, 418),
     (172, 400), (165, 385), (152, 372), (138, 362), (122, 355), (105, 351),
     (88, 353), (70, 362), (55, 377), (43, 395), (38, 415), (36, 435),
     (30, 455), (20, 472), (13, 492), (13, 515), (20, 535), (34, 552),
     (52, 565), (75, 574), (100, 578), (125, 584), (145, 594), (160, 608),
     (175, 628), (195, 645), (215, 657), (240, 665), (262, 666),
     (270, 654), (278, 642), (286, 630), (294, 618), (300, 608)]
    + arc_points(305, 580, JACK_DISK_R, 100, -90, 16)
)

# Body patch: the part of Jack's arm that sits in front of the torso, above
# the apron edge. Filled with torso red / apron beige; the arm covers it at
# rest. Stops short of the apron button at (325-365, 600-645).
JACK_PATCH_POLY = [
    (255, 548), (330, 548), (330, 583), (322, 593), (315, 599), (300, 601),
    (285, 597), (270, 591), (255, 584),
]

# Jill's hand + phone. The wrist edge is a disk around the wrist pivot, so the
# red forearm stump underneath is always covered as the wrist bobs.
JILL_HAND_POLY = (
    [(876, 470), (900, 466), (930, 470), (960, 476), (982, 483), (986, 500),
     (984, 525), (982, 550), (980, 575), (978, 600), (980, 620), (974, 638),
     (962, 650), (945, 655), (925, 644)]
    + arc_points(895, 635, JILL_DISK_R, 18, 180, 18)
    + [(866, 620), (867, 600), (868, 580), (866, 560), (867, 540), (869, 520),
       (868, 500), (870, 482)]
)

JILL_PATCH_CENTER = (895, 635)
JILL_PATCH_R = JILL_DISK_R

# Sparkles keep the shipped artboard positions, phases and colours.
SPARKLES = [
    (72, 92, 0.00, "FFFFD166"),
    (700, 104, 0.33, "FFFF8FA3"),
    (420, 44, 0.66, "FFFFD166"),
]

# Closed eyelids for Jack. Points are cubic Bezier handles in source pixels.
LEFT_LID = ((305, 490), (327, 471), (361, 467), (383, 485))
RIGHT_LID = ((445, 509), (464, 491), (494, 486), (513, 503))


def polygon_mask(size: tuple[int, int], points: list[tuple[float, float]], ss: int = 4) -> np.ndarray:
    """Binary mask. Anti-aliasing is left to the original image's alpha, so the
    cut edge stays exact at rest and the silhouette keeps its own feathering."""
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in points], fill=255)
    m = m.resize(size, Image.Resampling.LANCZOS)
    return np.asarray(m) > 127


def disk_mask(size: tuple[int, int], center: tuple[float, float], radius: float, ss: int = 4) -> np.ndarray:
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    cx, cy = center[0] * ss, center[1] * ss
    r = radius * ss
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    m = m.resize(size, Image.Resampling.LANCZOS)
    return np.asarray(m) > 127


def morph(mask: np.ndarray, close: int = 3, dilate: int = 0) -> np.ndarray:
    m = Image.fromarray((mask * 255).astype(np.uint8))
    if close:
        m = m.filter(ImageFilter.MaxFilter(close)).filter(ImageFilter.MinFilter(close))
    if dilate:
        m = m.filter(ImageFilter.MaxFilter(dilate * 2 + 1))
    return np.asarray(m) > 127


def inpaint(rgb: np.ndarray, mask: np.ndarray, iters: int = 1500, pad: int = 30) -> np.ndarray:
    ys, xs = np.where(mask)
    y0, y1 = max(0, ys.min() - pad), min(rgb.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(rgb.shape[1], xs.max() + pad + 1)
    crop = rgb[y0:y1, x0:x1].astype(np.float32)
    hole = mask[y0:y1, x0:x1]
    out = crop.copy()
    out[hole] = crop[~hole].mean(axis=0)
    for _ in range(iters):
        p = np.pad(out, ((1, 1), (1, 1), (0, 0)), mode="edge")
        avg = (
            p[1:-1, 1:-1] + p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]
        ) / 5.0
        out[hole] = avg[hole]
    result = rgb.copy()
    result[y0:y1, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)
    return result


def bezier(p0, p1, p2, p3, n: int = 160):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append(
            (
                u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1],
            )
        )
    return pts


def tapered_curve(draw, pts, r0, rmid, r1, color):
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        t = i / (n - 1)
        if t < 0.5:
            r = r0 + (rmid - r0) * (t / 0.5)
        else:
            r = rmid + (r1 - rmid) * ((t - 0.5) / 0.5)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def eye_flood_mask(source: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    rgb = source[:, :, :3].astype(np.int16)
    alpha = source[:, :, 3]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    skin_red = (r > 110) & ((r - g) > 75) & ((r - b) > 60)
    allowed = (~skin_red) & (alpha > 40)
    h, w = allowed.shape
    seen = np.zeros((h, w), bool)
    dq = deque([seed])
    seen[seed[1], seed[0]] = True
    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and allowed[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((nx, ny))
    return seen


def build_blink(source_rgba: Image.Image) -> Image.Image:
    src = np.asarray(source_rgba)
    base = morph(eye_flood_mask(src, (342, 480)), close=3) | morph(
        eye_flood_mask(src, (478, 500)), close=3
    )
    expanded = morph(base, close=0, dilate=6)
    feather = np.asarray(
        Image.fromarray((expanded * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
    ).astype(np.float32) / 255.0

    filled = inpaint(src[:, :, :3], expanded)
    filled = np.clip(filled.astype(np.float32) * 1.06, 0, 255).astype(np.uint8)

    overlay = Image.new("RGBA", source_rgba.size, (0, 0, 0, 0))
    skin = Image.fromarray(filled).convert("RGBA")
    skin.putalpha(Image.fromarray((feather * 255).astype(np.uint8)))
    overlay = Image.alpha_composite(overlay, skin)

    left = bezier(*LEFT_LID)
    right = bezier(*RIGHT_LID)

    lid_shadow = Image.new("RGBA", source_rgba.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(lid_shadow)
    for pts in (left, right):
        tapered_curve(sd, [(x, y + 2) for x, y in pts], 10, 13, 9, (100, 0, 0, 70))
    lid_shadow = lid_shadow.filter(ImageFilter.GaussianBlur(6))
    overlay = Image.alpha_composite(overlay, lid_shadow)

    crease = Image.new("RGBA", source_rgba.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(crease)
    for pts in (left, right):
        tapered_curve(cd, [(x, y - 8) for x, y in pts], 1.5, 2.6, 1.5, (110, 0, 0, 45))
    crease = crease.filter(ImageFilter.GaussianBlur(3))
    overlay = Image.alpha_composite(overlay, crease)

    highlight = Image.new("RGBA", source_rgba.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    for pts in (left, right):
        tapered_curve(hd, [(x, y + 5) for x, y in pts], 1.2, 2.2, 1.2, (255, 120, 110, 55))
    highlight = highlight.filter(ImageFilter.GaussianBlur(2))
    overlay = Image.alpha_composite(overlay, highlight)

    d = ImageDraw.Draw(overlay)
    for pts in (left, right):
        tapered_curve(d, pts, 2.0, 3.8, 2.0, (56, 24, 18, 255))
    tapered_curve(
        d,
        bezier(
            (LEFT_LID[0][0], LEFT_LID[0][1]),
            (LEFT_LID[0][0] - 7, LEFT_LID[0][1] - 3),
            (LEFT_LID[0][0] - 11, LEFT_LID[0][1] - 6),
            (LEFT_LID[0][0] - 14, LEFT_LID[0][1] - 8),
            24,
        ),
        3.0, 1.6, 0.4, (56, 24, 18, 255),
    )
    tapered_curve(
        d,
        bezier(
            (RIGHT_LID[3][0], RIGHT_LID[3][1]),
            (RIGHT_LID[3][0] + 7, RIGHT_LID[3][1] - 3),
            (RIGHT_LID[3][0] + 11, RIGHT_LID[3][1] - 6),
            (RIGHT_LID[3][0] + 14, RIGHT_LID[3][1] - 8),
            24,
        ),
        3.0, 1.6, 0.4, (56, 24, 18, 255),
    )
    return overlay


def rotate_premultiplied(image: Image.Image, degrees: float, center: tuple[int, int]) -> Image.Image:
    arr = np.asarray(image).astype(np.float32) / 255.0
    arr[:, :, :3] *= arr[:, :, 3:4]
    rotated = Image.fromarray((arr * 255).astype(np.uint8)).rotate(
        degrees, center=center, resample=Image.Resampling.BICUBIC
    )
    out = np.asarray(rotated).astype(np.float32) / 255.0
    a = out[:, :, 3:4]
    out[:, :, :3] = np.divide(out[:, :, :3], np.maximum(a, 1e-6))
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def downscale(image: Image.Image) -> Image.Image:
    return image.resize((ARTBOARD, ARTBOARD), Image.Resampling.LANCZOS)


def write_debug(background: Image.Image, layers: list[Image.Image], name: str):
    comp = background
    for layer in layers:
        comp = Image.alpha_composite(comp, layer)
    bg = Image.new("RGB", comp.size, (238, 238, 238))
    bg.paste(comp, mask=comp.getchannel("A"))
    bg.save(BUILD / name)


def surrounding_color(rgb: np.ndarray, alpha: np.ndarray, mask: np.ndarray,
                      red_only: bool = False, pad: int = 6) -> np.ndarray:
    """Median colour of the opaque pixels just outside a patch. Used to fill
    the body under a rotating limb with the material it sits on."""
    ring = morph(mask, close=0, dilate=pad) & ~mask & (alpha >= 250)
    if red_only:
        r, g, b = rgb[:, :, 0].astype(np.int16), rgb[:, :, 1].astype(np.int16), rgb[:, :, 2].astype(np.int16)
        ring &= (r > 110) & (g < 90) & (b < 90)
    px = rgb[ring]
    if len(px) == 0:
        return np.array([180, 10, 12], np.uint8)
    return np.median(px, axis=0).astype(np.uint8)


def build_layers():
    ASSETS.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)

    source = Image.open(SRC).convert("RGBA")
    if source.size != (SOURCE_SIZE, SOURCE_SIZE):
        raise SystemExit(f"Unexpected source size: {source.size}")
    src = np.asarray(source)
    alpha = src[:, :, 3]

    jack_mask = polygon_mask(source.size, JACK_ARM_POLY)
    jill_mask = polygon_mask(source.size, JILL_HAND_POLY)
    jack_patch = (
        polygon_mask(source.size, JACK_PATCH_POLY) & jack_mask & (alpha >= 250)
    )
    jill_patch = (
        disk_mask(source.size, JILL_PATCH_CENTER, JILL_PATCH_R) & (alpha >= 250)
    )

    jack_alpha = np.where(jack_mask, alpha, 0)
    jill_alpha = np.where(jill_mask, alpha, 0)

    jack_layer = source.copy()
    jack_layer.putalpha(Image.fromarray(jack_alpha))
    jill_layer = source.copy()
    jill_layer.putalpha(Image.fromarray(jill_alpha))

    # Fill the hidden body under each rotating limb with the surrounding
    # material, so a moving edge reveals red arm/torso instead of a transparent
    # seam. The fills are covered at rest.
    body_rgb = src[:, :, :3].copy()
    body_rgb[jack_patch] = surrounding_color(src[:, :, :3], alpha, jack_mask, red_only=True)
    body_rgb[jill_patch] = surrounding_color(src[:, :, :3], alpha, jill_mask, red_only=True)

    body_alpha = alpha.copy()
    body_alpha[jack_mask] = 0
    body_alpha[jill_mask] = 0
    body_alpha[jack_patch] = 255
    body_alpha[jill_patch] = 255
    body = Image.fromarray(np.dstack([body_rgb, body_alpha]))

    blink = build_blink(source)

    # Debug: rest composite should be pixel-identical to the source inside the
    # character, and the arm peaks should only reveal patched body colour.
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, jack_layer, jill_layer],
        "debug_rest.png",
    )
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, rotate_premultiplied(jack_layer, -3.55, JACK_PIVOT), jill_layer],
        "debug_jack_peak.png",
    )
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, jack_layer, rotate_premultiplied(jill_layer, -4.9, JILL_PIVOT)],
        "debug_jill_peak.png",
    )
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, jack_layer, jill_layer, blink],
        "debug_blink.png",
    )

    rest = Image.alpha_composite(
        Image.alpha_composite(
            Image.alpha_composite(Image.new("RGBA", source.size, (0, 0, 0, 0)), body),
            jack_layer,
        ),
        jill_layer,
    )
    diff = np.abs(
        np.asarray(rest).astype(np.int16)[:, :, :3] - src[:, :, :3].astype(np.int16)
    )
    diff_alpha = np.abs(np.asarray(rest).astype(np.int16)[:, :, 3] - alpha.astype(np.int16))
    changed_mask = (diff.max(axis=2) > 2) | (diff_alpha > 2)
    changed = int(changed_mask.sum())
    print(f"Rest composite changed pixels vs source: {changed}")
    if changed:
        ys, xs = np.where(changed_mask)
        print(
            f"  diff bbox: ({xs.min()}, {ys.min()})-({xs.max()}, {ys.max()})"
        )
    rest.save(BUILD / "debug_rest_rgba.png")
    diff_vis = np.zeros((*changed_mask.shape, 3), np.uint8)
    diff_vis[changed_mask] = (255, 0, 0)
    Image.fromarray(diff_vis).save(BUILD / "debug_rest_diff.png")

    for name, image in (
        ("duo_welcome_body.png", body),
        ("duo_welcome_jack_arm.png", jack_layer),
        ("duo_welcome_jill_hand.png", jill_layer),
        ("duo_welcome_blink.png", blink),
    ):
        out = downscale(image)
        out.save(ASSETS / name, optimize=True)
        print(f"{name}: {out.size[0]}x{out.size[1]}, {(ASSETS / name).stat().st_size // 1024} KB")


def rive_key(frame: int, value: float, interp: str = "cubic") -> str:
    if interp == "linear":
        return f'          <KeyFrameDouble value="{value}" frame="{frame}" interpolationType="linear"/>\n'
    return (
        f'          <KeyFrameDouble value="{value}" frame="{frame}" interpolationType="cubic">\n'
        '            <CubicEaseInterpolator x1="0.42" y1="0" x2="0.58" y2="1"/>\n'
        "          </KeyFrameDouble>\n"
    )


def keyed(out: list[str], object_id: int, prop: int, keys: list[tuple[int, float, str]]):
    merged: dict[int, tuple[int, float, str]] = {}
    for frame, value, interp in keys:
        merged[frame] = (frame, value, interp)
    out.append(f'      <KeyedObject objectId="0:{object_id}">')
    out.append(f'        <KeyedProperty propertyKey="{prop}">')
    for frame in sorted(merged):
        _, value, interp = merged[frame]
        out.append(rive_key(frame, value, interp).rstrip("\n"))
    out.append("        </KeyedProperty>")
    out.append("      </KeyedObject>")


def build_scene() -> str:
    lines: list[str] = ['<Rive version="1" kind="fragment">']
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_body.png" name="duo_welcome_body" id="0:3001"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_jack_arm.png" name="duo_welcome_jack_arm" id="0:3002"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_jill_hand.png" name="duo_welcome_jill_hand" id="0:3003"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_blink.png" name="duo_welcome_blink" id="0:3004"/>'
    )
    lines.append(
        f'  <Artboard width="{ARTBOARD}" height="{ARTBOARD}" name="DuoWelcome" '
        'defaultStateMachineId="0:3020" id="0:3005">'
    )
    lines.append(
        f'    <Node x="{MOTION_PIVOT[0]}" y="{MOTION_PIVOT[1]}" '
        'name="DuoWelcomeMotion" id="0:3010">'
    )
    # RML draw order is front-to-back: the first child paints on top. Put the
    # sparkles, blink, hand and arm in front, and the body at the back.
    jx, jy = JACK_PIVOT[0] - MOTION_PIVOT[0], JACK_PIVOT[1] - MOTION_PIVOT[1]
    jack_node = [
        f'      <Node x="{jx}" y="{jy}" name="JackArmPivot" id="0:3012">',
        f'        <Image x="{-JACK_PIVOT[0]}" y="{-JACK_PIVOT[1]}" originX="0" originY="0" '
        'assetId="0:3002" name="JackArm"/>',
        "      </Node>",
    ]
    ix, iy = JILL_PIVOT[0] - MOTION_PIVOT[0], JILL_PIVOT[1] - MOTION_PIVOT[1]
    jill_node = [
        f'      <Node x="{ix}" y="{iy}" name="JillHandPivot" id="0:3014">',
        f'        <Image x="{-JILL_PIVOT[0]}" y="{-JILL_PIVOT[1]}" originX="0" originY="0" '
        'assetId="0:3003" name="JillHand"/>',
        "      </Node>",
    ]
    blink_node = [
        '      <Node x="0" y="0" name="JackBlink" id="0:3016">',
        f'        <Image x="{-MOTION_PIVOT[0]}" y="{-MOTION_PIVOT[1]}" '
        'originX="0" originY="0" assetId="0:3004" name="JackBlinkImage" id="0:3017"/>',
        "      </Node>",
    ]
    sparkle_nodes: list[str] = []
    for i, (x, y, phase, color) in enumerate(SPARKLES):
        sparkle_nodes.append(
            f'      <Node x="{x - MOTION_PIVOT[0]}" y="{y - MOTION_PIVOT[1]}" '
            f'name="Sparkle{i + 1}" id="0:{3031 + i}">'
        )
        sparkle_nodes.append('        <Shape name="SparkleShape">')
        sparkle_nodes.append(
            '          <Star width="24" height="24" points="4" innerRadius="0.32" '
            'cornerRadius="3" originX="0.5" originY="0.5" name="Path"/>'
        )
        sparkle_nodes.append('          <Fill name="Fill">')
        sparkle_nodes.append(f'            <SolidColor colorValue="{color}" name="Color"/>')
        sparkle_nodes.append("          </Fill>")
        sparkle_nodes.append("        </Shape>")
        sparkle_nodes.append("      </Node>")
    lines.extend(sparkle_nodes)
    lines.extend(blink_node)
    lines.extend(jill_node)
    lines.extend(jack_node)
    lines.append(
        f'      <Image x="{-MOTION_PIVOT[0]}" y="{-MOTION_PIVOT[1]}" '
        'originX="0" originY="0" assetId="0:3001" name="Body"/>'
    )
    lines.append("    </Node>")

    lines.append(
        f'    <LinearAnimation name="Idle" duration="{DURATION}" loopValue="loop" id="0:3022">'
    )
    # Whole-body breath. Absolute y values around the 660 pivot.
    keyed(lines, 3010, 14, [
        (0, 660.0, "cubic"), (48, 655.0, "cubic"), (96, 660.0, "cubic"),
        (144, 657.8, "cubic"), (192, 660.0, "linear"),
    ])
    keyed(lines, 3010, 15, [
        (0, 0.0, "cubic"), (48, 0.0095, "cubic"), (96, 0.0, "cubic"),
        (144, -0.0095, "cubic"), (192, 0.0, "linear"),
    ])
    keyed(lines, 3010, 16, [
        (0, 1.0, "cubic"), (48, 1.006, "cubic"), (96, 1.0, "cubic"),
        (144, 1.0024, "cubic"), (192, 1.0, "linear"),
    ])
    keyed(lines, 3010, 17, [
        (0, 1.0, "cubic"), (48, 1.013, "cubic"), (96, 1.0, "cubic"),
        (144, 1.0052, "cubic"), (192, 1.0, "linear"),
    ])

    # Jack's pan arm: a small stir/lift, then home.
    keyed(lines, 3012, 15, [
        (0, 0.0, "cubic"), (34, 0.0, "cubic"), (62, 0.062, "cubic"),
        (88, 0.0, "cubic"), (192, 0.0, "linear"),
    ])

    # Jill's wrist bob, outward so the phone never crosses her face.
    keyed(lines, 3014, 15, [
        (0, 0.0, "cubic"), (118, 0.0, "cubic"), (138, 0.05, "cubic"),
        (158, 0.0, "cubic"), (192, 0.0, "linear"),
    ])

    # Jack blinks once, quickly, at 1.6-1.8s.
    keyed(lines, 3016, 18, [
        (0, 0.0, "cubic"), (94, 0.0, "cubic"), (98, 1.0, "cubic"),
        (102, 1.0, "cubic"), (106, 0.0, "cubic"), (192, 0.0, "cubic"),
    ])

    for i, (_, _, phase, _) in enumerate(SPARKLES):
        start = round(phase * DURATION)
        appear = start + 8
        fade = start + 36
        object_id = 3031 + i
        keyed(lines, object_id, 18, [
            (0, 0.0, "cubic"), (start, 0.0, "cubic"), (appear, 0.9, "cubic"),
            (fade, 0.0, "cubic"), (DURATION, 0.0, "linear"),
        ])
        keyed(lines, object_id, 16, [
            (0, 0.4, "cubic"), (start, 0.4, "cubic"), (appear, 1.0, "cubic"),
            (fade, 0.4, "cubic"), (DURATION, 0.4, "linear"),
        ])
        keyed(lines, object_id, 17, [
            (0, 0.4, "cubic"), (start, 0.4, "cubic"), (appear, 1.0, "cubic"),
            (fade, 0.4, "cubic"), (DURATION, 0.4, "linear"),
        ])
        keyed(lines, object_id, 15, [
            (0, 0.0, "cubic"), (start, 0.0, "cubic"), (appear, 0.3, "cubic"),
            (fade, 0.5, "cubic"), (DURATION, 0.5, "linear"),
        ])

    lines.append("    </LinearAnimation>")
    lines.append('    <StateMachine name="Idle" id="0:3020">')
    lines.append('      <StateMachineLayer name="Layer 1" id="0:3021">')
    lines.append('        <AnyState x="-200" y="-120"/>')
    lines.append('        <ExitState x="400" y="-120"/>')
    lines.append("        <EntryState>")
    lines.append('          <StateTransition stateToId="0:3023"/>')
    lines.append("        </EntryState>")
    lines.append(
        '        <AnimationState x="0" animationId="0:3022" id="0:3023"/>'
    )
    lines.append("      </StateMachineLayer>")
    lines.append("    </StateMachine>")
    lines.append("  </Artboard>")
    lines.append("</Rive>")
    return "\n".join(lines) + "\n"


def main():
    build_layers()
    (HERE / "scene.rml").write_text(build_scene(), encoding="utf-8")
    (HERE / "rive.yaml").write_text(
        "name: duo_welcome_layered\nmain: DuoWelcome\n", encoding="utf-8"
    )
    print(f"Wrote {HERE / 'scene.rml'}")


if __name__ == "__main__":
    main()
