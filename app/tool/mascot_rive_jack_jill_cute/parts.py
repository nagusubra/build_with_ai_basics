"""Jack rig part tools: chroma-key Gemini renders and register them onto the master canvas.

Every raw render in design/mascots/jack_rig/raw/ is a flat-green-background image. This module turns them
into clean transparent RGBA layers that live in the master's 1024x1024 coordinate space, so every part
lines up with every other part without hand-placement.
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter

GREEN_HI = 150  # greenness (g - max(r, b)) at or above which a pixel is pure background
GREEN_LO = 70   # greenness at or below which a pixel is fully opaque
GREEN_LO_RIM = 40  # near the silhouette, green lead at which a pixel becomes fully transparent


def load(path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def key(rgb: np.ndarray, keep_green: float = 0.0) -> np.ndarray:
    """Return float RGBA in 0..255. `keep_green` lets genuinely green parts (leaf/stem) keep that much green lead."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    gdom = g - np.maximum(r, b)
    a = np.clip((GREEN_HI - gdom) / (GREEN_HI - GREEN_LO), 0.0, 1.0)
    # Drop isolated speckles with a small morphological open on the matte.
    am = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    a = np.minimum(a, np.asarray(am, np.float32) / 255.0 + (a >= 0.999))
    if not keep_green:
        # Gemini's renders carry a green-lit rim a few px wide that keys as opaque. Within that band only
        # (interior green details like the apron cherry stems stay), treat any green lead as background.
        near = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9))) < 255
        a = np.where(near, np.minimum(a, np.clip((GREEN_LO_RIM - gdom) / GREEN_LO_RIM, 0.0, 1.0)), a)
    # Unmix the background out of soft edges (c = a*fg + (1-a)*bg), then pull the edge in slightly so no
    # green-tinted rim survives against dark or light UI backgrounds.
    bg = np.median(rgb[a <= 0.0], axis=0) if (a <= 0.0).any() else np.array([0.0, 255.0, 0.0])
    soft = (a > 0) & (a < 1)
    out = rgb.copy()
    out[soft] = np.clip((rgb[soft] - (1 - a[soft, None]) * bg) / np.maximum(a[soft, None], 0.2), 0, 255)
    a = np.clip((a - 0.12) / 0.88, 0.0, 1.0)
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    # Despill: limit how far green can lead red/blue, harder on soft edges.
    lead = keep_green * a
    out[..., 1] = np.minimum(g, np.maximum(r, b) + lead)
    return np.dstack([out, a * 255.0])


def bbox(alpha: np.ndarray, thr: float = 8.0):
    ys, xs = np.nonzero(alpha > thr)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def warp(rgba: np.ndarray, scale: float, dx: float, dy: float, size=(1024, 1024)) -> np.ndarray:
    """Place `rgba` into master space: master = scale * src + (dx, dy). Premultiplied resample."""
    pm = rgba.copy()
    pm[..., :3] *= pm[..., 3:4] / 255.0
    im = Image.fromarray(np.clip(pm, 0, 255).astype(np.uint8), "RGBA")
    inv = (1 / scale, 0, -dx / scale, 0, 1 / scale, -dy / scale)
    w = np.asarray(im.transform(size, Image.AFFINE, inv, resample=Image.BICUBIC), np.float32)
    a = w[..., 3:4]
    w[..., :3] = np.where(a > 0, w[..., :3] * 255.0 / np.maximum(a, 1e-3), 0)
    return w


def _ncc(a: np.ndarray, b: np.ndarray) -> float:
    a = a - a.mean()
    b = b - b.mean()
    return float((a * b).sum() / (np.sqrt((a * a).sum() * (b * b).sum()) + 1e-6))


def register(src_rgb: np.ndarray, master_rgb: np.ndarray, box, scales=(1.0,), center=(0.0, 0.0), search=30, step=3):
    """Find (score, scale, dx, dy) with master = scale * src + (dx, dy), by NCC over master `box`.

    Coarse grid over `scales` x (center +- search), then a sub-pixel refinement around the best hit.
    """
    x0, y0, x1, y1 = box
    ref = master_rgb[y0:y1, x0:x1].mean(axis=2)
    src = Image.fromarray(src_rgb.mean(axis=2).astype(np.float32), "F")

    def score(s, dx, dy):
        inv = (1 / s, 0, (x0 - dx) / s, 0, 1 / s, (y0 - dy) / s)
        return _ncc(ref, np.asarray(src.transform((x1 - x0, y1 - y0), Image.AFFINE, inv, resample=Image.BILINEAR)))

    best = (-2.0, 1.0, 0.0, 0.0)
    for s in scales:
        cx, cy = center(s) if callable(center) else center
        for dy in range(-search, search + 1, step):
            for dx in range(-search, search + 1, step):
                c = score(s, cx + dx, cy + dy)
                if c > best[0]:
                    best = (c, s, cx + dx, cy + dy)
    _, s0, dx0, dy0 = best
    ds = 0.01 if len(scales) > 1 else 0.0
    for s in np.arange(s0 - ds, s0 + ds + 1e-9, 0.002) if ds else [s0]:
        for dy in np.arange(dy0 - step, dy0 + step + 1e-9, 0.5):
            for dx in np.arange(dx0 - step, dx0 + step + 1e-9, 0.5):
                c = score(s, dx, dy)
                if c > best[0]:
                    best = (c, float(s), float(dx), float(dy))
    return best


def save(rgba: np.ndarray, path, crop=True):
    """Save an RGBA layer; returns (x, y, w, h) of the saved crop in master space."""
    a = rgba[..., 3]
    if crop:
        x0, y0, x1, y1 = bbox(a, 1.0)
        x0, y0 = max(0, x0 - 2), max(0, y0 - 2)
        x1, y1 = min(rgba.shape[1], x1 + 2), min(rgba.shape[0], y1 + 2)
    else:
        x0, y0, x1, y1 = 0, 0, rgba.shape[1], rgba.shape[0]
    out = rgba[y0:y1, x0:x1].copy()
    out[..., :3] = np.where(out[..., 3:4] > 0, out[..., :3], 0)
    Image.fromarray(np.clip(out, 0, 255).round().astype(np.uint8), "RGBA").save(path, optimize=True)
    return x0, y0, x1 - x0, y1 - y0
