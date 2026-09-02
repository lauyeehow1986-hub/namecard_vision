import '../model/card.dart';
import '../model/fingerprint_hash.dart';
import 'web_link.dart';

/// Composes the "reply with your card" hand-back — a static, backend-free way
/// for a web viewer to send *their* card back to the sender.
///
/// The web page has no server to receive data, so the reply is delivered
/// through a channel that is **already on the sender's card** (their email,
/// WhatsApp, or SMS). The recipient's card is encoded as its own web-profile
/// [WebLink]; the sender opens it, sees the recipient's fingerprint + safety
/// code, and saves it — closing the exchange loop with no accounts and no
/// backend. This class is pure so the message + channel URIs are unit-testable.
class ReplyMessage {
  /// The recipient's own web-profile link (the sender will open this).
  final String link;

  /// The recipient card's safety code, quoted in the message so the sender can
  /// eyeball-verify what they receive.
  final String safetyCode;

  /// The plain-text message body (link + verify hint).
  final String body;

  /// `mailto:` to the sender, prefilled, or null if their card has no email.
  final Uri? email;

  /// `https://wa.me/…?text=…` to the sender, or null if no phone.
  final Uri? whatsApp;

  /// `sms:` to the sender with a prefilled body, or null if no phone.
  final Uri? sms;

  const ReplyMessage._({
    required this.link,
    required this.safetyCode,
    required this.body,
    this.email,
    this.whatsApp,
    this.sms,
  });

  /// True when the sender's card exposed at least one direct return channel.
  bool get hasDirectChannel => email != null || whatsApp != null || sms != null;

  /// Build the reply from the [recipient]'s freshly-entered card back to the
  /// [sender] card being viewed.
  factory ReplyMessage.build(
    NameCard recipient,
    NameCard sender, {
    String base = WebLink.base,
  }) {
    final link = WebLink.forCard(recipient, base: base);
    final safety = Fingerprint.ofCard(recipient).safetyCode;
    final who = recipient.name.trim().isEmpty ? 'my' : "${recipient.name}'s";
    final body = "Here's $who card: $link\n\n"
        'Open it in Namecard Vision to verify · safety code $safety';

    Uri? email;
    if (sender.emails.isNotEmpty) {
      email = Uri(
        scheme: 'mailto',
        path: sender.emails.first.trim(),
        query: _query({
          'subject': 'My Namecard Vision card',
          'body': body,
        }),
      );
    }

    Uri? whatsApp;
    Uri? sms;
    if (sender.phones.isNotEmpty) {
      final e164 = sender.phones.first.e164;
      final digits = e164.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        whatsApp = Uri.parse(
            'https://wa.me/$digits?text=${Uri.encodeComponent(body)}');
      }
      final dialable =
          '${e164.trim().startsWith('+') ? '+' : ''}$digits';
      sms = Uri(
        scheme: 'sms',
        path: dialable,
        query: _query({'body': body}),
      );
    }

    return ReplyMessage._(
      link: link,
      safetyCode: safety,
      body: body,
      email: email,
      whatsApp: whatsApp,
      sms: sms,
    );
  }

  /// Encode a query map the way `mailto:`/`sms:` expect (RFC 6068 / RFC 5724):
  /// `%20` for spaces rather than `+`, which `Uri(queryParameters:)` would use.
  static String _query(Map<String, String> params) => params.entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
