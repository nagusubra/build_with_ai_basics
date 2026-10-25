"""Runtime and source QA shared by the Jack and Jill animation workshops."""
from __future__ import annotations

import json
import math
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

RIVE = shutil.which("rive") or str(Path.home() / ".rive" / "bin" / "rive.exe")


def check_tracks(scene: Path) -> int:
    """Check endpoint values and C1 seam tangents on continuous transform tracks."""
    checked = 0
    for animation in ET.parse(scene).getroot().iter("LinearAnimation"):
        duration = int(animation.attrib["duration"])
        for prop in animation.iter("KeyedProperty"):
            keys = list(prop)
            first, last = keys[0], keys[-1]
            assert int(first.attrib["frame"]) == 0
            assert int(last.attrib["frame"]) == duration
            assert math.isclose(float(first.attrib["value"]), float(last.attrib["value"]), abs_tol=1e-6)
            if prop.attrib["propertyKey"] not in ("13", "14", "15", "16", "17"):
                continue
            # Generated flow tracks use thirds for x handles. Discrete FX/pose tracks do not.
            curves = [k.find("CubicEaseInterpolator") for k in keys[:-1]]
            if not all(c is not None and abs(float(c.attrib["x1"]) - 1 / 3) < 1e-5
                       and abs(float(c.attrib["x2"]) - 2 / 3) < 1e-5 for c in curves):
                continue
            def slope(i, outgoing):
                a, b = keys[i], keys[i + 1]
                c = curves[i]
                delta = (float(b.attrib["value"]) - float(a.attrib["value"])) / (
                    int(b.attrib["frame"]) - int(a.attrib["frame"]))
                return delta * (float(c.attrib["y1"]) / float(c.attrib["x1"]) if outgoing else
                                (1 - float(c.attrib["y2"])) / (1 - float(c.attrib["x2"])))
            assert math.isclose(slope(0, True), slope(len(keys) - 2, False), abs_tol=2e-5), (
                animation.attrib["name"], prop.attrib, "velocity discontinuity")
            checked += 1
    return checked


def audit(here: Path, artboards, output_name: str, quick=False):
    build = here / "build"
    build.mkdir(exist_ok=True)
    yaml = here / "rive.yaml"
    original = yaml.read_text(encoding="utf-8")
    captures = {}
    report = {"continuous_tracks": check_tracks(here / "scene.rml"), "artboards": {}}

    def run(*args):
        result = subprocess.run([RIVE, str(here), *args], capture_output=True, text=True)
        logs = result.stdout + result.stderr
        if result.returncode or "0 errors" not in logs or "0 warnings" not in logs:
            raise RuntimeError(f"Rive command failed: {args}\n{logs}")
        return logs

    def capture(board, frame, scale=0.5):
        key = (board, frame, scale)
        if key not in captures:
            path = build / f"audit_{board}_{frame}_{scale}.png"
            run(f"--screenshot={path}", f"--advance={frame + 1}", f"--scale={scale}")
            with Image.open(path) as image:
                captures[key] = image.convert("RGBA")
        return captures[key]

    shots = []
    try:
        run("--verify")
        run("--once")
        size = (build / f"{output_name}.riv").stat().st_size
        assert 0 < size < 4_000_000, size
        report["bytes"] = size
        for index, (name, base, pose, factory) in enumerate(artboards):
            duration = factory(base).duration
            yaml.write_text(f"name: {output_name}\nmain: {name}\n", encoding="utf-8")
            first = np.asarray(capture(name, 0), dtype=np.int16)
            last = np.asarray(capture(name, duration), dtype=np.int16)
            prev = np.asarray(capture(name, duration - 1), dtype=np.int16)
            after = np.asarray(capture(name, 1), dtype=np.int16)
            seam = int(np.abs(first - last).max())
            acceleration = float(np.abs((after - first) - (first - prev)).mean())
            assert seam <= 3, (name, seam)
            # Acceleration is diagnostic: a fast squash can accelerate sharply
            # despite matching seam velocity, which check_tracks tests directly.
            frames = [40, 70, 73, 76, 96, 99, 102] if index else [
                50, 70, 73, 76, 125, 126, 127, 137, 180, 215, 216, 217,
                250, 300, 303, 306, 320, 360, 371, 372, 373, 386, 420, 449, 450, 451, 462]
            frames = sorted(set([0] + [f for f in frames if f < duration]))
            for frame in frames:
                shots.append((f"{name} f{frame}", capture(name, frame)))
            report["artboards"][name] = {
                "frames": duration, "seam_max_channel": seam,
                "seam_acceleration_mean": round(acceleration, 6), "reviewed_frames": frames,
            }
            print(f"PASS: {name} seam={seam}, raster seam acceleration={acceleration:.6f}", flush=True)
        if not quick:
            name, base, _, factory = artboards[0]
            yaml.write_text(f"name: {output_name}\nmain: {name}\n", encoding="utf-8")
            frames = [capture(name, f) for f in range(0, factory(base).duration, 4)]
            frames[0].save(build / "preview.webp", save_all=True, append_images=frames[1:],
                           duration=1000 / 15, loop=0, quality=90)
    finally:
        yaml.write_text(original, encoding="utf-8")
        # Segment captures compile their selected main; restore the deliverable as well as the config.
        run("--once")

    w, h = shots[0][1].size
    cols = 6
    sheet = Image.new("RGB", (cols * (w + 10) + 10, math.ceil(len(shots) / cols) * (h + 30) + 10), "#FFF0F2")
    draw = ImageDraw.Draw(sheet)
    for i, (label, image) in enumerate(shots):
        x, y = 10 + i % cols * (w + 10), 10 + i // cols * (h + 30)
        sheet.paste(image.convert("RGB"), (x, y + 20))
        draw.text((x, y), label, fill="#A71938")
    sheet.save(build / "audit.png")
    beats = [(label, image) for label, image in shots if label.split()[0] == artboards[0][0]
             and int(label.split(" f")[1]) in (0, 50, 137, 180, 250, 320, 360, 386, 420, 462)]
    review = Image.new("RGB", (5 * (w + 10) + 10, 2 * (h + 30) + 10), "#FFF0F2")
    draw = ImageDraw.Draw(review)
    for i, (label, image) in enumerate(beats):
        x, y = 10 + i % 5 * (w + 10), 10 + i // 5 * (h + 30)
        review.paste(image.convert("RGB"), (x, y + 20))
        draw.text((x, y), label, fill="#A71938")
    review.save(build / "review.png")
    strip_shots = shots[::max(1, len(shots) // 10)][:10]
    strip = Image.new("RGB", (130 * len(strip_shots), 155), "#FFF9F3")
    draw = ImageDraw.Draw(strip)
    for i, (label, image) in enumerate(strip_shots):
        image = image.copy()
        image.thumbnail((120, 120), Image.Resampling.LANCZOS)
        strip.paste(image.convert("RGB"), (i * 130 + 5, 25))
        draw.text((i * 130 + 5, 5), label, fill="#A71938")
    strip.save(build / "chat_size.png")
    (build / "qa.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {report['bytes']:,} bytes, {report['continuous_tracks']} C1 transform tracks; config restored")


if __name__ == "__main__":
    import sys
    from build_jack import ARTBOARDS, HERE
    audit(HERE, ARTBOARDS, "jack_wingman", "--quick" in sys.argv)
