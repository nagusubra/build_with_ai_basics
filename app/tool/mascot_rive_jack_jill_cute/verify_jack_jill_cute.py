"""Capture real Rive renders of Jack and check the rig: python app\\tool\\mascot_rive_jack\\verify_jack.py [--quick]

Writes build/review.png (story beats of the wingman loop + each segment artboard), build/preview.webp/gif of the
full 8 s loop, and checks the loop seam renders identically.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build_jack_jill_cute import ARTBOARDS, BUILD, HERE, LOOP, REPO

RIVE = shutil.which("rive") or str(Path.home() / ".rive" / "bin" / "rive.exe")
YAML = HERE / "rive.yaml"


def run(*args):
    r = subprocess.run([RIVE, str(HERE), *args], cwd=REPO, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f"rive {' '.join(args)} failed\n{r.stdout}\n{r.stderr}")
    return r.stderr + r.stdout


def capture(path: Path, frame: int, scale=1.0) -> Image.Image:
    # The first advance enters the state machine; it does not move the timeline.
    run(f"--screenshot={path}", f"--advance={frame + 1}", f"--scale={scale}")
    with Image.open(path) as im:
        return im.convert("RGBA")


def on_cream(im: Image.Image) -> Image.Image:
    bg = Image.new("RGBA", im.size, "#FFF9F3")
    bg.alpha_composite(im)
    return bg.convert("RGB")


def main():
    quick = "--quick" in sys.argv
    BUILD.mkdir(exist_ok=True)
    out = run("--verify")
    assert "0 errors" in out and "0 warnings" in out, out
    run("--once")
    riv = BUILD / "jack_jill_cute.riv"
    print(f"PASS: verify clean, {riv.stat().st_size:,} bytes")

    beats = [("think", 50), ("dots", 100), ("idea pop", 137), ("idea", 180), ("write", 250), ("scribble", 320),
             ("heart", 360), ("smile hop", 386), ("smile", 420), ("return", 462)]
    shots = [(n, on_cream(capture(BUILD / f"beat_{f:03}.png", f))) for n, f in beats]

    seam = capture(BUILD / "seam.png", LOOP)
    rest = capture(BUILD / "rest.png", 0)
    diff = int(np.abs(np.asarray(seam, int) - np.asarray(rest, int)).max())
    assert diff <= 3, f"loop seam differs by {diff}"
    print(f"PASS: loop seam max channel diff {diff}")

    original = YAML.read_text(encoding="utf-8")
    segs = []
    try:
        for name, *_ in ARTBOARDS[1:]:
            YAML.write_text(f"name: jack_jill_cute\nmain: {name}\n", encoding="utf-8")
            for f in (0, 40):
                segs.append((f"{name} f{f}", on_cream(capture(BUILD / f"seg_{name}_{f}.png", f))))
    finally:
        YAML.write_text(original, encoding="utf-8")

    w, h = shots[0][1].size
    tw, th = w // 2, h // 2
    cols = 5
    rows = (len(shots) + cols - 1) // cols + (len(segs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + 10) + 10, rows * (th + 30) + 10), "#FFF0F2")
    d = ImageDraw.Draw(sheet)
    for i, (n, im) in enumerate(shots + [None] * (-len(shots) % cols) + segs):
        if im is None:
            continue
        x, y = 10 + (i % cols) * (tw + 10), 10 + (i // cols) * (th + 30)
        sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y + 20))
        d.text((x, y + 4), n, fill="#A71938")
    sheet.save(BUILD / "review.png")
    print("PASS: wrote build/review.png")

    if quick:
        return
    with tempfile.TemporaryDirectory(dir=BUILD) as tmp:
        frames = [on_cream(capture(Path(tmp) / f"{f:03}.png", f, 0.5)) for f in range(0, LOOP, 2)]
    frames[0].save(BUILD / "preview.webp", save_all=True, append_images=frames[1:], duration=33, loop=0, quality=88)
    frames[0].save(BUILD / "preview.gif", save_all=True, append_images=frames[1:], duration=33, loop=0)
    # A 120 px chat-header strip shows how it reads at the real size.
    strip = Image.new("RGB", (len(beats) * 130, 140), "#FFF9F3")
    for i, (_, im) in enumerate(shots):
        strip.paste(im.resize((round(120 * w / h), 120), Image.LANCZOS), (i * 130 + 5, 10))
    strip.save(BUILD / "chat_size.png")
    print("PASS: wrote preview.webp, preview.gif, chat_size.png")


if __name__ == "__main__":
    main()
