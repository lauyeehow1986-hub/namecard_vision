import 'package:flutter/material.dart';

import 'features/web/web_card_page.dart';
import 'model/card.dart';
import 'web/web_link.dart';

/// Web-only entrypoint for the hosted card viewer:
///   flutter build web --target lib/main_web.dart --base-href /namecard_vision/
///
/// The card is carried in the URL *fragment* (after `#`), which the browser
/// never sends to the server — so the host sees no card data. Everything here
/// is pure Dart / `dart:ui` (no Drift, no device plugins), so it compiles for
/// the web and re-derives the sender's fingerprint locally. That is the
/// verification, running in a browser with no backend.
void main() {
  final card = WebLink.cardFromUri(Uri.base);
  runApp(WebViewerApp(card: card));
}

class WebViewerApp extends StatelessWidget {
  final NameCard? card;

  const WebViewerApp({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3A6EA5);
    return MaterialApp(
      title: 'Namecard Vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: card == null ? const _EmptyState() : WebCardPage(card: card!),
    );
  }
}

/// Shown when the page is opened without a valid card in the URL fragment.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Namecard Vision',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Open a Namecard Vision share link to view someone’s card. '
                  'The card travels inside the link itself — nothing is stored '
                  'on a server.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
