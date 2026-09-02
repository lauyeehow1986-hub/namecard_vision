import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/phone.dart';
import '../../share/contact_actions.dart';

/// Launch [uri] in an external app, showing a snackbar if nothing can handle
/// it. Returns whether the launch was accepted.
Future<bool> launchExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text('Nothing can open $uri')));
    }
    return ok;
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open that link')),
    );
    return false;
  }
}

/// Bottom-sheet chooser for a phone number: WhatsApp / SMS / Call. WhatsApp
/// presence can't be detected, so it is always offered rather than guessed.
Future<void> showPhoneActions(
  BuildContext context, {
  required String e164,
  String label = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(PhoneFormat.toE164(e164)),
              subtitle: label.trim().isEmpty ? null : Text(label.trim()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await launchExternal(context, ContactActions.whatsApp(e164));
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('Text message'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await launchExternal(context, ContactActions.sms(e164));
              },
            ),
            ListTile(
              leading: const Icon(Icons.call),
              title: const Text('Call'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await launchExternal(context, ContactActions.call(e164));
              },
            ),
          ],
        ),
      ),
    ),
  );
}
