import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

import '../model/card.dart';
import 'envelope.dart';

/// Tap-to-share over NFC. The tag carries the *same* `NCV1` share envelope as
/// the QR path — a single MIME record (`application/vnd.namecard.vision`) whose
/// payload is the base45 envelope text — so a received card recomputes the
/// sender's fingerprint and safety code exactly as a scanned QR would. The art
/// is never on the tag; it is always re-derived on receipt.
///
/// Device-only: nothing here runs on web or in host tests. Every entry point is
/// defensive so an unsupported device degrades to a clear message rather than a
/// crash.
class NfcShare {
  static const String mimeType = 'application/vnd.namecard.vision';

  const NfcShare._();

  /// Whether the NFC plugin even exists on this platform. NFC is a mobile-only
  /// feature; on web/desktop the plugin throws, so the UI must gate on this
  /// before offering an NFC option or calling [availability].
  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether this device can do NFC at all (and whether it is switched on).
  /// Returns [NfcAvailability.unsupported] on platforms without the plugin.
  static Future<NfcAvailability> availability() {
    if (!platformSupported) return Future.value(NfcAvailability.unsupported);
    return NfcManager.instance.checkAvailability();
  }

  /// Build the NDEF message that encodes [card].
  static NdefMessage messageFor(NameCard card) {
    final payload = utf8.encode(ShareEnvelope.encode(card));
    return NdefMessage(records: [
      NdefRecord(
        typeNameFormat: TypeNameFormat.media,
        type: Uint8List.fromList(utf8.encode(mimeType)),
        identifier: Uint8List(0),
        payload: Uint8List.fromList(payload),
      ),
    ]);
  }

  /// Extract a [NameCard] from a tapped [message], or null if it carries no
  /// namecard_vision record. Foreign tags simply return null.
  static NameCard? cardFrom(NdefMessage? message) {
    if (message == null) return null;
    for (final r in message.records) {
      if (r.typeNameFormat != TypeNameFormat.media) continue;
      if (utf8.decode(r.type, allowMalformed: true) != mimeType) continue;
      try {
        return ShareEnvelope.decode(utf8.decode(r.payload));
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  /// Start a session that writes [card] to the next writable tag tapped.
  /// [onWritten] fires once on success; [onError] on any failure. Call
  /// [stop] to cancel. iOS shows the system sheet with [promptIos].
  static Future<void> hostCard(
    NameCard card, {
    required void Function() onWritten,
    required void Function(String message) onError,
    String promptIos = 'Hold near the other phone or an NFC tag to share.',
  }) async {
    final message = messageFor(card);
    await _startSession(
      promptIos: promptIos,
      onDiscovered: (tag) async {
        try {
          if (defaultTargetPlatform == TargetPlatform.android) {
            final ndef = NdefAndroid.from(tag);
            if (ndef == null) {
              throw const _NfcFailure('That tag does not support NDEF.');
            }
            if (!ndef.isWritable) {
              throw const _NfcFailure('That tag is read-only.');
            }
            if (ndef.maxSize < message.byteLength) {
              throw const _NfcFailure('The card is too large for that tag.');
            }
            await ndef.writeNdefMessage(message);
          } else {
            final ndef = NdefIos.from(tag);
            if (ndef == null) {
              throw const _NfcFailure('That tag does not support NDEF.');
            }
            await ndef.writeNdef(message);
          }
          onWritten();
        } on _NfcFailure catch (e) {
          onError(e.message);
        } catch (e) {
          onError('Could not write to that tag.');
        } finally {
          await stop();
        }
      },
      onError: onError,
    );
  }

  /// Start a session that reads a card from the next tag tapped. [onRead] fires
  /// with the decoded card; [onForeign] if the tag holds no namecard_vision
  /// record; [onError] on failure.
  static Future<void> readCard({
    required void Function(NameCard card) onRead,
    required void Function() onForeign,
    required void Function(String message) onError,
    String promptIos = 'Hold near the other phone or an NFC tag to receive.',
  }) async {
    await _startSession(
      promptIos: promptIos,
      onDiscovered: (tag) async {
        try {
          final NdefMessage? msg;
          if (defaultTargetPlatform == TargetPlatform.android) {
            msg = await NdefAndroid.from(tag)?.getNdefMessage();
          } else {
            msg = await NdefIos.from(tag)?.readNdef();
          }
          final card = cardFrom(msg);
          if (card == null) {
            onForeign();
          } else {
            onRead(card);
          }
        } catch (e) {
          onError('Could not read that tag.');
        } finally {
          await stop();
        }
      },
      onError: onError,
    );
  }

  /// Stop any running session.
  static Future<void> stop() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Nothing to stop / already stopped.
    }
  }

  static Future<void> _startSession({
    required void Function(NfcTag tag) onDiscovered,
    required void Function(String message) onError,
    required String promptIos,
  }) async {
    final availability = await NfcShare.availability();
    switch (availability) {
      case NfcAvailability.enabled:
        break;
      case NfcAvailability.disabled:
        onError('NFC is turned off. Enable it in settings and try again.');
        return;
      case NfcAvailability.unsupported:
        onError('This device does not support NFC.');
        return;
    }
    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: promptIos,
        onDiscovered: onDiscovered,
      );
    } catch (e) {
      onError('Could not start NFC. Try again.');
    }
  }
}

class _NfcFailure implements Exception {
  final String message;
  const _NfcFailure(this.message);
}
