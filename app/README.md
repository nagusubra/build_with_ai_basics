# BakeOut

Food-first dating with an AI wingman. Flutter app for iOS, Android, and the web.

## Run it

```sh
sh app/scripts/setup.sh     # Firebase config for all three platforms (git-ignored output)
cd app
flutter run                 # pick a device, or -d chrome / -d <android device>
```

`setup.sh` downloads the iOS, Android, and web app settings from the Firebase project
and writes `lib/firebase_options.dart` plus `ios/Runner/GoogleService-Info.plist`. On
macOS it also writes your own Apple signing config. Every output is git-ignored, so each
developer keeps their own copy; `--refresh` downloads everything again. Android and web
need no signing step.

Build:

```sh
flutter build ios --release
flutter build apk --debug        # release signing is still the debug key
flutter build web --release      # deployed by firebase deploy --only hosting
```

## The selfie check, per platform

The live check (blink, turn, look back) and the match against the main photo run on the
device everywhere. The selfie never leaves it: frames live in memory, the temporary file
the camera writes is deleted immediately, and nothing is uploaded.

| | Face detection | Still face | Match |
| --- | --- | --- | --- |
| iOS | Apple Vision (`ios/Runner/AppDelegate.swift`) | BGRA image stream | MobileFaceNet via TensorFlowLiteSwift (vendored) |
| Android | ML Kit face detection (`FaceVisionChannel.kt`) | NV21 image stream, rotated upright | MobileFaceNet via `flutter_litert` |
| Web | MediaPipe face landmarks (`web/bakeout_vision.js`) | browser `<video>` capture | MobileFaceNet via TensorFlow.js LiteRT |

Everything above the platform line is shared Dart: `liveness_tracker.dart` owns the step
order and thresholds, `detected_face.dart` normalises what each backend reports,
`face_math.dart` aligns the eyes to the model's 112x112 layout, and
`verification_service.dart` compares the two embeddings (cosine, cutoff 0.5 in one
constant). `live_check_view{,_native,_web}.dart` and `face_vision{,_native,_web}.dart`
are the conditional-import shims that pick the platform.

### Android frames arrive sideways

Android's camera plugin hands over image-stream frames in the sensor's own orientation,
unlike iOS. `services/frame_rotation.dart` adds the sensor angle to the way the phone is
being held and passes the result through `FaceVision.detectInFrame` into
`InputImage.fromByteBuffer`. It is a pure function, so `test/frame_rotation_test.dart`
covers it; the real test is a physical phone in portrait and in landscape.

### Web: the wasm runtime must sit next to the script

`web/tflite/tf-tflite.min.js` loads `tflite_web_api_cc_simd.wasm` from **its own
directory**, not the page root. Those four runtime files (`tflite_web_api_cc{,_simd}.{js,wasm}`)
therefore belong in `web/tflite/`; putting them anywhere else fails at
`loadTFLiteModel` with `Cannot read properties of undefined (reading '_malloc')`.
MediaPipe's bundle and wasm live in `web/mediapipe/`. Both sets are self-hosted, so the
app needs no CDN.

## Mascot motion

The seven large mascot poses share one code-authored Rive file,
`assets/mascots/rive/cherry_mascots.riv`. The PNGs stay the poster and the fallback;
small mascots and reduced-motion users never load Rive.

### Preview without Flutter

Open the Rive preview window instead of building and launching the app:

```powershell
cd app
.\tool\preview_mascot.ps1
.\tool\preview_mascot.ps1 -Artboard DuoMatch
```

It watches `tool/mascot_rive/scene.rml` and rebuilds live. In the window, `space` pauses,
`a` switches artboard, and `s` writes a screenshot. The equivalent direct command is
`rive tool/mascot_rive --artboard=DuoWelcome`.

### Regenerate the asset

Regenerate it from the repo's `design/mascots/*.png` sources after changing the
motion or pose list. Install the Rive CLI once (`curl -fsSL https://rive.app/install.sh | sh`
on macOS/Linux, or the installer from https://rive.app/docs/cli on Windows), then:

```sh
cd app
dart run tool/build_mascot_rive.dart             # all seven artboards
dart run tool/build_mascot_rive.dart --only=DuoWelcome  # one probe build
```

The script resizes each PNG to 768px in `tool/mascot_rive/assets/`, writes
`tool/mascot_rive/scene.rml`, runs `rive --verify` and `rive --once`, and copies the
result over the committed `.riv`. Those intermediates are git-ignored. `MASCOT_RIVE=false`
forces the PNG path; Reduce Motion does the same at runtime.

### Isolated layered DuoWelcome proof

`tool/mascot_rive_duo/` is a separate art experiment, **not wired into Flutter**.
It leaves the shipped seven-pose asset and PNG/reduced-motion fallback untouched.
The latest direction is two open eyes for Jill looking left toward Jack, a
synchronized blink and a gentle shared nuzzle instead of a phone tap. Jack still
gives the pan a small lift. Jill's eyes, lids, lashes and brows are repainted
from image-model (Gemini) edits of a 2x face crop, stored in
`design/mascots/jill_eyes_gemini/` (`open`, `half`, `nearly`, `closed`). The
builder maps that crop back to source box `(545, 300, 929, 684)`, composites only
feathered eye/brow ellipses, and subtracts the surrounding color drift so the
cheeks keep the original shading.

From `app/`, with Python, NumPy, Pillow and the Rive CLI available:

```powershell
python .\tool\mascot_rive_duo\build_proof.py
python .\tool\mascot_rive_duo\verify_proof.py
.\tool\preview_mascot_duo.ps1
```

The thirteen transparent 768px layers are the body, two heads, Jack's pan arm,
Jill's phone hand, two closed-eye overlays, and three in-between blink poses per
character. Layer cuts and pivots are authored
against the 1024px source, then **both** are scaled by 0.75 for Rive. Artboard
pivots: pan `(228.75, 435)`, phone `(671.25, 476.25)`, Jack's head `(316.5, 270)`,
Jill's head `(517.5, 270)`. Exterior outlines belong only to their moving layer;
only interior neck/shoulder overlap stays underneath.

The 192-frame/3.2-second loop uses a restrained breath and sway, a pan lift peaking
at frame 62, anticipation at 72-84, and a nuzzle peaking at 101/103 (about 1.38 degrees
per head). Sway, pan and head curves have matching velocities at their joins,
including the loop: the sway passes through center instead of stopping there.
The blink closes through three poses at 94-96 (Jill: half, nearly, nearly), holds at 97-102,
then reopens more slowly through 103-108. Each pose is opaque, never a dissolve:
pupils retain their shape and never ghost through the eyelids. Heads settle
independently through 160/164. A small native vector heart blooms at the nuzzle and floats away; the
original three sparkles remain. All tracks return to their starting values,
including sparkle rotation, and hidden effects start hidden.

The verifier checks pivots, loop endpoints and velocity continuity, blink
synchronization/hold timing and exclusive visibility of intermediate poses,
layer dimensions/transparency, stationary silhouette ghosts, a rendered loop
boundary (at most 3/255 channel-level raster rounding), and the 4 MB size limit.
The builder also requires exact source-resolution rest reconstruction against
the repainted artwork, verifies both pupils sit left of their sclera, keeps the
repaint inside the opaque head interior, and prevents it reaching Jill's mouth.
Run `build_proof.py` before `verify_proof.py`; the verifier does not rebuild. Runtime captures include
one initialization tick before their numbered animation frame; this avoids
mistaking state-machine entry for a loop discontinuity. Visual inspection is
still required for art quality.

Outputs in `tool/mascot_rive_duo/build/`:

- `duo_welcome_layered.riv`: standalone proof.
- `preview.webp`: all 192 **actual Rive runtime** captures at 60fps, not simulated transforms.
- `preview.gif`: a browser-friendly 50fps version, also exactly 3.2 seconds.
- `review.png`: pose sheet, including exact 290px captures.
- `eye_review.png`: enlarged open, closed and intermediate eye poses.
- `rest.png`, `arm.png`, `blink.png`, `bump.png`, `settle.png`, their `app_` variants,
  and `review_*.png`: full-size and intermediate-frame inspection.

For a single headless capture from `app/` (capture paths are relative to the shell's
working directory, not the Rive project):

```powershell
& "$env:USERPROFILE\.rive\bin\rive.exe" .\tool\mascot_rive_duo --verify
& "$env:USERPROFILE\.rive\bin\rive.exe" .\tool\mascot_rive_duo --screenshot=tool\mascot_rive_duo\build\bump.png --advance=101
```

Approve the live proof before committing or integrating it into the app.

## Tests

```sh
flutter test                                   # unit tests, no device needed
flutter test integration_test/face_match_test.dart   # on-device face pipeline
```
