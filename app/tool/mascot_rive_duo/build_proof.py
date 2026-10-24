"""Build the isolated layered DuoWelcome proof.

This is a one-off art/proof pipeline, not part of the Flutter app. It reads the
1024x1024 transparent cutout in design/mascots, extracts the body, two head
layers, Jack's arm, Jill's hand and two blink overlays, writes 768px assets and
scene.rml, and leaves the shipped seven-pose asset alone.

Jill's source art is a permanent wink. This pipeline removes the wink, then
composites Gemini-painted eyes and brows (design/mascots/jill_eyes_gemini) so
both eyes look left at Jack, and uses Gemini's matching half, nearly-closed
and closed eyelids for her blink. Both characters blink together.
The phone tap
is replaced by a gentle head bump: each head pivots at its stem attachment, so
the heart stems stay connected while the cheeks lean together.

Run from the repo root:
    python app/tool/mascot_rive_duo/build_proof.py
"""

from __future__ import annotations

import math
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

# Source-space pivots (scaled when writing RML). Each
# cut is a disk centred on its pivot, so rotating the layer cannot open a gap
# at the joint: a disk is invariant under rotation about its own centre.
JACK_PIVOT = (305, 580)
JACK_DISK_R = 24
JILL_PIVOT = (895, 635)
JILL_DISK_R = 30
MOTION_PIVOT = (384, 660)

# Head pivots sit at the stem attachment points. Rotating a head around the
# stem keeps the heart stems attached while the chin swings toward the other
# head. The head cut-outs stop above the clothes; the neck patches underneath
# keep the reveal red when the heads lean.
JACK_HEAD_PIVOT = (422, 360)
JILL_HEAD_PIVOT = (690, 360)
JACK_HEAD_ELLIPSE = ((378, 450), 230, 185)
JACK_HAT_ELLIPSE = ((270, 280), 130, 100)
JILL_HEAD_ELLIPSE = ((730, 440), 195, 190)
JILL_BOW_ELLIPSE = ((810, 330), 120, 110)
JACK_NECK_ELLIPSE = ((380, 570), 130, 65)
JILL_NECK_ELLIPSE = ((730, 570), 130, 65)

# Jill's wink lives around x=655; her open eye is mirrored across the face.
JILL_FACE_MID_X = 750.0
JILL_GAZE_OFFSET_X = -136
JILL_OPEN_EYE_BOX = (766, 400, 878, 540)
JILL_WINK_BOX = (600, 492, 712, 558)
JILL_BROW_BOX = (605, 425, 716, 482)

# Gemini edited a 768px render of this source crop; its 1024px outputs map
# back onto the same box. Feature ellipses are in that 1024px space.
JILL_AI_DIR = REPO / "design" / "mascots" / "jill_eyes_gemini"
JILL_AI_BOX = (545, 300, 929, 684)
JILL_AI_EYES = (((340, 515), 160, 140), ((742, 520), 135, 138))
JILL_AI_BROWS = (((340, 345), 140, 60), ((725, 340), 125, 60))
JILL_AI_BLINK = ("half", "nearly", "nearly")
JILL_MOUTH_BOX = (715, 552, 778, 590)


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
JACK_PROP_POLY = [
    (0, 335), (145, 335), (184, 390), (184, 480), (176, 520),
    (188, 548), (211, 560), (220, 590), (240, 630), (220, 660),
    (170, 650), (130, 620), (0, 595),
]

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
    [(908, 460), (944, 462), (982, 478), (992, 496),
     (984, 525), (982, 550), (980, 575), (978, 600), (980, 620), (974, 638),
     (962, 650), (945, 655), (925, 644)]
    + arc_points(895, 635, JILL_DISK_R, 18, 180, 18)
    + [(866, 620), (867, 600), (874, 578), (883, 548), (892, 518), (901, 488)]
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
JACK_LIDS = (
    (LEFT_LID, ((301, 499), (297, 407), (367, 406), (383, 505)),
     ((301, 499), (320, 531), (369, 542), (383, 505))),
    (RIGHT_LID, ((444, 521), (438, 442), (508, 432), (514, 526)),
     ((444, 521), (460, 546), (500, 548), (514, 526))),
)


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


def ellipse_mask(size: tuple[int, int], center: tuple[float, float],
                 rx: float, ry: float, ss: int = 4) -> np.ndarray:
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    cx, cy = center[0] * ss, center[1] * ss
    ImageDraw.Draw(m).ellipse(
        [cx - rx * ss, cy - ry * ss, cx + rx * ss, cy + ry * ss], fill=255
    )
    m = m.resize(size, Image.Resampling.LANCZOS)
    return np.asarray(m) > 127


def morph(mask: np.ndarray, close: int = 3, dilate: int = 0) -> np.ndarray:
    m = Image.fromarray((mask * 255).astype(np.uint8))
    if close:
        m = m.filter(ImageFilter.MaxFilter(close)).filter(ImageFilter.MinFilter(close))
    if dilate:
        m = m.filter(ImageFilter.MaxFilter(dilate * 2 + 1))
    return np.asarray(m) > 127


def erode_mask(mask: np.ndarray, px: int) -> np.ndarray:
    if px <= 0:
        return mask
    m = Image.fromarray((mask * 255).astype(np.uint8)).filter(
        ImageFilter.MinFilter(px * 2 + 1)
    )
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


def connected_mask(allowed: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    if not allowed[seed[1], seed[0]]:
        raise ValueError(f"Flood seed {seed} is outside the allowed region")
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


def eye_flood_mask(source: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    rgb = source[:, :, :3].astype(np.int16)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    skin_red = (r > 110) & ((r - g) > 75) & ((r - b) > 60)
    return connected_mask((~skin_red) & (source[:, :, 3] > 40), seed)


def build_jack_blink(source_rgba: Image.Image) -> tuple[Image.Image, Image.Image]:
    src = np.asarray(source_rgba)
    base = morph(eye_flood_mask(src, (342, 480)), close=3) | morph(
        eye_flood_mask(src, (478, 500)), close=3
    )
    expanded = morph(base, close=0, dilate=10)
    feather = np.asarray(
        Image.fromarray((expanded * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(4))
    ).astype(np.float32) / 255.0

    filled = inpaint(src[:, :, :3], expanded, iters=2400)

    overlay = Image.new("RGBA", source_rgba.size, (0, 0, 0, 0))
    skin = Image.fromarray(filled).convert("RGBA")
    skin.putalpha(Image.fromarray((feather * 255).astype(np.uint8)))
    overlay = Image.alpha_composite(overlay, skin)
    skin_plate = overlay.copy()

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
    return overlay, skin_plate


def open_jill_eye(source_rgba: Image.Image) -> Image.Image:
    """Replace Jill's permanent wink with an open eye looking toward Jack.

    Only the dark marks (wink lash + thin brow) are erased and only the eye
    and brow pixels are pasted back, so the left cheek keeps its own shading
    and specular highlight instead of a mirrored patch of the brighter side.
    """
    src = np.asarray(source_rgba)
    rgb = src[:, :, :3].copy()
    alpha = src[:, :, 3]

    in_box = np.zeros(alpha.shape, dtype=bool)
    for bx0, by0, bx1, by1 in (JILL_BROW_BOX, JILL_WINK_BOX):
        in_box[by0:by1, bx0:bx1] = True
    smooth = Image.fromarray(rgb).filter(ImageFilter.GaussianBlur(16))
    lum = rgb.mean(axis=2)
    skin_lum = np.asarray(smooth).astype(np.float32).mean(axis=2)
    dark = in_box & (lum < skin_lum * 0.82)
    erase = morph(dark, close=3, dilate=5)
    erase |= ellipse_mask(source_rgba.size, (654, 457), 43, 24)
    # The wink's low-contrast crease survives a darkness-only selection.
    erase |= polygon_mask(source_rgba.size, [
        (608, 503), (622, 484), (649, 482), (680, 488),
        (711, 508), (715, 532), (682, 543), (640, 544), (612, 534),
    ])
    filled = inpaint(rgb, erase, iters=2400, pad=24).astype(np.float32)

    x0, y0, x1, y1 = JILL_OPEN_EYE_BOX
    patch = src[y0:y1, x0:x1][:, ::-1]
    mx0 = int(round(2 * JILL_FACE_MID_X - x1))
    ph, pw = patch.shape[:2]

    # Keep the entire connected eye, including its warm iris edge. Selecting
    # all "non-red" pixels individually punches holes in the brown lower iris.
    iris = polygon_mask(source_rgba.size, [
        (780, 480), (787, 464), (798, 458), (812, 462),
        (820, 477), (823, 499), (819, 520), (807, 530),
        (793, 531), (783, 523), (779, 507),
    ])
    eye = eye_flood_mask(src, (820, 490)) | iris
    brow_region = polygon_mask(source_rgba.size, [
        (783, 431), (787, 421), (800, 414), (813, 413),
        (827, 417), (839, 425), (847, 435), (847, 438),
        (838, 431), (824, 425), (811, 422), (799, 424), (788, 429),
    ])
    brow = brow_region & (rgb[:, :, 0] < 185)
    for row in range(407, 441):
        columns = np.flatnonzero(brow[row])
        if columns.size:
            brow[row, columns[0]:columns[-1] + 1] = True
    yy, xx = np.indices(alpha.shape)
    outer_lashes = eye & (xx >= 832) & (yy < 476)
    feature = (
        morph(outer_lashes, close=3, dilate=2) | morph(brow, close=3)
    )[y0:y1, x0:x1][:, ::-1]

    feather = Image.fromarray((feature * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(1.2)
    )
    fm = np.asarray(feather).astype(np.float32)[:, :, None] / 255.0

    dst = filled[y0:y0 + ph, mx0:mx0 + pw]
    f = fm * patch[:, :, 3:4].astype(np.float32) / 255.0
    pr, pg, pb = (patch[:, :, i].astype(np.float32) for i in range(3))
    iris_patch = iris[y0:y1, x0:x1][:, ::-1]
    donor_skin = inpaint(rgb, morph(eye | brow, close=3, dilate=5), iters=2400)
    donor_skin = donor_skin[y0:y1, x0:x1][:, ::-1].astype(np.float32)
    # Match only the red skin fringe to its destination lighting. Preserve the
    # continuous iris and brow detail rather than cutting by colour again.
    skin_weight = np.minimum(
        np.clip((pr - pg - 45) / 40, 0, 1),
        np.clip((pr - pb - 45) / 40, 0, 1),
    ) * np.clip((pr - 100) / 60, 0, 1)
    skin_weight[iris_patch] = 0
    skin_weight[brow[y0:y1, x0:x1][:, ::-1]] = 0
    corrected = patch[:, :, :3].astype(np.float32) + (
        dst - donor_skin
    ) * skin_weight[:, :, None]
    filled[y0:y0 + ph, mx0:mx0 + pw] = (
        dst * (1 - f) + np.clip(corrected, 0, 255) * f
    )
    filled = direct_jill_gaze(filled, src, iris, eye)

    return Image.fromarray(
        np.dstack([np.clip(filled, 0, 255).astype(np.uint8), alpha])
    )


def direct_jill_gaze(
    rgb: np.ndarray, source: np.ndarray, iris: np.ndarray,
    eye: np.ndarray,
) -> np.ndarray:
    """Keep mirrored outer lashes, but aim the eye left instead of cross-eyed."""
    y0, y1, x0, x1 = 440, 540, 772, 866
    donor = source[y0:y1, x0:x1, :3].astype(np.float32)
    red, green, blue = (source[:, :, i].astype(int) for i in range(3))
    eye_region = np.zeros(iris.shape, dtype=bool)
    eye_region[444:536, 775:862] = True
    sclera = connected_mask(
        eye_region & (red > 185) & (green > 140) & (blue > 100), (840, 490),
    )
    # Follow the actual eyeball, then retain a narrow dark lid rim. A loose
    # polygon also copies the stumps of the original outward-facing lashes.
    eye_without_lashes = morph(sclera | iris, close=5, dilate=3)
    matte = eye_without_lashes[y0:y1, x0:x1]
    donor_skin = inpaint(
        source[:, :, :3], morph(eye, close=3, dilate=5), iters=2400,
    )[y0:y1, x0:x1].astype(np.float32)
    target_x0 = x0 + JILL_GAZE_OFFSET_X
    target = rgb[y0:y1, target_x0:target_x0 + x1 - x0]
    r, g, b = donor[:, :, 0], donor[:, :, 1], donor[:, :, 2]
    skin_weight = np.minimum(
        np.clip((r - g - 45) / 40, 0, 1), np.clip((r - b - 45) / 40, 0, 1),
    ) * np.clip((r - 100) / 60, 0, 1)
    skin_weight[iris[y0:y1, x0:x1]] = 0
    corrected = np.clip(donor + (target - donor_skin) * skin_weight[:, :, None], 0, 255)
    opacity = np.asarray(
        Image.fromarray((matte * 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(1.0))
    ).astype(np.float32)[:, :, None] / 255
    rgb[y0:y1, target_x0:target_x0 + x1 - x0] = (
        target * (1 - opacity) + corrected * opacity
    )
    return rgb


def blur_float(values: np.ndarray, sigma: float) -> np.ndarray:
    radius = int(3 * sigma)
    kernel = np.exp(-0.5 * (np.arange(-radius, radius + 1) / sigma) ** 2)
    kernel /= kernel.sum()
    out = values.astype(np.float32)
    for axis in (0, 1):
        out = np.apply_along_axis(np.convolve, axis, out, kernel, mode="same")
    return out


def gemini_jill_layer(
    base_rgba: Image.Image, name: str, include_brows: bool,
) -> Image.Image:
    """Map one Gemini eye frame back onto Jill as a feathered RGBA overlay.

    Gemini repaints the whole crop, so only the eye (and optionally brow)
    ellipses are kept. Its slight lighting drift is measured in a ring just
    outside those features and removed, so the overlay has no visible seam.
    """
    x0, y0, x1, y1 = JILL_AI_BOX
    size = x1 - x0
    scale = size / 1024
    art = Image.open(JILL_AI_DIR / f"{name}.jpg").convert("RGB")
    if art.size != (1024, 1024):
        raise RuntimeError(f"Unexpected Gemini frame size for {name}: {art.size}")
    art = np.asarray(
        art.resize((size, size), Image.Resampling.LANCZOS)
    ).astype(np.float32)
    base = np.asarray(base_rgba)[y0:y1, x0:x1].astype(np.float32)

    mask = np.zeros((size, size), dtype=bool)
    for (cx, cy), rx, ry in JILL_AI_EYES + (JILL_AI_BROWS if include_brows else ()):
        mask |= ellipse_mask((size, size), (cx * scale, cy * scale), rx * scale, ry * scale)
    ring = (morph(mask, close=0, dilate=12) & ~mask & (base[:, :, 3] > 250)).astype(np.float32)
    delta = (art - base[:, :, :3]) * ring[:, :, None]
    mean_delta = delta.sum(axis=(0, 1)) / max(ring.sum(), 1)
    weight = blur_float(ring, 18)[:, :, None]
    drift = np.dstack([blur_float(delta[:, :, i], 18) for i in range(3)])
    drift = (drift + 1e-3 * mean_delta) / (weight + 1e-3)
    corrected = np.clip(art - drift, 0, 255)

    feather = blur_float(mask.astype(np.float32), 1.6)
    out = np.zeros((SOURCE_SIZE, SOURCE_SIZE, 4), np.uint8)
    out[y0:y1, x0:x1, :3] = corrected.astype(np.uint8)
    out[y0:y1, x0:x1, 3] = np.clip(feather * base[:, :, 3], 0, 255).astype(np.uint8)
    return Image.fromarray(out)


def blink_inbetweens(skin: Image.Image, lids: tuple) -> list[Image.Image]:
    """Reveal Jack's unchanged eyes through narrowing curved apertures."""
    frames = []
    for amount in (0.25, 0.55, 0.82):
        overlay = skin.copy()
        aperture = Image.new("L", skin.size, 0)
        aperture_draw = ImageDraw.Draw(aperture)
        curves = []
        for closed, top, bottom in lids:
            top_curve = tuple(
                (x * (1 - amount) + cx * amount, y * (1 - amount) + cy * amount)
                for (x, y), (cx, cy) in zip(top, closed)
            )
            bottom_curve = tuple(
                (x * (1 - amount) + cx * amount, y * (1 - amount) + cy * amount)
                for (x, y), (cx, cy) in zip(bottom, closed)
            )
            pts = bezier(*top_curve)
            aperture_draw.polygon(pts + bezier(*bottom_curve)[::-1], fill=255)
            curves.append(pts)
        aperture = aperture.filter(ImageFilter.GaussianBlur(0.65))
        alpha = np.asarray(overlay.getchannel("A")).astype(np.float32)
        alpha *= 1 - np.asarray(aperture).astype(np.float32) / 255
        overlay.putalpha(Image.fromarray(alpha.astype(np.uint8)))
        draw = ImageDraw.Draw(overlay)
        for side, pts in enumerate(curves):
            tapered_curve(draw, pts, 1.5, 2.8, 1.5, (56, 24, 18, 255))
            end = pts[0] if side == 0 else pts[-1]
            direction = -1 if side == 0 else 1
            start = end
            tapered_curve(draw, bezier(
                start, (start[0] + direction * 5, start[1] - 1),
                (start[0] + direction * 9, start[1] - 4),
                (start[0] + direction * 9, start[1] - 8),
            ), 2.0, 1.4, 0.3, (56, 24, 18, 255))
        frames.append(overlay)
    return frames


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


def stem_mask(src: np.ndarray) -> np.ndarray:
    r, g, b, a = (src[:, :, i].astype(np.int16) for i in range(4))
    olive = (a > 40) & (g > 80) & (b < 160) & (g > b + 25) & (r > b + 25)
    region = np.zeros(olive.shape, bool)
    region[80:380, 385:450] = True
    region[80:380, 650:750] = True
    return morph(olive & region, close=0, dilate=2)


def build_layers():
    ASSETS.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)

    source = Image.open(SRC).convert("RGBA")
    if source.size != (SOURCE_SIZE, SOURCE_SIZE):
        raise SystemExit(f"Unexpected source size: {source.size}")
    src = np.asarray(source)
    alpha = src[:, :, 3]

    jack_mask = (
        polygon_mask(source.size, JACK_ARM_POLY)
        | polygon_mask(source.size, JACK_PROP_POLY)
    )
    jack_mask = morph(jack_mask, close=0, dilate=4)
    jill_mask = polygon_mask(source.size, JILL_HAND_POLY)
    jack_patch = (
        polygon_mask(source.size, JACK_PATCH_POLY) & jack_mask & (alpha == 255)
    )
    jill_patch = (
        disk_mask(source.size, JILL_PATCH_CENTER, JILL_PATCH_R) & jill_mask & (alpha == 255)
    )

    jack_alpha = np.where(jack_mask, alpha, 0)
    jill_alpha = np.where(jill_mask, alpha, 0)

    jack_layer = source.copy()
    jack_layer.putalpha(Image.fromarray(jack_alpha))
    jill_layer = source.copy()
    jill_layer.putalpha(Image.fromarray(jill_alpha))

    # Head cut-outs. The stem and clothes stay in the body; the neck patches
    # below keep a red reveal when the heads lean.
    stem = stem_mask(src)
    jack_head_region = (
        ellipse_mask(source.size, *JACK_HEAD_ELLIPSE)
        | ellipse_mask(source.size, *JACK_HAT_ELLIPSE)
    )
    jill_head_region = (
        ellipse_mask(source.size, *JILL_HEAD_ELLIPSE)
        | ellipse_mask(source.size, *JILL_BOW_ELLIPSE)
    )
    yy, xx = np.indices(alpha.shape)
    # Split the touching heads at a midline, and keep the arm/hand in their own
    # layers so a head bump cannot drag a phone or pan along with it.
    jack_head_mask = (
        jack_head_region & (alpha > 0) & ~stem & ~jack_mask & (xx <= 562)
    )
    jill_head_mask = (
        jill_head_region & (alpha > 0) & ~stem & ~jill_mask & (xx > 562)
    )
    jack_head_mask |= (
        disk_mask(source.size, JACK_PIVOT, JACK_DISK_R + 12)
        & jack_head_region & (alpha >= 254) & (yy < 606)
    )
    jack_neck = ellipse_mask(source.size, *JACK_NECK_ELLIPSE) & jack_head_mask
    jill_neck = ellipse_mask(source.size, *JILL_NECK_ELLIPSE) & jill_head_mask
    # Only retain interior neck overlap, never the exterior head silhouette.
    # A stationary silhouette rim becomes a second outline as soon as it moves.
    neck_patch = (jack_neck | jill_neck) & (yy >= 594) & erode_mask(alpha >= 254, 14)

    wink_removed = open_jill_eye(source)
    # Clip the repaint to the opaque head interior so every repainted pixel
    # moves with the head and the antialiased silhouette stays untouched.
    open_overlay = np.asarray(gemini_jill_layer(wink_removed, "open", True)).copy()
    open_overlay[~(jill_head_mask & erode_mask(alpha >= 254, 2)), 3] = 0
    open_source = Image.alpha_composite(wink_removed, Image.fromarray(open_overlay))
    open_arr = np.asarray(open_source)
    # Both pupils sit left of their bright sclera, toward Jack.
    for pupil, sclera in (((665, 500), (697, 497)), ((795, 500), (838, 492))):
        if not (
            open_arr[pupil[1], pupil[0], :3].mean() < 90
            and open_arr[sclera[1], sclera[0], :3].mean() > 180
        ):
            raise RuntimeError("Jill's pupils must sit left of the white sclera, toward Jack")

    jack_head = source.copy()
    jack_head.putalpha(Image.fromarray(np.where(jack_head_mask, alpha, 0)))
    jill_head = open_source.copy()
    jill_head.putalpha(Image.fromarray(np.where(jill_head_mask, alpha, 0)))

    # Fill the hidden body under each rotating limb/head with the surrounding
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
    body_alpha[jack_head_mask | jill_head_mask] = 0
    body_alpha[neck_patch] = 255
    body = Image.fromarray(np.dstack([body_rgb, body_alpha]))

    jack_blink, jack_skin = build_jack_blink(source)
    jill_blink = gemini_jill_layer(open_source, "closed", False)
    blink_stages = [
        *[(f"duo_welcome_jack_blink_{i}.png", image)
          for i, image in enumerate(blink_inbetweens(jack_skin, JACK_LIDS), 1)],
        *[(f"duo_welcome_jill_blink_{i}.png", gemini_jill_layer(open_source, name, False))
          for i, name in enumerate(JILL_AI_BLINK, 1)],
    ]

    # Rest composite: body, heads, arm, hand (back to front).
    rest = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for layer in (body, jack_head, jill_head, jack_layer, jill_layer):
        rest = Image.alpha_composite(rest, layer)

    rest_arr = np.asarray(rest)
    diff = np.abs(rest_arr.astype(np.int16)[:, :, :3] - open_arr.astype(np.int16)[:, :, :3])
    diff_alpha = np.abs(rest_arr.astype(np.int16)[:, :, 3] - open_arr.astype(np.int16)[:, :, 3])
    changed_mask = (diff.max(axis=2) > 2) | (diff_alpha > 2)
    changed = int(changed_mask.sum())
    print(f"Rest composite changed pixels vs open-eye source: {changed}")
    if changed:
        ys, xs = np.where(changed_mask)
        raise RuntimeError(
            f"Layer extraction changed {changed} rest pixels: "
            f"({xs.min()}, {ys.min()})-({xs.max()}, {ys.max()})"
        )

    open_diff = np.abs(open_arr.astype(np.int16)[:, :, :3] - src[:, :, :3].astype(np.int16))
    open_changed = (open_diff.max(axis=2) > 2) | (
        np.abs(open_arr.astype(np.int16)[:, :, 3] - alpha.astype(np.int16)) > 2
    )
    print(f"Jill open-eye change vs source: {int(open_changed.sum())} pixels")
    mx0, my0, mx1, my1 = JILL_MOUTH_BOX
    if open_changed[my0:my1, mx0:mx1].any():
        raise RuntimeError("Jill's eye repair intrudes into her mouth")
    if open_changed.any():
        ys, xs = np.where(open_changed)
        print(f"  bbox: ({xs.min()}, {ys.min()})-({xs.max()}, {ys.max()})")

    # Debug: rest, head-bump peak, both blinks, Jill's opened eye.
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, jack_head, jill_head, jack_layer, jill_layer],
        "debug_rest.png",
    )
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [
            body,
            rotate_premultiplied(jack_head, math.degrees(0.024), JACK_HEAD_PIVOT),
            rotate_premultiplied(jill_head, -math.degrees(0.024), JILL_HEAD_PIVOT),
            jack_layer,
            jill_layer,
        ],
        "debug_bump_peak.png",
    )
    write_debug(
        Image.new("RGBA", source.size, (0, 0, 0, 0)),
        [body, jack_head, jill_head, jack_layer, jill_layer, jack_blink, jill_blink],
        "debug_blink.png",
    )
    Image.fromarray(open_arr[430:560, 590:900]).save(BUILD / "debug_jill_open_crop.png")
    rest.save(BUILD / "debug_rest_rgba.png")
    diff_vis = np.zeros((*changed_mask.shape, 3), np.uint8)
    diff_vis[changed_mask] = (255, 0, 0)
    Image.fromarray(diff_vis).save(BUILD / "debug_rest_diff.png")

    for name, image in (
        ("duo_welcome_body.png", body),
        ("duo_welcome_jack_arm.png", jack_layer),
        ("duo_welcome_jill_hand.png", jill_layer),
        ("duo_welcome_jack_head.png", jack_head),
        ("duo_welcome_jill_head.png", jill_head),
        ("duo_welcome_jack_blink.png", jack_blink),
        ("duo_welcome_jill_blink.png", jill_blink),
        *blink_stages,
    ):
        out = downscale(image)
        out.save(ASSETS / name, optimize=True)
        print(f"{name}: {out.size[0]}x{out.size[1]}, {(ASSETS / name).stat().st_size // 1024} KB")

    (ASSETS / "duo_welcome_blink.png").unlink(missing_ok=True)


def rive_key(frame: int, value: float, interp: str = "cubic") -> str:
    if interp in ("linear", "hold"):
        return f'          <KeyFrameDouble value="{value}" frame="{frame}" interpolationType="{interp}"/>\n'
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
    frames = sorted(merged)
    slopes = [0.0] * len(frames)
    if all(interp == "flow" for _, _, interp in keys):
        for i in range(len(frames) - 1):
            previous = i - 1 if i else len(frames) - 2
            before = (merged[frames[i]][1] - merged[frames[previous]][1]) / (
                frames[i] - frames[previous] if i else frames[-1] - frames[previous]
            )
            after = (merged[frames[i + 1]][1] - merged[frames[i]][1]) / (
                frames[i + 1] - frames[i]
            )
            if before * after > 0:
                slopes[i] = 2 * before * after / (before + after)
        slopes[-1] = slopes[0]
    for i, frame in enumerate(frames):
        _, value, interp = merged[frame]
        if interp == "flow" and i + 1 < len(frames):
            dt = frames[i + 1] - frame
            dv = merged[frames[i + 1]][1] - value
            y1 = slopes[i] * dt / (3 * dv) if dv else 0
            y2 = 1 - slopes[i + 1] * dt / (3 * dv) if dv else 1
            out.append(
                f'          <KeyFrameDouble value="{value}" frame="{frame}" interpolationType="cubic">'
                f'<CubicEaseInterpolator x1="{1 / 3}" y1="{y1}" '
                f'x2="{2 / 3}" y2="{y2}"/></KeyFrameDouble>'
            )
        else:
            out.append(rive_key(frame, value, "linear" if interp == "flow" else interp).rstrip("\n"))
    out.append("        </KeyedProperty>")
    out.append("      </KeyedObject>")


def build_scene() -> str:
    ratio = ARTBOARD / SOURCE_SIZE
    jack_pivot = tuple(v * ratio for v in JACK_PIVOT)
    jill_pivot = tuple(v * ratio for v in JILL_PIVOT)
    jack_head_pivot = tuple(v * ratio for v in JACK_HEAD_PIVOT)
    jill_head_pivot = tuple(v * ratio for v in JILL_HEAD_PIVOT)
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
        '  <ImageAsset file="assets/duo_welcome_jack_blink.png" name="duo_welcome_jack_blink" id="0:3004"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_jack_head.png" name="duo_welcome_jack_head" id="0:3006"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_jill_head.png" name="duo_welcome_jill_head" id="0:3007"/>'
    )
    lines.append(
        '  <ImageAsset file="assets/duo_welcome_jill_blink.png" name="duo_welcome_jill_blink" id="0:3008"/>'
    )
    for character, offset in (("jack", 0), ("jill", 3)):
        for stage in range(1, 4):
            lines.append(
                f'  <ImageAsset file="assets/duo_welcome_{character}_blink_{stage}.png" '
                f'name="{character}_blink_{stage}" id="0:{3100 + offset + stage}"/>'
            )
    lines.append(
        f'  <Artboard width="{ARTBOARD}" height="{ARTBOARD}" name="DuoWelcome" '
        'defaultStateMachineId="0:3020" id="0:3005">'
    )
    lines.append(
        f'    <Node x="{MOTION_PIVOT[0]}" y="{MOTION_PIVOT[1]}" '
        'name="DuoWelcomeMotion" id="0:3010">'
    )
    # RML draw order is front-to-back: the first child paints on top. Sparkles,
    # hand and arm sit in front of the heads, and the body is at the back.
    sparkle_nodes: list[str] = []
    for i, (x, y, phase, color) in enumerate(SPARKLES):
        sparkle_nodes.append(
            f'      <Node x="{x - MOTION_PIVOT[0]}" y="{y - MOTION_PIVOT[1]}" '
            f'opacity="0" scaleX="0.4" scaleY="0.4" '
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

    lines.append(
        '      <Node x="30" y="-455" opacity="0" name="NuzzleHeart" id="0:3040">'
    )
    lines.append('        <Shape name="Heart">')
    lines.append('          <PointsPath isClosed="true" name="HeartPath">')
    for point, incoming, outgoing in (
        ((0, -6), (7, -16), (-7, -16)),
        ((-14, -7), (-14, -19), (-14, 2)),
        ((0, 13), (-4, 10), (4, 10)),
        ((14, -7), (14, 2), (14, -19)),
    ):
        ix, iy = incoming[0] - point[0], incoming[1] - point[1]
        ox, oy = outgoing[0] - point[0], outgoing[1] - point[1]
        lines.append(
            f'            <CubicDetachedVertex x="{point[0]}" y="{point[1]}" '
            f'inRotation="{math.atan2(iy, ix)}" inDistance="{math.hypot(ix, iy)}" '
            f'outRotation="{math.atan2(oy, ox)}" outDistance="{math.hypot(ox, oy)}"/>'
        )
    lines.append('          </PointsPath>')
    lines.append('          <Fill name="Rose"><SolidColor colorValue="FFFF8FA3"/></Fill>')
    lines.append('        </Shape>')
    lines.append('      </Node>')

    ix, iy = jill_pivot[0] - MOTION_PIVOT[0], jill_pivot[1] - MOTION_PIVOT[1]
    lines.append(f'      <Node x="{ix}" y="{iy}" name="JillHandPivot" id="0:3014">')
    lines.append(
        f'        <Image x="{-jill_pivot[0]}" y="{-jill_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3003" name="JillHand"/>'
    )
    lines.append("      </Node>")

    jx, jy = jack_pivot[0] - MOTION_PIVOT[0], jack_pivot[1] - MOTION_PIVOT[1]
    lines.append(f'      <Node x="{jx}" y="{jy}" name="JackArmPivot" id="0:3012">')
    lines.append(
        f'        <Image x="{-jack_pivot[0]}" y="{-jack_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3002" name="JackArm"/>'
    )
    lines.append("      </Node>")

    hx, hy = jack_head_pivot[0] - MOTION_PIVOT[0], jack_head_pivot[1] - MOTION_PIVOT[1]
    lines.append(f'      <Node x="{hx}" y="{hy}" name="JackHeadPivot" id="0:3016">')
    for stage in range(1, 4):
        lines.append(
            f'        <Image x="{-jack_head_pivot[0]}" y="{-jack_head_pivot[1]}" '
            f'originX="0" originY="0" assetId="0:{3100 + stage}" opacity="0" '
            f'name="JackBlink{stage}" id="0:{3110 + stage}"/>'
        )
    lines.append(
        f'        <Image x="{-jack_head_pivot[0]}" y="{-jack_head_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3004" opacity="0" name="JackBlink" id="0:3017"/>'
    )
    lines.append(
        f'        <Image x="{-jack_head_pivot[0]}" y="{-jack_head_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3006" name="JackHead"/>'
    )
    lines.append("      </Node>")

    hx, hy = jill_head_pivot[0] - MOTION_PIVOT[0], jill_head_pivot[1] - MOTION_PIVOT[1]
    lines.append(f'      <Node x="{hx}" y="{hy}" name="JillHeadPivot" id="0:3018">')
    for stage in range(1, 4):
        lines.append(
            f'        <Image x="{-jill_head_pivot[0]}" y="{-jill_head_pivot[1]}" '
            f'originX="0" originY="0" assetId="0:{3103 + stage}" opacity="0" '
            f'name="JillBlink{stage}" id="0:{3113 + stage}"/>'
        )
    lines.append(
        f'        <Image x="{-jill_head_pivot[0]}" y="{-jill_head_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3008" opacity="0" name="JillBlink" id="0:3019"/>'
    )
    lines.append(
        f'        <Image x="{-jill_head_pivot[0]}" y="{-jill_head_pivot[1]}" originX="0" originY="0" '
        'assetId="0:3007" name="JillHead"/>'
    )
    lines.append("      </Node>")

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
        (0, 0.0, "flow"), (48, 0.008, "flow"), (96, 0.0, "flow"),
        (144, -0.008, "flow"), (192, 0.0, "flow"),
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
        (0, 0.0, "flow"), (26, 0.0, "flow"), (62, 0.052, "flow"),
        (92, 0.0, "flow"), (192, 0.0, "flow"),
    ])

    # A small anticipation, shared nuzzle, then a slower overlapping settle.
    keyed(lines, 3016, 15, [
        (0, 0.0, "flow"), (72, 0.0, "flow"), (82, 0.003, "flow"),
        (101, -0.024, "flow"), (111, -0.021, "flow"),
        (140, 0.0015, "flow"), (160, 0.0, "flow"), (192, 0.0, "flow"),
    ])
    keyed(lines, 3018, 15, [
        (0, 0.0, "flow"), (74, 0.0, "flow"), (84, -0.0025, "flow"),
        (103, 0.024, "flow"), (113, 0.021, "flow"),
        (144, -0.0015, "flow"), (164, 0.0, "flow"), (192, 0.0, "flow"),
    ])

    # Opaque aperture poses close quickly and reopen more slowly. Never
    # dissolve the eyes: that makes pupils ghost through the painted skin.
    for object_id in (3017, 3019):
        keyed(lines, object_id, 18, [
            (0, 0.0, "hold"), (97, 1.0, "hold"),
            (103, 0.0, "hold"), (192, 0.0, "hold"),
        ])
    for offset in (0, 3):
        for stage, close_start, close_end, open_start, open_end in (
            (1, 94, 95, 107, 109), (2, 95, 96, 105, 107), (3, 96, 97, 103, 105),
        ):
            keyed(lines, 3110 + offset + stage, 18, [
                (0, 0.0, "hold"), (close_start, 1.0, "hold"), (close_end, 0.0, "hold"),
                (open_start, 1.0, "hold"), (open_end, 0.0, "hold"), (192, 0.0, "hold"),
            ])

    keyed(lines, 3040, 18, [
        (0, 0.0, "cubic"), (91, 0.0, "cubic"), (101, 0.9, "cubic"),
        (114, 0.85, "cubic"), (142, 0.0, "cubic"), (192, 0.0, "linear"),
    ])
    for prop in (16, 17):
        keyed(lines, 3040, prop, [
            (0, 0.55, "cubic"), (91, 0.55, "cubic"), (103, 1.12, "cubic"),
            (115, 1.0, "cubic"), (142, 0.8, "cubic"), (192, 0.55, "linear"),
        ])
    keyed(lines, 3040, 14, [
        (0, -455.0, "cubic"), (91, -455.0, "cubic"),
        (142, -481.0, "cubic"), (192, -455.0, "linear"),
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
            (fade, 0.5, "cubic"), (DURATION, 0.0, "linear"),
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
