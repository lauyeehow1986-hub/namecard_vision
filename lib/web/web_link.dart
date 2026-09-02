import '../model/card.dart';
import '../share/envelope.dart';

/// Builds and parses the hosted web-profile link.
///
/// The card rides in the URL **fragment** (everything after `#`), which a
/// browser never sends to the server — so the host (GitHub Pages) never sees
/// any card data; it is decoded entirely in the recipient's browser. The
/// payload is the same verifiable `NCV1` [ShareEnvelope] used by QR/NFC/BLE, so
/// the web viewer re-derives the sender's fingerprint + safety code exactly.
/// That is the verification, now in a browser and with no backend.
class WebLink {
  WebLink._();

  /// The hosted viewer's base URL (GitHub Pages). Only freshly-built links carry
  /// it; nothing stored references it, so moving to a custom domain later is a
  /// one-line change rather than a data migration.
  static const String base =
      'https://lauyeehow1986-hub.github.io/namecard_vision/';

  /// A shareable web-profile URL for [card]. The envelope is percent-encoded so
  /// the base45 text (which can contain `%`, spaces, `+`, `/`) is a valid URL
  /// fragment; [cardFromUri] reverses it.
  static String forCard(NameCard card, {String base = WebLink.base}) {
    final envelope = ShareEnvelope.encode(card);
    return '$base#${Uri.encodeComponent(envelope)}';
  }

  /// Decode the card from a full viewer [uri], or null if it carries none.
  static NameCard? cardFromUri(Uri uri) => _decode(uri.fragment);

  /// Decode from a raw fragment string (the part after `#`), or null.
  static NameCard? cardFromFragment(String fragment) => _decode(fragment);

  static NameCard? _decode(String fragment) {
    var f = fragment.trim();
    if (f.isEmpty) return null;
    // Unlike query parameters, `Uri.fragment` (and a browser's location.hash)
    // return the fragment *still percent-encoded*, so reverse forCard's
    // encoding here. If it isn't valid percent-encoding, use it verbatim.
    try {
      f = Uri.decodeComponent(f);
    } on ArgumentError {
      // Not percent-encoded — fall through with the raw text.
    } on FormatException {
      // Malformed escape — fall through with the raw text.
    }
    try {
      return ShareEnvelope.decode(f);
    } on FormatException {
      return null;
    }
  }
}
