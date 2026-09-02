import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../fingerprint/registry.dart';
import '../fingerprint/style.dart';
import '../model/card.dart';
import '../model/fingerprint_hash.dart';

/// Rasterizes a card's fingerprint art to PNG bytes so it can travel as a
/// contact photo — a vCard `PHOTO` value, or a native contact's avatar.
///
/// The image stays a pure function of the digest (same style + background as
/// [FingerprintView]), so a rasterized fingerprint is still a faithful
/// verification image, not decoration.
class FingerprintRaster {
  const FingerprintRaster._();

  /// Render [card]'s fingerprint to a square PNG, [size]x[size] pixels.
  ///
  /// An opaque [background] is painted first so Contacts apps that don't
  /// composite transparency still show the art on a clean field.
  static Future<Uint8List> pngOfCard(
    NameCard card, {
    int size = 512,
    Color background = Colors.white,
    FingerprintStyle? style,
  }) async {
    final fp = Fingerprint.ofCard(card);
    final s = style ?? styleById(card.styleId);
    final dim = size.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, dim, dim),
      Paint()..color = background,
    );
    s.paint(canvas, Size(dim, dim), fp.digest);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(size, size);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// The same art, base64-encoded for embedding in a vCard `PHOTO` value.
  static Future<String> base64OfCard(
    NameCard card, {
    int size = 512,
  }) async {
    final bytes = await pngOfCard(card, size: size);
    return base64.encode(bytes);
  }
}
