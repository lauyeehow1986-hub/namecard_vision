import 'package:flutter/material.dart';

import 'backup/backup_service.dart';
import 'data/card_dao.dart';
import 'data/connection.dart';
import 'data/database.dart' hide Card;
import 'contacts/device_contacts.dart';
import 'features/backup/backup_actions.dart';
import 'features/editor/editor_screen.dart';
import 'features/import/contact_import.dart';
import 'features/ocr/scan_card_flow.dart';
import 'features/scanner/scan_result.dart';
import 'features/scanner/scan_screen.dart';
import 'features/viewer/card_viewer.dart';
import 'model/card.dart';
import 'model/fingerprint_hash.dart';
import 'ocr/ocr_scanner.dart';
import 'ui/fingerprint_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(NamecardVisionApp(database: AppDatabase(openAppDatabase())));
}

class NamecardVisionApp extends StatelessWidget {
  final AppDatabase database;

  const NamecardVisionApp({super.key, required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'namecard_vision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A6EA5)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3A6EA5), brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: HomeScreen(dao: database.cardDao),
    );
  }
}

/// Collection home: search, list of cards with their fingerprint thumbnails,
/// and a button to create a new card. The list is the P0 store (Drift + FTS5)
/// made visible; each row's art is re-derived live by [FingerprintView].
class HomeScreen extends StatefulWidget {
  final CardDao dao;

  const HomeScreen({super.key, required this.dao});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  String _query = '';

  late final BackupService _backup = BackupService(widget.dao);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _exportCollection() =>
      BackupActions.export(context, _backup);

  Future<void> _importBackup() async {
    final added = await BackupActions.import(context, _backup);
    if (added && mounted) setState(() {});
  }

  /// Import external contacts — from a .vcf file (e.g. shared over WhatsApp) or
  /// the phone's address book — via a review/selection list.
  Future<void> _importContacts() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('Contact file (.vcf)'),
              subtitle: const Text('e.g. a card shared over WhatsApp'),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
            if (DeviceContacts.platformSupported)
              ListTile(
                leading: const Icon(Icons.contacts_outlined),
                title: const Text('Phone contacts'),
                subtitle: const Text('Pick from your address book'),
                onTap: () => Navigator.of(ctx).pop('phone'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final added = source == 'file'
        ? await ContactImport.fromFile(context, widget.dao)
        : await ContactImport.fromPhone(context, widget.dao);
    if (added > 0 && mounted) setState(() {});
  }

  /// Write every card in the collection into the phone's contacts (one
  /// permission prompt, after a confirmation since it adds many entries).
  Future<void> _exportAllToPhone() async {
    final messenger = ScaffoldMessenger.of(context);
    final cards = await widget.dao.getAll();
    if (!mounted) return;
    if (cards.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No cards to export.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${cards.length} contact'
            '${cards.length == 1 ? '' : 's'} to your phone?'),
        content: const Text(
            'Each card in your collection is added as a new phone contact. '
            'Running this again creates duplicates.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Add all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result =
        await DeviceContacts.saveManyToPhone(cards.map((s) => s.card).toList());
    if (!mounted) return;
    final msg = result.permissionDenied
        ? 'Contacts permission is needed to export.'
        : 'Saved ${result.saved} to phone contacts'
            '${result.failed > 0 ? ' (${result.failed} failed)' : ''}.';
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openEditor(
      {StoredCard? existing, NameCard? prefill, bool isMine = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initial: existing?.card ?? prefill,
          onSave: (card) async {
            await widget.dao.upsert(
              card,
              origin: existing?.origin ?? CardOrigin.created,
              id: existing?.id,
              // Only set the role on creation; editing preserves it.
              isMine: existing == null ? isMine : null,
            );
            if (mounted) setState(() {}); // refresh search results
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// The "+" button asks whether you're adding your own namecard or a contact,
  /// since a card you create (or OCR from a photo) is usually someone else's.
  Future<void> _addCard() async {
    final mine = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('New contact'),
              subtitle: const Text('Someone else’s card'),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('My namecard'),
              subtitle: const Text('Your own card, to share'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mine == null) return;
    await _openEditor(isMine: mine);
  }

  /// Long-press actions on a row: pin/unpin and switch a card between "mine"
  /// and contacts.
  Future<void> _rowActions(StoredCard s) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(s.pinned ? Icons.star : Icons.star_border),
              title: Text(s.pinned ? 'Unpin' : 'Pin to top'),
              onTap: () async {
                await widget.dao.setPinned(s.id, !s.pinned);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              leading:
                  Icon(s.isMine ? Icons.person_outline : Icons.badge_outlined),
              title: Text(s.isMine ? 'Move to contacts' : 'Set as my card'),
              onTap: () async {
                await widget.dao.setMine(s.id, !s.isMine);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Photograph a physical card, OCR it, and open the editor prefilled with the
  /// best-guess fields for the user to review before saving.
  Future<void> _scanPhysicalCard() async {
    final parsed = await scanPhysicalCard(context);
    if (parsed == null || !mounted) return;
    await _openEditor(prefill: parsed);
  }

  /// Open a saved card in the read-only viewer, with edit/delete wired back to
  /// the store. Re-reads the row after an edit so the viewer reflects changes.
  Future<void> _openViewer(StoredCard stored) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardViewer(
          card: stored.card,
          received: stored.origin == CardOrigin.received,
          pinned: stored.pinned,
          isMine: stored.isMine,
          onTogglePin: (v) async {
            await widget.dao.setPinned(stored.id, v);
            if (mounted) setState(() {});
          },
          onToggleMine: (v) async {
            await widget.dao.setMine(stored.id, v);
            if (mounted) setState(() {});
          },
          onCardChanged: (updated) async {
            // A restyle: same row, same content (and thus same fingerprint) —
            // only the skin changes. Preserve avatar/origin/createdAt; leaving
            // isMine absent keeps the role and pin flags untouched.
            await widget.dao.upsert(
              updated,
              origin: stored.origin,
              id: stored.id,
              avatar: stored.avatar,
              createdAt: stored.createdAt,
            );
            if (mounted) setState(() {});
          },
          onEdit: () async {
            await _openEditor(existing: stored);
            if (mounted) Navigator.of(context).pop(); // back to refreshed list
          },
          onDelete: () async {
            await widget.dao.deleteById(stored.id);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Scan (or paste) a card. A Namecard Vision card is confirmed against its
  /// safety code and saved as received; a foreign contact QR (vCard / MeCard)
  /// is opened in the editor, prefilled, for review before saving.
  Future<void> _scan() async {
    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute<ScanResult>(builder: (_) => const ScanScreen()),
    );
    if (result == null || !mounted) return;
    if (!result.appVerified) {
      await _openEditor(prefill: result.card);
      return;
    }
    final card = result.card;
    final fp = Fingerprint.ofCard(card);
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(card.name.trim().isEmpty
            ? 'Add received card?'
            : 'Add ${card.name.trim()}?'),
        content: Text('Safety code: ${fp.safetyCode}\n\n'
            'Confirm this matches the sender before saving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    await widget.dao.upsert(card, origin: CardOrigin.received);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('namecard_vision'),
        actions: [
          if (OcrScanner.platformSupported)
            IconButton(
              tooltip: 'Scan a physical card',
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: _scanPhysicalCard,
            ),
          IconButton(
            tooltip: 'Scan a card',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
          IconButton(
            tooltip: 'Import contacts',
            icon: const Icon(Icons.import_contacts_outlined),
            onPressed: _importContacts,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'export') _exportCollection();
              if (v == 'import') _importBackup();
              if (v == 'toPhone') _exportAllToPhone();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('Export collection…'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('Import backup…'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (DeviceContacts.platformSupported) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'toPhone',
                  child: ListTile(
                    leading: Icon(Icons.contact_phone_outlined),
                    title: Text('Export all to phone contacts…'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search name, org, title, tags, note',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCard,
        icon: const Icon(Icons.add),
        label: const Text('New card'),
      ),
      body: _query.isEmpty
          ? StreamBuilder<List<StoredCard>>(
              stream: widget.dao.watchAll(),
              builder: (context, snap) => _list(snap.data),
            )
          : FutureBuilder<List<StoredCard>>(
              future: widget.dao.search(_query),
              builder: (context, snap) => _list(snap.data),
            ),
    );
  }

  Widget _list(List<StoredCard>? cards) {
    if (cards == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // Search results stay a single flat list across everything.
    if (_query.isNotEmpty) {
      if (cards.isEmpty) return _empty('No cards match "$_query".');
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, i) => _cardTile(cards[i]),
      );
    }

    // Grouped home: favourites on top, then the user's own cards, then contacts.
    final pinned = cards.where((c) => c.pinned).toList();
    final mine = cards.where((c) => !c.pinned && c.isMine).toList();
    final contacts = cards.where((c) => !c.pinned && !c.isMine).toList();

    final children = <Widget>[];
    if (pinned.isNotEmpty) {
      children.add(_header('Pinned', Icons.star));
      children.addAll(pinned.map(_cardTile));
    }
    children.add(_header('My cards', Icons.badge_outlined));
    if (mine.isEmpty) {
      children.add(_addMinePlaceholder());
    } else {
      children.addAll(mine.map(_cardTile));
    }
    if (contacts.isNotEmpty) {
      children.add(_header('Contacts', Icons.contacts_outlined));
      children.addAll(contacts.map(_cardTile));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: children,
    );
  }

  Widget _empty(String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_page_outlined,
                size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      );

  Widget _header(String label, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.8,
                  ),
            ),
          ],
        ),
      );

  /// Shown under "My cards" when the user hasn't marked one yet.
  Widget _addMinePlaceholder() => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add your namecard'),
          subtitle: const Text('The card you share with others'),
          onTap: () => _openEditor(isMine: true),
        ),
      );

  Widget _cardTile(StoredCard s) {
    final subtitle =
        [s.card.title, s.card.org].where((t) => t.isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: SizedBox(
          width: 52,
          height: 52,
          child: FingerprintView(card: s.card, size: 52, showSafetyCode: false),
        ),
        title: Text(s.card.name.isEmpty ? '(unnamed)' : s.card.name),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        trailing: IconButton(
          tooltip: s.pinned ? 'Unpin' : 'Pin to top',
          icon: Icon(s.pinned ? Icons.star : Icons.star_border,
              color: s.pinned ? Theme.of(context).colorScheme.primary : null),
          onPressed: () async {
            await widget.dao.setPinned(s.id, !s.pinned);
            if (mounted) setState(() {});
          },
        ),
        onTap: () => _openViewer(s),
        onLongPress: () => _rowActions(s),
      ),
    );
  }
}
