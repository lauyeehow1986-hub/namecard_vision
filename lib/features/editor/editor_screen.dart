import 'package:flutter/material.dart';

import '../../fingerprint/registry.dart';
import '../../model/card.dart';
import '../../model/fingerprint_hash.dart';
import '../../ui/fingerprint_view.dart';

/// Card editor with a live fingerprint preview. As the fields change the art
/// and safety code recompute on every keystroke, so the verifiable identity of
/// the card is visible while you type it.
class EditorScreen extends StatefulWidget {
  /// Existing card to edit, or null to start a blank one.
  final NameCard? initial;

  /// Called with the finished card when the user saves. Persistence lives in
  /// the caller so the editor stays a pure form.
  final Future<void> Function(NameCard card)? onSave;

  const EditorScreen({super.key, this.initial, this.onSave});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _org;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _tags;
  late final TextEditingController _note;
  bool _saving = false;

  /// The chosen art skin ([FingerprintStyle.id]); null means the default skin.
  String? _styleId;

  @override
  void initState() {
    super.initState();
    final c = widget.initial ?? const NameCard();
    _styleId = c.styleId;
    _name = TextEditingController(text: c.name);
    _title = TextEditingController(text: c.title);
    _org = TextEditingController(text: c.org);
    _phone = TextEditingController(
        text: c.phones.isNotEmpty ? c.phones.first.e164 : '');
    _email =
        TextEditingController(text: c.emails.isNotEmpty ? c.emails.first : '');
    _tags = TextEditingController(text: c.tags.join(', '));
    _note = TextEditingController(text: c.note);
    for (final ctl in [_name, _title, _org, _phone, _email, _tags, _note]) {
      ctl.addListener(_onChanged);
    }
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    for (final ctl in [_name, _title, _org, _phone, _email, _tags, _note]) {
      ctl.dispose();
    }
    super.dispose();
  }

  /// Build the card from the current form, applying light normalization so the
  /// canonical bytes (and thus the fingerprint) are stable across trivial
  /// whitespace differences. Normalization is deliberately the editor's job.
  NameCard _currentCard() {
    String t(TextEditingController c) => c.text.trim();
    final phone = t(_phone);
    final email = t(_email);
    final tags = _tags.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return NameCard(
      name: t(_name),
      title: t(_title),
      org: t(_org),
      phones: phone.isEmpty ? const [] : [PhoneNumber(label: 'mobile', e164: phone)],
      emails: email.isEmpty ? const [] : [email],
      note: t(_note),
      tags: tags,
      styleId: _styleId,
    );
  }

  Future<void> _save() async {
    if (widget.onSave == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave!(_currentCard());
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card saved')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _currentCard();
    final fp = Fingerprint.ofCard(card);
    final wide = MediaQuery.of(context).size.width >= 720;

    final preview = _PreviewPanel(
      card: card,
      hex: fp.hex,
      selectedStyleId: _styleId,
      onStyleSelected: (id) => setState(() => _styleId = id),
    );
    final form = _formFields();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'New card' : 'Edit card'),
        actions: [
          if (widget.onSave != null)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: 'Save',
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                  ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: form)),
                SizedBox(
                  width: 340,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: preview,
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: preview),
                  const SizedBox(height: 24),
                  form,
                ],
              ),
            ),
    );
  }

  Widget _formFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_name, 'Name', Icons.person_outline),
          _field(_title, 'Title', Icons.badge_outlined),
          _field(_org, 'Organization', Icons.business_outlined),
          _field(_phone, 'Phone (E.164, e.g. +6591234567)', Icons.phone_outlined,
              keyboard: TextInputType.phone),
          _field(_email, 'Email', Icons.email_outlined,
              keyboard: TextInputType.emailAddress),
          _field(_tags, 'Tags (comma separated)', Icons.label_outline),
          _field(_note, 'Note', Icons.notes_outlined, maxLines: 3),
        ],
      );

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  final NameCard card;
  final String hex;
  final String? selectedStyleId;
  final ValueChanged<String> onStyleSelected;

  const _PreviewPanel({
    required this.card,
    required this.hex,
    required this.selectedStyleId,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FingerprintView(card: card, size: 240),
        const SizedBox(height: 16),
        _SkinPicker(
          card: card,
          selectedStyleId: selectedStyleId,
          onSelected: onStyleSelected,
        ),
        const SizedBox(height: 16),
        Text(
          card.name.isEmpty ? '(unnamed card)' : card.name,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (card.org.isNotEmpty || card.title.isNotEmpty)
          Text(
            [card.title, card.org].where((s) => s.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        SelectableText(
          hex,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.4,
          ),
        ),
        Text(
          'SHA-256 fingerprint',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

/// A row of tappable thumbnails — one per registered art skin — each rendering
/// the *current* card so the choice previews live. Selecting a skin only
/// changes how the card is drawn; the safety code (content hash) is unchanged.
class _SkinPicker extends StatelessWidget {
  final NameCard card;
  final String? selectedStyleId;
  final ValueChanged<String> onSelected;

  const _SkinPicker({
    required this.card,
    required this.selectedStyleId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveId = selectedStyleId ?? defaultStyle.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ART SKIN',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.hintColor, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in styles)
              _SkinThumb(
                label: s.label,
                selected: s.id == effectiveId,
                onTap: () => onSelected(s.id),
                // Render this specific skin for the current card, no code.
                child: FingerprintView(
                  card: card,
                  size: 64,
                  style: s,
                  showSafetyCode: false,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SkinThumb extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SkinThumb({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label art skin',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  width: selected ? 2.5 : 1,
                  color: selected ? accent : theme.dividerColor,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: child,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? accent : theme.hintColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
