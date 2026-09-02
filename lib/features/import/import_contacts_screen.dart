import 'package:flutter/material.dart';

import '../../model/card.dart';
import '../../model/phone.dart';
import '../../ui/fingerprint_view.dart';

/// A checklist of candidate contacts to import (from a .vcf file or the phone's
/// address book). Pops with the selected [NameCard]s, or null if cancelled.
class ImportContactsScreen extends StatefulWidget {
  final List<NameCard> candidates;
  final String title;

  const ImportContactsScreen({
    super.key,
    required this.candidates,
    this.title = 'Import contacts',
  });

  @override
  State<ImportContactsScreen> createState() => _ImportContactsScreenState();
}

class _ImportContactsScreenState extends State<ImportContactsScreen> {
  late final List<bool> _checked =
      List<bool>.filled(widget.candidates.length, true);

  int get _selectedCount => _checked.where((c) => c).length;
  bool get _allSelected => _selectedCount == widget.candidates.length;

  void _toggleAll() {
    final next = !_allSelected;
    setState(() {
      for (var i = 0; i < _checked.length; i++) {
        _checked[i] = next;
      }
    });
  }

  void _done() {
    final picked = <NameCard>[
      for (var i = 0; i < widget.candidates.length; i++)
        if (_checked[i]) widget.candidates[i],
    ];
    Navigator.of(context).pop(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _toggleAll,
            child: Text(_allSelected ? 'None' : 'All'),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: widget.candidates.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = widget.candidates[i];
          return CheckboxListTile(
            value: _checked[i],
            onChanged: (v) => setState(() => _checked[i] = v ?? false),
            secondary: SizedBox(
              width: 44,
              height: 44,
              child: FingerprintView(card: c, size: 44, showSafetyCode: false),
            ),
            title: Text(c.name.trim().isEmpty ? '(unnamed)' : c.name.trim()),
            subtitle: Text(_subtitle(c), maxLines: 1,
                overflow: TextOverflow.ellipsis),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedCount == 0 ? null : _done,
        backgroundColor: _selectedCount == 0
            ? Theme.of(context).disabledColor
            : null,
        icon: const Icon(Icons.download_done),
        label: Text(_selectedCount == 0
            ? 'Select contacts'
            : 'Import $_selectedCount'),
      ),
    );
  }

  String _subtitle(NameCard c) {
    final org = [c.title, c.org].where((t) => t.trim().isNotEmpty).join(' · ');
    if (org.isNotEmpty) return org;
    if (c.phones.isNotEmpty) return PhoneFormat.toE164(c.phones.first.e164);
    if (c.emails.isNotEmpty) return c.emails.first;
    return 'No details';
  }
}
