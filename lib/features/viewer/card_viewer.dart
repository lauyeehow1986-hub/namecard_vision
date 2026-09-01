import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../share/contact_actions.dart';
import '../../ui/fingerprint_view.dart';
import '../share/share_screen.dart';
import 'contact_actions_ui.dart';

/// Read-only view of a card: the fingerprint (the thing you verify against),
/// the safety code, and actionable contact rows. Share / edit / delete live
/// in the app bar.
class CardViewer extends StatelessWidget {
  final NameCard card;
  final bool received;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CardViewer({
    super.key,
    required this.card,
    this.received = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = card.name.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? 'Card' : name),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShareScreen(card: card),
              ),
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                if (received)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Chip(
                      avatar: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Received — verify the safety code'),
                      backgroundColor:
                          theme.colorScheme.secondaryContainer,
                    ),
                  ),
                FingerprintView(card: card, size: 240),
                const SizedBox(height: 20),
                if (card.title.trim().isNotEmpty)
                  Text(card.title.trim(), style: theme.textTheme.titleMedium),
                if (card.org.trim().isNotEmpty)
                  Text(
                    card.org.trim(),
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 12),
                ..._contactRows(context),
                if (card.note.trim().isNotEmpty) ...[
                  const Divider(height: 32, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      card.note.trim(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
                if (card.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final t in card.tags)
                        Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
              ],
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
      rows.add(ListTile(
        leading: const Icon(Icons.phone),
        title: Text(p.e164),
        subtitle: p.label.trim().isEmpty ? null : Text(p.label.trim()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            showPhoneActions(context, e164: p.e164, label: p.label),
      ));
    }
    for (final e in card.emails) {
      if (e.trim().isEmpty) continue;
      rows.add(ListTile(
        leading: const Icon(Icons.email_outlined),
        title: Text(e.trim()),
        onTap: () => launchExternal(context, ContactActions.email(e)),
      ));
    }
    for (final s in card.socials) {
      final uri = ContactActions.social(s);
      if (uri == null) continue;
      rows.add(ListTile(
        leading: const Icon(Icons.link),
        title: Text(s.platform.trim().isEmpty ? uri.host : s.platform.trim()),
        subtitle: Text(uri.toString()),
        onTap: () => launchExternal(context, uri),
      ));
    }
    return rows;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this card?'),
        content: const Text('It will be removed from your collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete?.call();
  }
}
