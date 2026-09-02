// Captures real app screens to PNGs under screenshots/ for the README.
// Run: flutter test --update-goldens tool/gen_feature_shots.dart
//
// Not a real test — it drives actual app widgets (editor, viewer, share) at a
// phone size and writes each screen via matchesGoldenFile (which handles the
// headless image capture reliably). Full Roboto + MaterialIcons + RobotoMono
// fonts are loaded so nothing renders as tofu. The goldens live in
// screenshots/, so re-running with --update-goldens refreshes the README shots.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/editor/editor_screen.dart';
import 'package:namecard_vision/features/share/share_screen.dart';
import 'package:namecard_vision/features/viewer/card_viewer.dart';
import 'demo_cards.dart';

const _flutterFonts = 'C:/src/flutter/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    final loader = FontLoader(family)
      ..addFont(File(path).readAsBytes().then((b) => b.buffer.asByteData()));
    await loader.load();
  }

  await load('Roboto', '$_flutterFonts/roboto-regular.ttf');
  await load('MaterialIcons', '$_flutterFonts/materialicons-regular.otf');
  final mono = await rootBundle.load('assets/fonts/RobotoMono-Regular.ttf');
  for (final fam in ['RobotoMono', 'monospace']) {
    await (FontLoader(fam)..addFont(Future.value(mono))).load();
  }
}

Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorSchemeSeed: const Color(0xFF3D6CE0),
        brightness: Brightness.light,
      ),
      home: home,
    );

/// Phone-sized surface at 3x so the PNG is crisp.
void _phone(WidgetTester tester) {
  const w = 390.0, h = 844.0, dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(w * dpr, h * dpr);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(_loadFonts);

  testWidgets('editor', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(EditorScreen(initial: demoMaya, onSave: (_) async {})));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(EditorScreen),
        matchesGoldenFile('../screenshots/feature-editor.png'));
  });

  testWidgets('viewer', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(CardViewer(
      card: demoArjun,
      onCardChanged: (_) {},
      onEdit: () {},
      onDelete: () {},
      onTogglePin: (_) {},
      onToggleMine: (_) {},
    )));
    await tester.pump(const Duration(milliseconds: 400));
    // Expand the skin switcher so the four skins are visible.
    final tile = find.textContaining('Art skin:');
    if (tile.evaluate().isNotEmpty) {
      await tester.tap(tile);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await expectLater(find.byType(CardViewer),
        matchesGoldenFile('../screenshots/feature-viewer.png'));
  });

  testWidgets('share', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const ShareScreen(card: demoWei)));
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byType(ShareScreen),
        matchesGoldenFile('../screenshots/feature-share.png'));
  });
}
