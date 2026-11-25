import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text in a photo or screenshot, on the phone. Behind an interface
/// so tests (and web, which has no ML Kit) use a fake.
abstract class OcrService {
  /// False where there is no recogniser (web, tests by default).
  bool get available;

  /// The recognised text, line by line; empty when nothing was found.
  /// Throws when the image cannot be read.
  Future<String> read(String imagePath);
}

/// Google ML Kit on-device text recognition (free, bundled model; the image
/// never leaves the phone).
class MlKitOcr implements OcrService {
  @override
  bool get available => true;

  @override
  Future<String> read(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return [
        for (final block in result.blocks)
          for (final line in block.lines) line.text,
      ].join('\n');
    } finally {
      await recognizer.close();
    }
  }
}

class NoOcr implements OcrService {
  const NoOcr();
  @override
  bool get available => false;
  @override
  Future<String> read(String imagePath) async => '';
}

/// Returns canned text; for tests and the demo build.
class FakeOcr implements OcrService {
  FakeOcr(this.text);
  final String text;
  @override
  bool get available => true;
  @override
  Future<String> read(String imagePath) async => text;
}
