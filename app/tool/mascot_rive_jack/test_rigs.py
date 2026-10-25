"""Focused regression tests for the isolated Jack/Jill workshops."""
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image

from audit_rig import check_tracks

HERE = Path(__file__).resolve().parent


class RigTests(unittest.TestCase):
    def test_accessory_depth_on_every_artboard(self):
        for rig, head_name, accessories in (("jack", "Head", ("hat", "stem")), ("jill", "head", ("stem",))):
            scene = ET.parse(HERE.with_name(f"mascot_rive_{rig}") / "scene.rml").getroot()
            boards = list(scene.iter("Artboard"))
            self.assertEqual(len(boards), 5)
            for board in boards:
                with self.subTest(rig=rig, board=board.attrib["name"]):
                    head = next(n for n in board.iter("Node") if n.attrib.get("name") == head_name)
                    names = [n.attrib.get("name") for n in head]
                    self.assertLess(names.index("blink"), names.index("face_think"))
                    for accessory in accessories:
                        for face in ("face_think", "face_idea", "face_write", "face_smile", "blink"):
                            self.assertLess(names.index(face), names.index(accessory))

    def test_source_tracks_loop_with_matching_velocity(self):
        for rig in ("jack", "jill"):
            with self.subTest(rig=rig):
                self.assertGreater(check_tracks(HERE.with_name(f"mascot_rive_{rig}") / "scene.rml"), 30)

    def test_binary_size_and_runtime_results(self):
        for rig, name in (("jack", "jack_wingman"), ("jill", "jill_wingwoman")):
            build = HERE.with_name(f"mascot_rive_{rig}") / "build"
            with self.subTest(rig=rig):
                size = (build / f"{name}.riv").stat().st_size
                self.assertGreater(size, 0)
                self.assertLess(size, 4_000_000)
                report = json.loads((build / "qa.json").read_text(encoding="utf-8"))
                self.assertEqual(len(report["artboards"]), 5)
                for board in report["artboards"].values():
                    self.assertLessEqual(board["seam_max_channel"], 3)

    def test_non_green_parts_have_no_green_alpha_rim(self):
        for rig in ("jack", "jill"):
            assets = HERE.with_name(f"mascot_rive_{rig}") / "assets"
            for path in assets.glob("*.png"):
                if path.stem.endswith("_stem"):
                    continue
                with self.subTest(asset=path.name):
                    pixels = np.asarray(Image.open(path).convert("RGBA"), dtype=np.int16)
                    self.assertGreater(int(pixels[..., 3].max()), 250)
                    edge = (pixels[..., 3] > 0) & (pixels[..., 3] < 230)
                    lead = pixels[..., 1] - np.maximum(pixels[..., 0], pixels[..., 2])
                    self.assertFalse(np.any(edge & (lead > 5)), path.name)


if __name__ == "__main__":
    unittest.main()
