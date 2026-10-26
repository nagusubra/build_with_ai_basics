"""Generate Android launcher icons from the iOS app icon.

Legacy `mipmap-*/ic_launcher.png` (padded square), `ic_launcher_round.png`
(circular) and adaptive-icon foregrounds (`ic_launcher_foreground.png`) are
rebuilt from `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`.

Run from `app/`: `python tool/app_icons.py`
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-App-1024x1024@1x.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"

# dp sizes per density; legacy launcher icons are 48dp, adaptive foregrounds 108dp.
DPI = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
LEGACY_DP = 48.0
FOREGROUND_DP = 108.0
SAFE_SCALE = 0.58  # content share of the 108dp canvas (mask-safe zone is ~2/3)


def main() -> None:
    src = Image.open(SOURCE).convert("RGBA")
    assert src.size == (1024, 1024), src.size
    background = src.getpixel((8, 8))[:3]

    manifest = (RES / ".." / "AndroidManifest.xml").resolve()
    text = manifest.read_text(encoding="utf-8")
    if "android:roundIcon" not in text:
        text = text.replace('android:icon="@mipmap/ic_launcher"',
                            'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"')
        manifest.write_text(text, encoding="utf-8")
        print("manifest: added android:roundIcon")

    values = RES / "values" / "values.xml"
    if not values.exists():
        values.write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
            '</resources>\n' % background,
            encoding="utf-8",
        )
        print("values.xml: adaptive background color #%02X%02X%02X" % background)

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )

    for dpi, scale in DPI.items():
        folder = RES / f"mipmap-{dpi}"
        folder.mkdir(exist_ok=True)
        legacy_px = round(LEGACY_DP * scale)

        padded = Image.new("RGBA", (1024, 1024), background + (255,))
        padded.alpha_composite(src.resize((round(1024 * 0.8),) * 2, Image.LANCZOS),
                               (round(1024 * 0.1), round(1024 * 0.1)))

        padded.resize((legacy_px, legacy_px), Image.LANCZOS).save(folder / "ic_launcher.png")

        mask = Image.new("L", (legacy_px, legacy_px), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, legacy_px - 1, legacy_px - 1), fill=255)
        round_icon = padded.resize((legacy_px, legacy_px), Image.LANCZOS)
        round_icon.putalpha(mask)
        round_icon.save(folder / "ic_launcher_round.png")

        fg_px = round(FOREGROUND_DP * scale)
        fg = Image.new("RGBA", (fg_px, fg_px), (0, 0, 0, 0))
        content = round(int(fg_px * SAFE_SCALE))
        fg.alpha_composite(src.resize((content, content), Image.LANCZOS),
                           ((fg_px - content) // 2, (fg_px - content) // 2))
        fg.save(folder / "ic_launcher_foreground.png")
        print(f"mipmap-{dpi}: ic_launcher {legacy_px}px, round, foreground {fg_px}px")

    icons = sorted(p.name for p in RES.rglob("*.png"))
    expected = {"ic_launcher.png", "ic_launcher_round.png", "ic_launcher_foreground.png"}
    counts = {name: icons.count(name) for name in expected}
    missing = [f"{n} ({c})" for n, c in counts.items() if c != len(DPI)]
    assert not missing, f"missing: {missing}"
    print(f"OK: {len(icons)} icon files")


if __name__ == "__main__":
    main()
