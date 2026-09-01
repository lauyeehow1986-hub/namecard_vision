import 'package:flutter/material.dart';

import 'features/editor/editor_screen.dart';
import 'features/scanner/scan_screen.dart';
import 'features/viewer/card_viewer.dart';
import 'features/share/share_screen.dart';
import 'model/card.dart';

/// Database-free demo entrypoint for the browser:
///   flutter run -d chrome -t lib/main_demo.dart
///
/// The full app (`lib/main.dart`) adds the Drift-backed collection, whose
/// native SQLite does not compile for web. Everything shown here — the
/// fingerprint editor, QR share, scan/paste receive, and card viewer — is pure
/// Dart/`dart:ui`, so the whole P2 sharing loop runs live in a browser with no
/// store behind it.
void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3A6EA5);
    return MaterialApp(
      title: 'Namecard Vision — demo',
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
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Namecard Vision — demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The full sharing loop',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Make a card and watch its verifiable fingerprint form as you '
                  'type. Share it as a QR, then receive it back by pasting the '
                  'code — the safety code you see is proof it arrived unaltered.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _createAndShare(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New card  →  share'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _receive(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Receive a card'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _shareSample(context),
                  child: const Text('Share a sample card'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createAndShare(BuildContext context) async {
    final nav = Navigator.of(context);
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => EditorScreen(
        onSave: (card) async {
          nav.pop(); // close editor
          nav.push(MaterialPageRoute<void>(
            builder: (_) => ShareScreen(card: card),
          ));
        },
      ),
    ));
  }

  void _shareSample(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ShareScreen(
        card: NameCard(
          name: 'Grace Hopper',
          title: 'Rear Admiral',
          org: 'US Navy',
          phones: [PhoneNumber(label: 'mobile', e164: '+15125550143')],
          emails: ['grace@navy.example'],
          socials: [SocialLink(platform: 'website', url: 'https://example.org')],
          tags: ['compiler', 'legend'],
        ),
      ),
    ));
  }

  Future<void> _receive(BuildContext context) async {
    final nav = Navigator.of(context);
    final card = await nav.push<NameCard>(
      MaterialPageRoute<NameCard>(builder: (_) => const ScanScreen()),
    );
    if (card == null) return;
    nav.push(MaterialPageRoute<void>(
      builder: (_) => CardViewer(card: card, received: true),
    ));
  }
}
