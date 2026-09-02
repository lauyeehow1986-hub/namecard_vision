// Shared fictional demo cards, imported by both screenshot generators so a
// given person renders with the SAME fingerprint and safety code everywhere in
// the README (the hash depends on every field, tags included).
import 'package:namecard_vision/model/card.dart';

const demoMaya = NameCard(
  name: 'Dr. Maya Chen',
  title: 'Consultant Cardiologist',
  org: 'Harbourfront Heart Centre',
  phones: [PhoneNumber(label: 'mobile', e164: '+6591234567')],
  emails: ['maya.chen@example.com'],
  socials: [
    SocialLink(platform: 'linkedin', handle: 'maya-chen'),
    SocialLink(platform: 'github', handle: 'mayachen'),
  ],
  tags: ['cardiology', 'research'],
);

const demoArjun = NameCard(
  name: 'Arjun Rao',
  title: 'Staff Data Scientist',
  org: 'Novena Analytics',
  phones: [PhoneNumber(label: 'mobile', e164: '+6598887766')],
  emails: ['arjun@example.org'],
  socials: [
    SocialLink(platform: 'x', handle: 'arjunrao'),
    SocialLink(platform: 'website', url: 'arjun.example.dev'),
  ],
  tags: ['ml', 'python'],
  styleId: 'geometric.v1',
);

const demoSofia = NameCard(
  name: 'Sofia Almeida',
  title: 'Principal Product Designer',
  org: 'Studio Lumen',
  phones: [PhoneNumber(label: 'mobile', e164: '+6590011223')],
  emails: ['sofia@example.net'],
  socials: [SocialLink(platform: 'instagram', handle: 'sofia.designs')],
  tags: ['design', 'brand'],
  styleId: 'harmonograph.v1',
);

const demoWei = NameCard(
  name: 'Wei Lin',
  title: 'Security Engineer',
  org: 'Redwall Labs',
  phones: [PhoneNumber(label: 'mobile', e164: '+6593334455')],
  emails: ['wei@example.io'],
  socials: [SocialLink(platform: 'github', handle: 'weilin')],
  tags: ['appsec'],
  styleId: 'randomart.v1',
);
