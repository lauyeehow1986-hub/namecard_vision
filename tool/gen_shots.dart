// Renders the demo namecards to PNGs under screenshots/ for the README.
// Run: flutter test tool/gen_shots.dart
//
// Not a real test — it just uses the flutter_test binding (which gives us an
// image pipeline for Picture.toImage) to compose each card onto a canvas and
// write it to disk. Text uses the bundled RobotoMono so glyphs render in the
// headless environment (the default test font is blank).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/fingerprint/registry.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';

const String _mono = 'RobotoMono';

final List<(String, NameCard)> _cards = [
  (
    'maya-biostat',
    const NameCard(
      name: 'Dr. Maya Chen',
      title: 'Consultant Cardiologist',
      org: 'Harbourfront Heart Centre',
      phones: [PhoneNumber(label: 'mobile', e164: '+6591234567')],
      emails: ['maya.chen@example.com'],
      socials: [
        SocialLink(platform: 'linkedin', handle: 'maya-chen'),
        SocialLink(platform: 'github', handle: 'mayachen'),
      ],
    ),
  ),
  (
    'arjun-geometric',
    const NameCard(
      name: 'Arjun Rao',
      title: 'Staff Data Scientist',
      org: 'Novena Analytics',
      phones: [PhoneNumber(label: 'mobile', e164: '+6598887766')],
      emails: ['arjun@example.org'],
      socials: [
        SocialLink(platform: 'x', handle: 'arjunrao'),
        SocialLink(platform: 'website', url: 'arjun.example.dev'),
      ],
      styleId: 'geometric.v1',
    ),
  ),
  (
    'sofia-harmonograph',
    const NameCard(
      name: 'Sofia Almeida',
      title: 'Principal Product Designer',
      org: 'Studio Lumen',
      phones: [PhoneNumber(label: 'mobile', e164: '+6590011223')],
      emails: ['sofia@example.net'],
      socials: [SocialLink(platform: 'instagram', handle: 'sofia.designs')],
      styleId: 'harmonograph.v1',
    ),
  ),
  (
    'wei-randomart',
    const NameCard(
      name: 'Wei Lin',
      title: 'Security Engineer',
      org: 'Redwall Labs',
      phones: [PhoneNumber(label: 'mobile', e164: '+6593334455')],
      emails: ['wei@example.io'],
      socials: [SocialLink(platform: 'github', handle: 'weilin')],
      styleId: 'randomart.v1',
    ),
  ),
];

String _socialLine(SocialLink s) {
  final v = s.url.trim().isNotEmpty ? s.url.trim() : s.handle.trim();
  return '${s.platform}  ·  $v';
}

void _line(Canvas c, String text,
    {required double x,
    required double y,
    required double width,
    required double size,
    required Color color,
    TextAlign align = TextAlign.left,
    double spacing = 0}) {
  final b = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontFamily: _mono,
    fontSize: size,
    textAlign: align,
  ))
    ..pushStyle(ui.TextStyle(color: color, letterSpacing: spacing))
    ..addText(text);
  final p = b.build()..layout(ui.ParagraphConstraints(width: width));
  c.drawParagraph(p, Offset(x, y));
}

Future<Uint8List> _renderCard(NameCard card) async {
  const w = 380.0, h = 548.0, scale = 3.0;
  const ink = Color(0xFF1B2430);
  const muted = Color(0xFF66707E);
  const page = Color(0xFFEDF0F5);
  const surface = Color(0xFFFFFFFF);
  const border = Color(0xFFE1E5EC);
  const accent = Color(0xFF3D6CE0);

  final fp = Fingerprint.ofCard(card);
  final style = styleById(card.styleId);

  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  c.scale(scale);

  // Page + card surface.
  c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = page);
  final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, w - 32, h - 32), const Radius.circular(20));
  c.drawRRect(cardRect, Paint()..color = surface);
  c.drawRRect(
      cardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border);

  // Fingerprint (the style paints its own background + rounding).
  const fpSize = 196.0;
  const fpX = (w - fpSize) / 2, fpY = 40.0;
  c.save();
  c.translate(fpX, fpY);
  style.paint(c, const Size(fpSize, fpSize), fp.digest);
  c.restore();

  // Safety code + label.
  _line(c, fp.safetyCode,
      x: 0, y: fpY + fpSize + 16, width: w, size: 18, color: ink,
      align: TextAlign.center, spacing: 2);
  _line(c, 'SAFETY CODE',
      x: 0, y: fpY + fpSize + 40, width: w, size: 9, color: muted,
      align: TextAlign.center, spacing: 3);

  // Identity.
  var y = fpY + fpSize + 62;
  _line(c, card.name,
      x: 0, y: y, width: w, size: 20, color: ink, align: TextAlign.center);
  y += 28;
  if (card.title.isNotEmpty) {
    _line(c, card.title,
        x: 0, y: y, width: w, size: 12.5, color: ink, align: TextAlign.center);
    y += 18;
  }
  if (card.org.isNotEmpty) {
    _line(c, card.org,
        x: 0, y: y, width: w, size: 12.5, color: muted,
        align: TextAlign.center);
    y += 22;
  }

  // Divider.
  c.drawLine(Offset(44, y), Offset(w - 44, y),
      Paint()..color = border..strokeWidth = 1);
  y += 18;

  // Contact lines.
  final lines = <String>[
    if (card.phones.isNotEmpty) card.phones.first.e164,
    ...card.emails,
    ...card.socials.map(_socialLine),
  ];
  for (final l in lines) {
    _line(c, l, x: 46, y: y, width: w - 92, size: 12.5, color: accent);
    y += 22;
  }

  final picture = recorder.endRecording();
  try {
    final img = await picture.toImage((w * scale).round(), (h * scale).round());
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  } finally {
    picture.dispose();
  }
}

void main() {
  testWidgets('render demo namecards', (tester) async {
    // Load the bundled monospace font so text isn't blank in the test engine.
    final data = await rootBundle.load('assets/fonts/RobotoMono-Regular.ttf');
    final loader = FontLoader(_mono)..addFont(Future.value(data));
    await loader.load();

    final dir = Directory('screenshots')..createSync();
    await tester.runAsync(() async {
      for (final (slug, card) in _cards) {
        final png = await _renderCard(card);
        File('${dir.path}/$slug.png').writeAsBytesSync(png);
        // ignore: avoid_print
        print('wrote screenshots/$slug.png (${png.length} bytes)');
      }
    });
  });
}
