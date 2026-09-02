import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../model/card.dart';
import 'card_parser.dart';

/// Captures a photo of a physical business card and runs on-device OCR
/// (Google ML Kit), returning a best-guess [NameCard] via [CardParser] to
/// prefill the editor. Device-only: ML Kit ships no web/desktop backend, so the
/// UI must gate on [platformSupported].
class OcrScanner {
  const OcrScanner._();

  /// ML Kit text recognition exists only on Android and iOS.
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Take (or pick) a photo and recognize it. Returns the parsed card, or null
  /// if the user cancelled. Throws [OcrException] on a recognition failure so
  /// the UI can show a clear message.
  static Future<NameCard?> scan({required ImageSource source}) async {
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
      );
    } catch (e) {
      throw const OcrException('Could not open the camera or gallery.');
    }
    if (photo == null) return null; // cancelled

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(photo.path);
      final result = await recognizer.processImage(input);
      return CardParser.parse(_toLines(result));
    } catch (e) {
      throw const OcrException('Could not read text from that image.');
    } finally {
      await recognizer.close();
    }
  }

  /// Flatten ML Kit's block→line structure into [OcrLine]s, carrying each
  /// line's bounding-box height so the parser can rank the name by size.
  static List<OcrLine> _toLines(RecognizedText result) {
    final lines = <OcrLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final h = line.boundingBox.height.toDouble();
        lines.add(OcrLine(line.text, height: h));
      }
    }
    return lines;
  }
}

/// A recognition failure worth surfacing to the user.
class OcrException implements Exception {
  final String message;
  const OcrException(this.message);

  @override
  String toString() => message;
}
