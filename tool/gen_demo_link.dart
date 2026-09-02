// Prints a working web-viewer link for a sample card, using the app's own
// encoder — handy for demoing the hosted viewer without a phone.
//   dart run tool/gen_demo_link.dart
import 'package:namecard_vision/model/card.dart';
import 'package:namecard_vision/web/web_link.dart';

void main() {
  const card = NameCard(
    name: 'Dr Yee How Lau',
    title: 'Cardiology & Health Informatics',
    org: 'National Heart Centre Singapore',
    phones: [PhoneNumber(label: 'mobile', e164: '+6598765432')],
    emails: ['lauyeehow1986@gmail.com'],
    socials: [
      SocialLink(platform: 'linkedin', handle: 'yeehowlau'),
      SocialLink(platform: 'github', handle: 'lauyeehow1986-hub'),
    ],
    note: 'Not for diagnosis — a demo namecard.',
  );
  // ignore: avoid_print
  print(WebLink.forCard(card));
}
