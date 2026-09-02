import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namecard_vision/features/share/share_screen.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  const card = NameCard(
    name: 'Ada Lovelace',
    org: 'Engine Co',
    phones: [PhoneNumber(label: 'mobile', e164: '98765432')],
  );

  testWidgets('QR toggles between the app envelope and the web link',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShareScreen(card: card)));

    // Defaults to the verifiable app QR.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.textContaining('re-derives'), findsOneWidget);

    // Switch to the web-link QR: caption changes, QR still renders.
    await tester.tap(find.text('Web QR'));
    await tester.pumpAndSettle();
    expect(find.textContaining('app needed'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
