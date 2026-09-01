import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/biostat_style.dart';

// Not a real test — a helper to eyeball the fingerprint art.
// Run: flutter test test/_render_samples.dart
Future<void> _write(String label, String seed, String dir) async {
  final digest = Uint8List.fromList(sha256.convert(utf8.encode(seed)).bytes);
  const px = 480;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  const BiostatStyle().paint(canvas, Size(px.toDouble(), px.toDouble()), digest);
  final img = await recorder.endRecording().toImage(px, px);
  final png = (await img.toByteData(format: ImageByteFormat.png))!.buffer.asUint8List();
  File('$dir/$label.png').writeAsBytesSync(png);
}

void main() {
  test('render sample fingerprints', () async {
    final dir = Platform.environment['NCV_OUT'] ?? Directory.systemTemp.path;
    await _write('ada', 'Ada Lovelace|Analyst|Analytical Engine Co', dir);
    await _write('ada2', 'Ada Lovelace|Analyst|Analytical Engine Co.', dir);
    await _write('grace', 'Grace Hopper|Rear Admiral|US Navy', dir);
    await _write('alan', 'Alan Turing|Cryptanalyst|Bletchley Park', dir);
    await _write('yh', 'YH|Researcher|NHCS Singapore', dir);
    await _write('empty', '', dir);
    stderr.writeln('Wrote samples to $dir');
  });
}
