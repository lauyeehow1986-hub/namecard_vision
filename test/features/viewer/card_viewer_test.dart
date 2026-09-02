import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/viewer/card_viewer.dart';
import 'package:namecard_vision/model/card.dart';

void main() {
  const card = NameCard(name: 'Ada Lovelace', org: 'Engine Co');

  testWidgets('pin star toggles and reports the new value', (tester) async {
    bool? reported;
    await tester.pumpWidget(MaterialApp(
      home: CardViewer(card: card, onTogglePin: (v) => reported = v),
    ));

    // Starts unpinned.
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pump();

    expect(reported, isTrue);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('"Set as my card" reports mine and shows the chip',
      (tester) async {
    bool? reported;
    await tester.pumpWidget(MaterialApp(
      home: CardViewer(card: card, onToggleMine: (v) => reported = v),
    ));

    expect(find.text('Your card'), findsNothing);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as my card'));
    await tester.pumpAndSettle();

    expect(reported, isTrue);
    expect(find.text('Your card'), findsOneWidget);
  });

  testWidgets('a received card shows the verify chip only when not mine',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CardViewer(card: card, received: true),
    ));
    expect(find.text('Received — verify the safety code'), findsOneWidget);
    expect(find.text('Your card'), findsNothing);
  });
}
