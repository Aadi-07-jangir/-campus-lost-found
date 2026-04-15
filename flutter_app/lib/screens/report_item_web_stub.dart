import 'dart:typed_data';

/// Stub for non-web platforms — never actually called at runtime.
class WebImageResult {
  final Uint8List bytes;
  final String name;
  WebImageResult({required this.bytes, required this.name});
}

Future<WebImageResult?> pickImageWeb() async => null;
