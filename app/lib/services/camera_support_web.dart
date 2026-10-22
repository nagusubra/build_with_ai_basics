/// Whether this browser can open a camera at all. Whether the person allows it
/// is only known once the live check asks for it.
Future<bool> cameraAvailable() async => true;
