import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../model/fingerprint_hash.dart';
import '../../ui/fingerprint_view.dart';
import '../../ui/skin_picker.dart';

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

  /// Social / web links being edited. Managed as a list (not controllers on the
  /// state) so rows can be added and removed freely.
  late List<SocialLink> _socials;

  @override
  void initState() {
    super.initState();
    final c = widget.initial ?? const NameCard();
    _styleId = c.styleId;
    _socials = List<SocialLink>.of(c.socials);
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
      socials: _cleanSocials(),
      note: t(_note),
      tags: tags,
      styleId: _styleId,
    );
  }

  /// Drop links whose value is empty and trim the rest, so blank rows the user
  /// added but never filled in don't get saved onto the card.
  List<SocialLink> _cleanSocials() {
    final out = <SocialLink>[];
    for (final s in _socials) {
      final handle = s.handle.trim();
      final url = s.url.trim();
      if (handle.isEmpty && url.isEmpty) continue;
      out.add(SocialLink(platform: s.platform, handle: handle, url: url));
    }
    return out;
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
          _SocialsSection(
            socials: _socials,
            onChanged: (list) => setState(() => _socials = list),
          ),
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
        SkinPicker(
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

/// Editable list of social / web links. Each row is a platform picker plus a
/// value field (a handle for named platforms, a full URL for "Website"). Owns
/// its own controllers so rows can be added/removed, and reports the current
/// list up via [onChanged] on every edit.
class _SocialsSection extends StatefulWidget {
  final List<SocialLink> socials;
  final ValueChanged<List<SocialLink>> onChanged;

  const _SocialsSection({required this.socials, required this.onChanged});

  @override
  State<_SocialsSection> createState() => _SocialsSectionState();
}

class _SocialsSectionState extends State<_SocialsSection> {
  /// Platform keys offered in the dropdown, with a label and value hint.
  static const List<(String, String, String)> _platforms = [
    ('linkedin', 'LinkedIn', 'username'),
    ('github', 'GitHub', 'username'),
    ('x', 'X', 'handle (no @)'),
    ('instagram', 'Instagram', 'handle (no @)'),
    ('website', 'Website', 'example.com/you'),
  ];

  late List<String> _rowPlatforms;
  late List<TextEditingController> _rowCtrls;

  @override
  void initState() {
    super.initState();
    _rowPlatforms = [];
    _rowCtrls = [];
    for (final s in widget.socials) {
      final key = _platforms.any((p) => p.$1 == s.platform)
          ? s.platform
          : (s.url.isNotEmpty ? 'website' : (s.platform.isEmpty ? 'linkedin' : s.platform));
      final value = s.handle.isNotEmpty ? s.handle : s.url;
      _rowPlatforms.add(key);
      _rowCtrls.add(TextEditingController(text: value));
    }
  }

  @override
  void dispose() {
    for (final c in _rowCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final out = <SocialLink>[];
    for (var i = 0; i < _rowPlatforms.length; i++) {
      final key = _rowPlatforms[i];
      final value = _rowCtrls[i].text.trim();
      if (key == 'website') {
        out.add(SocialLink(platform: 'website', url: value));
      } else {
        out.add(SocialLink(platform: key, handle: value));
      }
    }
    widget.onChanged(out);
  }

  void _addRow() {
    setState(() {
      _rowPlatforms.add('linkedin');
      _rowCtrls.add(TextEditingController());
    });
    _emit();
  }

  void _removeRow(int i) {
    setState(() {
      _rowPlatforms.removeAt(i);
      _rowCtrls.removeAt(i).dispose();
    });
    _emit();
  }

  String _hintFor(String key) =>
      _platforms.firstWhere((p) => p.$1 == key).$3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.link, size: 18, color: theme.hintColor),
              const SizedBox(width: 8),
              Text('Social & web links',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
        ),
        for (var i = 0; i < _rowPlatforms.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 132,
                  child: DropdownButtonFormField<String>(
                    initialValue: _rowPlatforms[i],
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: [
                      for (final p in _platforms)
                        DropdownMenuItem(value: p.$1, child: Text(p.$2)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _rowPlatforms[i] = v);
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rowCtrls[i],
                    onChanged: (_) => _emit(),
                    decoration: InputDecoration(
                      hintText: _hintFor(_rowPlatforms[i]),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove link',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeRow(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add),
            label: const Text('Add link'),
          ),
        ),
      ],
    );
  }
}

