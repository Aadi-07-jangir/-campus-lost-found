import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebImageResult {
  final Uint8List bytes;
  final String name;
  WebImageResult({required this.bytes, required this.name});
}

/// Uses the browser's native file input to pick an image.
/// This avoids the blob URL revocation issue with image_picker on Flutter Web.
Future<WebImageResult?> pickImageWeb() async {
  final completer = Completer<WebImageResult?>();

  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();

  input.onChange.listen((event) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((event) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(
            WebImageResult(bytes: result, name: file.name));
      } else if (result is List<int>) {
        completer.complete(
            WebImageResult(bytes: Uint8List.fromList(result), name: file.name));
      } else {
        completer.complete(null);
      }
    });

    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(file);
  });

  // Handle cancel (no file selected)
  input.onAbort.listen((_) => completer.complete(null));

  return completer.future;
}
