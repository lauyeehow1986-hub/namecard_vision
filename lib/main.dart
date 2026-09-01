import 'package:flutter/material.dart';

import 'data/card_dao.dart';
import 'data/connection.dart';
import 'data/database.dart' hide Card;
import 'features/editor/editor_screen.dart';
import 'features/scanner/scan_screen.dart';
import 'features/viewer/card_viewer.dart';
import 'model/card.dart';
import 'model/fingerprint_hash.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openEditor({StoredCard? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initial: existing?.card,
          onSave: (card) async {
            await widget.dao.upsert(
              card,
              origin: existing?.origin ?? CardOrigin.created,
              id: existing?.id,
            );
            if (mounted) setState(() {}); // refresh search results
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Open a saved card in the read-only viewer, with edit/delete wired back to
  /// the store. Re-reads the row after an edit so the viewer reflects changes.
  Future<void> _openViewer(StoredCard stored) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardViewer(
          card: stored.card,
          received: stored.origin == CardOrigin.received,
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

  /// Scan (or paste) a shared card, confirm it, and save it as a received card.
  Future<void> _scan() async {
    final card = await Navigator.of(context).push<NameCard>(
      MaterialPageRoute<NameCard>(builder: (_) => const ScanScreen()),
    );
    if (card == null || !mounted) return;
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
          IconButton(
            tooltip: 'Scan a card',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
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
        onPressed: () => _openEditor(),
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
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_page_outlined,
                size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(_query.isEmpty
                ? 'No cards yet — tap "New card" to make one.'
                : 'No cards match "$_query".'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final s = cards[i];
        final subtitle =
            [s.card.title, s.card.org].where((t) => t.isNotEmpty).join(' · ');
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: SizedBox(
              width: 52,
              height: 52,
              child: FingerprintView(
                  card: s.card, size: 52, showSafetyCode: false),
            ),
            title: Text(s.card.name.isEmpty ? '(unnamed)' : s.card.name),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: Text(
              s.fingerprintHex.substring(0, 6),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            onTap: () => _openViewer(s),
          ),
        );
      },
    );
  }
}
