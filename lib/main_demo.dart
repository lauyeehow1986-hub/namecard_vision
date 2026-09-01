import 'package:flutter/material.dart';

import 'features/editor/editor_screen.dart';

/// Editor-only demo entrypoint (no database), for running the live fingerprint
/// preview in a browser: `flutter run -d chrome -t lib/main_demo.dart`.
///
/// The full app (`lib/main.dart`) adds the Drift-backed collection, whose
/// native SQLite does not compile for web; the fingerprint engine itself is
/// pure `dart:ui`, so this harness shows the interactive core with no store.
void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3A6EA5);
    return MaterialApp(
      title: 'Namecard Vision — Fingerprint demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorScreen(),
    );
  }
}
