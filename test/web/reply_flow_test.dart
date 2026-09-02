import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/web/web_card_page.dart';
import 'package:namecard_vision/model/card.dart';

void main() {
  testWidgets('Reply -> editor -> save opens the reply sheet', (tester) async {
    const sender = NameCard(
      name: 'Dr Yee How Lau',
      org: 'NHCS',
      emails: ['yh@example.org'],
      phones: [PhoneNumber(label: 'mobile', e164: '+6598765432')],
    );
    await tester.pumpWidget(
      const MaterialApp(home: WebCardPage(card: sender)),
    );

    await tester.tap(find.text('Reply with your card'));
    await tester.pumpAndSettle();
    expect(find.text('New card'), findsOneWidget);

    // Type a name into the first field.
    await tester.enterText(find.byType(TextField).first, 'Alan Turing');
    await tester.pump();

    // Tap the save check in the editor app bar.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // The reply sheet should now be up.
    expect(find.text('Send your card back'), findsOneWidget);
  });
}
