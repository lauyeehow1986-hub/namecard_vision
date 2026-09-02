import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../contacts/device_contacts.dart';
import '../../fingerprint/ascii_signature.dart';
import '../../model/card.dart';
import '../../model/phone.dart';
import '../../share/contact_actions.dart';
import '../../ui/fingerprint_view.dart';
import '../share/share_screen.dart';
import 'contact_actions_ui.dart';

/// Read-only view of a card: the fingerprint (the thing you verify against),
/// the safety code, and actionable contact rows. Share / pin / edit / delete
/// live in the app bar.
///
/// [pinned] and [isMine] are display state; toggling them calls back to the
/// store via [onTogglePin] / [onToggleMine]. The view keeps its own copy so the
/// app bar updates instantly while it sits on top of the navigation stack.
class CardViewer extends StatefulWidget {
  final NameCard card;
  final bool received;
  final bool pinned;
  final bool isMine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onTogglePin;
  final ValueChanged<bool>? onToggleMine;

  const CardViewer({
    super.key,
    required this.card,
    this.received = false,
    this.pinned = false,
    this.isMine = false,
    this.onEdit,
    this.onDelete,
    this.onTogglePin,
    this.onToggleMine,
  });

  @override
  State<CardViewer> createState() => _CardViewerState();
}

class _CardViewerState extends State<CardViewer> {
  late bool _pinned = widget.pinned;
  late bool _isMine = widget.isMine;

  NameCard get card => widget.card;

  void _togglePin() {
    setState(() => _pinned = !_pinned);
    widget.onTogglePin?.call(_pinned);
  }

  void _toggleMine() {
    setState(() => _isMine = !_isMine);
    widget.onToggleMine?.call(_isMine);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = card.name.trim();
    final hasMenu = widget.onToggleMine != null ||
        widget.onEdit != null ||
        widget.onDelete != null ||
        DeviceContacts.platformSupported;

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
          if (widget.onTogglePin != null)
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin to top',
              icon: Icon(_pinned ? Icons.star : Icons.star_border,
                  color: _pinned ? theme.colorScheme.primary : null),
              onPressed: _togglePin,
            ),
          if (hasMenu)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'mine':
                    _toggleMine();
                  case 'toPhone':
                    _saveToPhone(context);
                  case 'edit':
                    widget.onEdit?.call();
                  case 'delete':
                    _confirmDelete(context);
                }
              },
              itemBuilder: (_) => [
                if (DeviceContacts.platformSupported)
                  const PopupMenuItem(
                    value: 'toPhone',
                    child: ListTile(
                      leading: Icon(Icons.contact_phone_outlined),
                      title: Text('Save to phone contacts'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (widget.onToggleMine != null)
                  PopupMenuItem(
                    value: 'mine',
                    child: ListTile(
                      leading: Icon(_isMine
                          ? Icons.person_outline
                          : Icons.badge_outlined),
                      title: Text(
                          _isMine ? 'Move to contacts' : 'Set as my card'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (widget.onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (widget.onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
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
                if (_isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Chip(
                      avatar: const Icon(Icons.badge_outlined, size: 18),
                      label: const Text('Your card'),
                      backgroundColor: theme.colorScheme.primaryContainer,
                    ),
                  )
                else if (widget.received)
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
                const SizedBox(height: 12),
                _decorativeSignature(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A fun ASCII critter derived from the card's fingerprint. Collapsed by
  /// default and explicitly labelled as decorative so it is never mistaken for
  /// the verification image above.
  Widget _decorativeSignature(BuildContext context) {
    final theme = Theme.of(context);
    final art = AsciiSignature.ofCard(card);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        // Drop the divider lines ExpansionTile draws by default.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_nature_outlined),
          title: const Text('Decorative signature'),
          subtitle: const Text('Just for fun — not the verification image'),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SelectableText(
                    art,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.25,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    onPressed: () => _copyAscii(context, art),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAscii(BuildContext context, String art) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: art));
    messenger.showSnackBar(
      const SnackBar(content: Text('Copied the decorative signature.')),
    );
  }

  List<Widget> _contactRows(BuildContext context) {
    final rows = <Widget>[];
    for (final p in card.phones) {
      if (p.e164.trim().isEmpty) continue;
      rows.add(ListTile(
        leading: const Icon(Icons.phone),
        title: Text(PhoneFormat.toE164(p.e164)),
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

  Future<void> _saveToPhone(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await DeviceContacts.saveToPhone(card);
    final message = switch (outcome) {
      SaveToPhoneOutcome.saved => 'Saved to your phone contacts.',
      SaveToPhoneOutcome.permissionDenied =>
        'Contacts permission is needed to save.',
      SaveToPhoneOutcome.failed => 'Could not save to contacts.',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
    if (ok == true) widget.onDelete?.call();
  }
}
