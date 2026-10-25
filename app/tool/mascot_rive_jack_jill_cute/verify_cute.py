"""Validate and capture the actual Rive proof, not a simulated Pillow animation.

Run from any directory after build_proof.py:
    python app\\tool\\mascot_rive_duo\\verify_proof.py
"""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build_cute import (
    ARTBOARD, ASSETS, BUILD, DURATION, HERE, JACK_HEAD_PIVOT, JACK_PIVOT,
    JILL_HEAD_PIVOT, JILL_PIVOT, MOTION_PIVOT, REPO, SOURCE_SIZE,
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def validate_scene() -> None:
    scene = ET.parse(HERE / "scene.rml").getroot()
    ratio = ARTBOARD / SOURCE_SIZE
    for name, pivot in (
        ("JackArmPivot", JACK_PIVOT), ("JillHandPivot", JILL_PIVOT),
        ("JackHeadPivot", JACK_HEAD_PIVOT), ("JillHeadPivot", JILL_HEAD_PIVOT),
    ):
        node = scene.find(f".//Node[@name='{name}']")
        if node is None:
            raise RuntimeError(f"Missing {name}")
        image = node.find("Image")
        if image is None:
            raise RuntimeError(f"Missing image in {name}")
        for axis, coordinate, parent in zip(("x", "y"), pivot, MOTION_PIVOT):
            require(
                float(node.attrib[axis]) == coordinate * ratio - parent
                and float(image.attrib[axis]) == -coordinate * ratio,
                f"{name}: {axis} pivot is not in artboard coordinates",
            )

    animation = scene.find(".//LinearAnimation")
    if animation is None:
        raise RuntimeError("Missing Idle animation")
    require(int(animation.attrib["duration"]) == DURATION, "Unexpected duration")
    tracks: dict[tuple[str, str], list[tuple[int, float]]] = {}
    for obj in animation.findall("KeyedObject"):
        for prop in obj.findall("KeyedProperty"):
            key = (obj.attrib["objectId"], prop.attrib["propertyKey"])
            require(key not in tracks, f"Duplicate animation track: {key}")
            keys = [
                (int(k.attrib["frame"]), float(k.attrib["value"]))
                for k in prop.findall("KeyFrameDouble")
            ]
            require(keys[0][0] == 0 and keys[-1][0] == DURATION, f"Incomplete {key}")
            require(keys[0][1] == keys[-1][1], f"Loop discontinuity: {key}")
            require(
                all(a[0] < b[0] for a, b in zip(keys, keys[1:])),
                f"Unordered keyframes: {key}",
            )
            tracks[key] = keys
    require(tracks[("0:3017", "18")] == tracks[("0:3019", "18")], "Blinks out of sync")
    for name in ("JackBlink", "JillBlink"):
        blink = scene.find(f".//Image[@name='{name}']")
        require(blink is not None and blink.attrib.get("opacity") == "0", f"{name} flashes at rest")
    for obj in animation.findall("KeyedObject"):
        blink_ids = (3017, 3019, 3111, 3112, 3113, 3114, 3115, 3116)
        if obj.attrib["objectId"] in {f"0:{i}" for i in blink_ids}:
            require(
                all(k.attrib["interpolationType"] == "hold" for k in obj.findall(".//KeyFrameDouble")),
                "Blink opacity must never dissolve between open and closed eyes",
            )
        prop = obj.find("KeyedProperty")
        if prop is None:
            raise RuntimeError("Keyed object has no property")
        if (obj.attrib["objectId"], prop.attrib["propertyKey"]) in (
            ("0:3010", "15"), ("0:3012", "15"), ("0:3016", "15"), ("0:3018", "15"),
        ):
            keys = obj.findall(".//KeyFrameDouble")
            slopes = []
            for a, b in zip(keys, keys[1:]):
                curve = a.find("CubicEaseInterpolator")
                if curve is None:
                    raise RuntimeError("Flow track is missing its cubic handles")
                speed = (float(b.attrib["value"]) - float(a.attrib["value"])) / (
                    int(b.attrib["frame"]) - int(a.attrib["frame"])
                )
                slopes.append((
                    speed * float(curve.attrib["y1"]) / float(curve.attrib["x1"]),
                    speed * (1 - float(curve.attrib["y2"])) / (1 - float(curve.attrib["x2"])),
                ))
            for before, after in zip(slopes, slopes[1:] + slopes[:1]):
                require(abs(before[1] - after[0]) < 1e-10, "Velocity discontinuity in flow track")
    for offset in range(1, 4):
        require(
            tracks[(f"0:{3110 + offset}", "18")] == tracks[(f"0:{3113 + offset}", "18")],
            "Intermediate blink poses are out of sync",
        )
    for frame in range(DURATION):
        for character in ((3017, 3111, 3112, 3113), (3019, 3114, 3115, 3116)):
            visible = 0
            for object_id in character:
                keys = tracks[(f"0:{object_id}", "18")]
                value = next(value for time, value in reversed(keys) if time <= frame)
                require(value in (0.0, 1.0), "Translucent blink pose")
                visible += int(value)
            require(visible <= 1, "Overlapping blink poses")
    for asset in scene.findall("ImageAsset"):
        with Image.open(HERE / asset.attrib["file"]) as image:
            require(image.size == (ARTBOARD, ARTBOARD), "Unexpected layer size")
            require(image.mode == "RGBA", "Layer lost transparency")

    with Image.open(ASSETS / "jack_jill_cute_body.png") as image:
        body = np.asarray(image)
    require(int(body[170:235, 150:245, 3].max()) == 0, "Stationary chef-hat ghost")
    require(int(body[240:475, :130, 3].max()) <= 3, "Stationary pan/glove ghost")
    with Image.open(ASSETS / "jack_jill_cute_jill_hand.png") as image:
        hand = np.asarray(image)
    require(int(hand[398, 705, 3]) == 255, "Jill's phone is missing from its layer")
    require(int(hand[390, 656, 3]) == 0, "Jill's cheek was cut into the phone layer")
    print(
        f"PASS: scaled pivots, {len(tracks)} seamless tracks, continuous motion velocity, "
        "non-overlapping synchronized blink poses, RGBA layers"
    )


def main() -> None:
    raise RuntimeError("Rive CLI not installed")
    BUILD.mkdir(parents=True, exist_ok=True)
    validate_scene()

    def run(*args: str) -> None:
        result = subprocess.run(
            [rive, str(HERE), *args], cwd=REPO, capture_output=True, text=True,
        )
        require(
            result.returncode == 0,
            f"Rive failed: {' '.join(args)}\n{result.stdout}\n{result.stderr}",
        )

    # Keep verification output visible, including the error/warning counts.
    subprocess.run([rive, str(HERE), "--verify"], cwd=REPO, check=True)
    run("--once")
    size = (BUILD / "jack_jill_cute_layered.riv").stat().st_size
    require(0 < size < 4_000_000, f"Proof exceeds 4 MB: {size}")

    def capture(path: Path, frame: int, scale: float = 1.0) -> Image.Image:
        # The first tick enters the animation state; it does not advance Idle.
        run(f"--screenshot={path}", f"--advance={frame + 1}", f"--scale={scale}")
        with Image.open(path) as image:
            expected = round(ARTBOARD * scale)
            require(image.size == (expected, expected), f"Incorrect capture dimensions: {image.size}")
            return image.convert("RGB")

    poses = (("rest", 0), ("arm", 62), ("blink", 98), ("bump", 100), ("settle", 130))
    full = []
    small = []
    for name, frame in poses:
        full.append(capture(BUILD / f"{name}.png", frame))
        small.append(capture(BUILD / f"app_{name}.png", frame, 290 / ARTBOARD))

    with tempfile.TemporaryDirectory(prefix="capture_", dir=BUILD) as temporary:
        temp = Path(temporary)
        loop = capture(temp / "loop.png", DURATION)
        loop_diff = np.abs(np.asarray(full[0]).astype(int) - np.asarray(loop).astype(int))
        # Accumulated runtime float transforms differ from the unadvanced pose
        # by subpixel raster rounding; no channel may change more than 3/255.
        require(int(loop_diff.max()) <= 3, f"Rendered loop seam: {loop_diff.max()}")
        print(f"PASS: rendered loop matches rest (maximum channel difference {loop_diff.max()})")
        # WebP retains every 60fps runtime pose; GIF uses 50fps because browser
        # GIF players commonly clamp 10ms durations, slowing a nominal 60fps GIF.
        frames = [
            capture(temp / f"{frame:03}.png", frame, 0.75)
            for frame in range(DURATION)
        ]
        frames[0].save(
            BUILD / "preview.webp", save_all=True, append_images=frames[1:],
            duration=[17, 17, 16] * (DURATION // 3), loop=0, quality=92, method=4,
        )
        gif_frames = [frames[round(i * 60 / 50)] for i in range(DURATION * 50 // 60)]
        gif_frames[0].save(
            BUILD / "preview.gif", save_all=True, append_images=gif_frames[1:],
            duration=20, loop=0, disposal=2,
        )
        for frame in (93, 94, 95, 96, 97, 100, 102, 103, 104, 105, 106, 107, 108, 109, 112, 150, 189):
            capture(BUILD / f"review_{frame:03}.png", frame)
        eye_sheet = Image.new("RGB", (880, 540), "#fff8f4")
        for i, image in enumerate((full[0], full[2])):
            eye_sheet.paste(
                image.crop((440, 290, 660, 425)).resize((440, 270), Image.Resampling.LANCZOS),
                (i * 440, 0),
            )
        for i, frame in enumerate((95, 96, 104, 106)):
            with Image.open(BUILD / f"review_{frame:03}.png") as image:
                eye_sheet.paste(image.crop((440, 290, 660, 425)).resize((220, 135)), (i * 220, 320))
        eye_sheet.save(BUILD / "eye_review.png")

    sheet = Image.new("RGB", (1450, 710), "#fff8f4")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 18), "DUO WELCOME  /  Actual Rive renders  /  3.2 second loop", fill="#643744")
    for i, ((name, frame), image, app_image) in enumerate(zip(poses, full, small)):
        draw.text((i * 290 + 16, 52), f"{name.upper()}  |  {frame / 60:.2f}s", fill="#643744")
        sheet.paste(image.resize((280, 280), Image.Resampling.LANCZOS), (i * 290 + 5, 80))
        draw.text((i * 290 + 16, 375), "Welcome size: 290 px", fill="#643744")
        sheet.paste(app_image, (i * 290, 395))
    sheet.save(BUILD / "review.png")
    print(f"PASS: {size:,}-byte Rive; full-size and 290px captures; 60fps WebP and 50fps GIF")


if __name__ == "__main__":
    main()
