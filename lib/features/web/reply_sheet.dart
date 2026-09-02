import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/card.dart';
import '../../ui/fingerprint_view.dart';
import '../../web/reply_message.dart';

/// Present the "reply with your card" hand-back sheet. [recipient] is the card
/// the web viewer just created; [sender] is the card they are viewing. The
/// reply is delivered through a channel already on the sender's card — no
/// backend, no accounts.
Future<void> showReplySheet(
  BuildContext context, {
  required NameCard recipient,
  required NameCard sender,
}) {
  final message = ReplyMessage.build(recipient, sender);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReplySheet(recipient: recipient, message: message),
  );
}

class _ReplySheet extends StatelessWidget {
  final NameCard recipient;
  final ReplyMessage message;

  const _ReplySheet({required this.recipient, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send your card back',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'They open your link and verify this exact art + safety code.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FingerprintView(card: recipient, size: 132),
            const SizedBox(height: 20),
            if (message.hasDirectChannel) ...[
              if (message.whatsApp != null)
                _channel(context, Icons.chat, 'Reply on WhatsApp',
                    message.whatsApp!),
              if (message.email != null)
                _channel(context, Icons.email_outlined, 'Reply by email',
                    message.email!),
              if (message.sms != null)
                _channel(
                    context, Icons.sms_outlined, 'Reply by SMS', message.sms!),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This card has no email or phone to reply to — copy your link '
                  'and send it to them however you like.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Your link was copied')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                    onPressed: () => Share.share(message.body),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _channel(
      BuildContext context, IconData icon, String label, Uri uri) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          icon: Icon(icon),
          label: Text(label),
          onPressed: () async {
            final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open that app.')),
              );
            }
          },
        ),
      ),
    );
  }
}
