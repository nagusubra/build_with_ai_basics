import 'package:camera/camera.dart';

/// Whether this device has a camera the app can ask for.
Future<bool> cameraAvailable() async {
  try {
    return (await availableCameras()).isNotEmpty;
  } catch (_) {
    return false;
  }
}
