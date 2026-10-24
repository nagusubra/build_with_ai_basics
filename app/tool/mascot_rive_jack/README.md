# Jack wingman Rive rig

Code-authored Rive animation of Jack (the boy chef cherry), built from image-model parts in
[`design/mascots/jack_rig/`](../../../design/mascots/jack_rig/README.md). The full method is in
[`docs/mascot-animation-pipeline.md`](../../../docs/mascot-animation-pipeline.md). To make a new animation,
follow [`docs/new-mascot-animation-playbook.md`](../../../docs/new-mascot-animation-playbook.md).

## Artboards

| Artboard | Frames @ 60 fps | Use |
|---|---|---|
| `JackWingman` | 480 (8 s) | Chat header for a guy's profile: think → idea → write → smile → loop |
| `JackThink` | 150 | Loading / "Jack is thinking" |
| `JackIdea` | 120 | Suggestions, tips, "I've got an idea" |
| `JackWrite` | 180 | Composing, planning, notes |
| `JackSmile` | 120 | Success, sent, matched |

Each artboard has one looping state machine with the same name.

## Commands (from the repo root)

```powershell
python app\tool\mascot_rive_jack\build_jack.py            # raw renders -> parts -> assets -> scene.rml
python app\tool\mascot_rive_jack\verify_jack.py --quick   # rive verify + build + captures + review.png
python app\tool\mascot_rive_jack\verify_jack.py           # ...plus preview.webp/.gif and chat_size.png
.\app\tool\preview_mascot_jack.ps1                        # live preview in the browser
.\app\tool\preview_mascot_jack.ps1 -Native                # Rive CLI window, hot-reloads scene.rml
```

Needs Python 3.12 with NumPy and Pillow, and the Rive CLI at `%USERPROFILE%\.rive\bin\rive.exe` (or on
PATH). PowerShell prints the CLI's stderr log as a NativeCommandError, so check for "0 errors" instead.

## Files

| File | Role |
|---|---|
| `parts.py` | Chroma key (with edge unmixing and rim removal), affine warp, NCC registration, crop/save |
| `build_jack.py` | Constants (pivots, crop, timing), part assembly, runtime assets, RML rig and timelines for every artboard |
| `verify_jack.py` | Real Rive captures of the story beats and each artboard, loop-seam check, review sheet, previews |
| `preview.html` | Plays `build/jack_wingman.riv` with the Rive web runtime; `?artboard=JackWrite` picks a start |
| `assets/` | 0.75x runtime PNG layers (generated; committed so the `.riv` builds without the raw renders) |
| `scene.rml`, `rive.yaml` | Generated Rive source; `rive.yaml` `main` must stay `JackWingman` |
| `build/` | `jack_wingman.riv`, `review.png`, `chat_size.png`, `preview.webp` are committed; scratch captures are ignored |

## Ship to the app

```powershell
Copy-Item app\tool\mascot_rive_jack\build\jack_wingman.riv app\assets\mascots\rive\jack_wingman.riv
```

Then follow section 8 of the pipeline doc to add `MascotPose` entries and render with `AnimatedMascot`.
