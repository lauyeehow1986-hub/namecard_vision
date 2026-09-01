import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/editor/editor_screen.dart';

void main() {
  testWidgets('editor live-preview reacts to typing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorScreen()));
    await tester.pumpAndSettle();

    // Blank card shows the placeholder title in the preview panel.
    expect(find.text('(unnamed card)'), findsOneWidget);

    // Typing a name updates the live preview title.
    await tester.enterText(
        find.widgetWithText(TextField, 'Name'), 'Grace Hopper');
    await tester.pump();

    expect(find.text('(unnamed card)'), findsNothing);
    // 'Grace Hopper' now appears in both the text field and the live preview
    // title — the preview reacting is exactly what we want to prove.
    expect(find.text('Grace Hopper'), findsWidgets);
  });
}
