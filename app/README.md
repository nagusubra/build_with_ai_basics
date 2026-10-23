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

## Tests

```sh
flutter test                                   # unit tests, no device needed
flutter test integration_test/face_match_test.dart   # on-device face pipeline
```
