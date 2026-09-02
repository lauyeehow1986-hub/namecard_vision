import '../../model/card.dart';

/// The outcome of a scan / manual entry.
///
/// [appVerified] is true when the payload was a Namecard Vision card (its
/// fingerprint + safety code can be verified against the sender); false when it
/// was an imported foreign contact (vCard / MeCard), which the app opens in the
/// editor for review rather than showing a safety-code confirmation.
class ScanResult {
  final NameCard card;
  final bool appVerified;

  const ScanResult(this.card, {required this.appVerified});
}
