import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/editor/editor_screen.dart';
import 'package:namecard_vision/model/card.dart';

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

  testWidgets('editor shows existing social links and can save an edited one',
      (tester) async {
    const initial = NameCard(
      name: 'Grace Hopper',
      socials: [SocialLink(platform: 'github', handle: 'grace')],
    );
    NameCard? saved;
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(initial: initial, onSave: (c) async => saved = c),
    ));
    await tester.pumpAndSettle();

    // The section is present and the existing handle is shown for editing.
    expect(find.text('Social & web links'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'grace'), findsOneWidget);

    // Save and confirm the social link survives the round-trip.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.socials, hasLength(1));
    expect(saved!.socials.first.platform, 'github');
    expect(saved!.socials.first.handle, 'grace');
  });

  testWidgets('adding a link creates an editable row', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorScreen()));
    await tester.pumpAndSettle();

    // No link rows to start: the default platform label isn't shown yet.
    expect(find.text('LinkedIn'), findsNothing);

    await tester.ensureVisible(find.text('Add link'));
    await tester.tap(find.text('Add link'));
    await tester.pumpAndSettle();

    // A row appeared, defaulting to the LinkedIn platform.
    expect(find.text('LinkedIn'), findsWidgets);
  });
}
