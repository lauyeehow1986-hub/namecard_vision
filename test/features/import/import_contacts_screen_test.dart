import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/import/import_contacts_screen.dart';
import 'package:namecard_vision/model/card.dart';

void main() {
  const candidates = [
    NameCard(name: 'Ada Lovelace', org: 'Engine Co'),
    NameCard(name: 'Alan Turing', org: 'Bletchley'),
    NameCard(name: 'Grace Hopper'),
  ];

  Future<List<NameCard>?> run(WidgetTester tester) async {
    List<NameCard>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<List<NameCard>>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ImportContactsScreen(candidates: candidates),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('all selected by default; imports every candidate',
      (tester) async {
    await run(tester);
    expect(find.text('Import 3'), findsOneWidget);
    await tester.tap(find.text('Import 3'));
    await tester.pumpAndSettle();
    // Popped back to the launcher.
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('deselecting one reduces the import count', (tester) async {
    await run(tester);
    await tester.tap(find.text('Alan Turing'));
    await tester.pump();
    expect(find.text('Import 2'), findsOneWidget);
  });

  testWidgets('"None" clears the selection and disables import',
      (tester) async {
    await run(tester);
    await tester.tap(find.text('None'));
    await tester.pump();
    expect(find.text('Select contacts'), findsOneWidget);
  });
}
