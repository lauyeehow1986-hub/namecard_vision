import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/model/fingerprint_hash.dart';
import 'package:namecard_vision/share/nfc_share.dart';

void main() {
  group('NfcShare envelope', () {
    const card = NameCard(
      name: 'Grace Hopper',
      title: 'Rear Admiral',
      org: 'US Navy',
      phones: [PhoneNumber(label: 'mobile', e164: '+15125550143')],
      emails: ['grace@navy.example'],
      tags: ['compiler'],
    );

    test('messageFor produces one namecard MIME record', () {
      final msg = NfcShare.messageFor(card);
      expect(msg.records.length, 1);
      final r = msg.records.single;
      expect(r.typeNameFormat, TypeNameFormat.media);
      expect(utf8.decode(r.type), NfcShare.mimeType);
      expect(r.payload, isNotEmpty);
    });

    test('cardFrom(messageFor(card)) recomputes the same fingerprint', () {
      final decoded = NfcShare.cardFrom(NfcShare.messageFor(card));
      expect(decoded, isNotNull);
      expect(decoded, card); // value-equal
      expect(
        Fingerprint.ofCard(decoded!).hex,
        Fingerprint.ofCard(card).hex,
      );
    });

    test('cardFrom ignores a foreign (non-namecard) record', () {
      final foreign = NdefMessage(records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode('text/plain')),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode('hello')),
        ),
      ]);
      expect(NfcShare.cardFrom(foreign), isNull);
    });

    test('cardFrom returns null for a null or empty message', () {
      expect(NfcShare.cardFrom(null), isNull);
      expect(NfcShare.cardFrom(const NdefMessage(records: [])), isNull);
    });

    test('cardFrom returns null when our MIME record holds garbage', () {
      final corrupt = NdefMessage(records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.media,
          type: Uint8List.fromList(utf8.encode(NfcShare.mimeType)),
          identifier: Uint8List(0),
          payload: Uint8List.fromList(utf8.encode('!!! not base45 !!!')),
        ),
      ]);
      expect(NfcShare.cardFrom(corrupt), isNull);
    });
  });
}
