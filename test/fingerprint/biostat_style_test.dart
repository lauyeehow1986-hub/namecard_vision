import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/biostat_style.dart';
import 'package:namecard_vision/fingerprint/digest_random.dart';

/// Render the style to raw PNG bytes so we can compare pixels exactly.
Future<Uint8List> _renderPng(Uint8List digest, {int px = 200}) async {
  const style = BiostatStyle();
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  style.paint(canvas, Size(px.toDouble(), px.toDouble()), digest);
  final picture = recorder.endRecording();
  final image = await picture.toImage(px, px);
  final data = await image.toByteData(format: ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Uint8List _digestOf(String s) =>
    Uint8List.fromList(sha256.convert(utf8.encode(s)).bytes);

void main() {
  test('render is deterministic for a fixed digest', () async {
    final d = _digestOf('Ada Lovelace|Analyst|Engine Co');
    final a = await _renderPng(d);
    final b = await _renderPng(d);
    expect(a, equals(b), reason: 'same digest must produce identical pixels');
  });

  test('a single-byte digest change visibly changes the art', () async {
    final d1 = _digestOf('Ada Lovelace|Analyst|Engine Co');
    final d2 = _digestOf('Ada Lovelace|Analyst|Engine Co.'); // one char more
    expect(d1, isNot(equals(d2)));
    final a = await _renderPng(d1);
    final b = await _renderPng(d2);
    expect(a, isNot(equals(b)),
        reason: 'fingerprint must be faithful: different card -> different art');
  });

  test('DigestRandom is deterministic and platform-stable in range', () {
    final d = _digestOf('seed');
    final r1 = DigestRandom(d);
    final r2 = DigestRandom(d);
    final seqA = List.generate(50, (_) => r1.nextU32());
    final seqB = List.generate(50, (_) => r2.nextU32());
    expect(seqA, equals(seqB));
    for (final v in seqA) {
      expect(v, inInclusiveRange(0, 0xFFFFFFFF));
    }
  });

  test('DigestRandom.nextDouble stays in [0,1) and varies', () {
    final r = DigestRandom(_digestOf('x'));
    final vals = List.generate(100, (_) => r.nextDouble());
    for (final v in vals) {
      expect(v, greaterThanOrEqualTo(0.0));
      expect(v, lessThan(1.0));
    }
    expect(vals.toSet().length, greaterThan(50), reason: 'should not be constant');
  });
}
