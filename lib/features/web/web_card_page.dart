import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/card.dart';
import '../../model/phone.dart';
import '../../share/contact_actions.dart';
import '../../share/vcard.dart';
import '../../ui/fingerprint_view.dart';
import '../../web/download.dart';
import '../editor/editor_screen.dart';
import 'reply_sheet.dart';

/// The hosted, read-only web view of a card decoded from the URL fragment.
///
/// The fingerprint is re-derived here from the card bytes (never transmitted),
/// so what the recipient sees is a pure function of the data in front of them —
/// matching the sender's phone exactly. Below it: the contact details as
/// tappable links, a vCard download for app-less recipients, and a static
/// "reply with your card" loop that needs no backend.
class WebCardPage extends StatelessWidget {
  final NameCard card;

  const WebCardPage({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        [card.title, card.org].where((t) => t.trim().isNotEmpty).join(' · ');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FingerprintView(card: card, size: 208),
                  const SizedBox(height: 20),
                  Text(
                    card.name.trim().isEmpty ? '(unnamed card)' : card.name,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  ..._contactRows(context),
                  if (card.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(card.note,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Save contact'),
                        onPressed: _saveContact,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.reply),
                        label: const Text('Reply with your card'),
                        onPressed: () => _reply(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'The image above is a verifiable fingerprint of this card — '
                    'a single changed character produces different art. Made '
                    'with Namecard Vision.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contactRows(BuildContext context) {
    final rows = <Widget>[];
    for (final p in card.phones) {
      if (p.e164.trim().isEmpty) continue;
      final shown = PhoneFormat.toE164(p.e164);
      rows.add(_row(context, Icons.phone_outlined,
          p.label.trim().isEmpty ? shown : '$shown  (${p.label})',
          ContactActions.call(p.e164)));
    }
    for (final e in card.emails) {
      if (e.trim().isEmpty) continue;
      rows.add(_row(context, Icons.email_outlined, e, ContactActions.email(e)));
    }
    for (final s in card.socials) {
      final uri = ContactActions.social(s);
      if (uri == null) continue;
      final label = s.handle.trim().isNotEmpty ? s.handle : uri.toString();
      rows.add(_row(context, Icons.link, '${s.platform}: $label', uri));
    }
    return rows;
  }

  Widget _row(BuildContext context, IconData icon, String text, Uri uri) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(text),
      trailing: const Icon(Icons.open_in_new, size: 16),
      onTap: () => _launch(context, uri),
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${uri.scheme} link.')),
      );
    }
  }

  Future<void> _saveContact() async {
    final name = card.name.trim().isEmpty ? 'contact' : card.name.trim();
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    // Embed the fingerprint art so it becomes the contact photo on import.
    final vcf = await VCard.ofWithFingerprint(card);
    downloadText('$safe.vcf', vcf, mime: 'text/vcard;charset=utf-8');
  }

  Future<void> _reply(BuildContext context) async {
    // The editor pops itself once after onSave; we only capture the card here
    // (popping inside onSave too would race and close the reply sheet below).
    NameCard? theirs;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(onSave: (c) async => theirs = c),
      ),
    );
    if (theirs == null || !context.mounted) return;
    await showReplySheet(context, recipient: theirs!, sender: card);
  }
}
