import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../model/card.dart';
import '../../model/fingerprint_hash.dart';
import '../../share/ble_share.dart';
import '../../share/envelope.dart';
import '../../share/nfc_share.dart';
import '../../share/vcard.dart';
import '../../web/web_link.dart';
import 'ble_sheet.dart';
import 'nfc_sheet.dart';

/// Shows a card as a scannable QR (the verifiable NCV envelope) alongside its
/// fingerprint + safety code, plus a vCard fallback for app-less recipients.
class ShareScreen extends StatelessWidget {
  final NameCard card;
  const ShareScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final text = ShareEnvelope.encode(card);
    final fp = Fingerprint.ofCard(card);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Share card')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quiet-zone white card so the QR scans in any app theme.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: text,
                    version: QrVersions.auto,
                    size: 260,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  card.name.trim().isEmpty ? '(unnamed card)' : card.name.trim(),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'safety code  ${fp.safetyCode}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The recipient scans this, and their app re-derives the same '
                  'art and safety code — proof the card arrived unaltered.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                OverflowBar(
                  alignment: MainAxisAlignment.center,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    if (NfcShare.platformSupported)
                      FilledButton.icon(
                        icon: const Icon(Icons.contactless),
                        label: const Text('Tap to share'),
                        onPressed: () => showNfcSend(context, card),
                      ),
                    if (BleShare.platformSupported)
                      FilledButton.icon(
                        icon: const Icon(Icons.bluetooth),
                        label: const Text('Bluetooth'),
                        onPressed: () => showBleSend(context, card),
                      ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.link),
                      label: const Text('Share link'),
                      onPressed: () => Share.share(WebLink.forCard(card)),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy share code'),
                      onPressed: () => _copy(context, text, 'Share code copied'),
                    ),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.contact_page_outlined),
                      label: const Text('vCard'),
                      onPressed: () => _showVCard(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVCard(BuildContext context) {
    final vcf = VCard.of(card);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('vCard (contact export)'),
        content: SingleChildScrollView(
          child: SelectableText(
            vcf,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              _copy(context, vcf, 'vCard copied');
              Navigator.of(ctx).pop();
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
