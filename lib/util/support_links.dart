import 'package:flutter/widgets.dart';

class SupportLink {
  final String name;
  final String url;
  final bool primary;

  const SupportLink({
    required this.name,
    required this.url,
    this.primary = false,
  });
}

class SupportGroup {
  final String title;
  final String subtitle;
  final List<SupportLink> links;

  const SupportGroup({
    required this.title,
    required this.subtitle,
    required this.links,
  });
}

const kKoFiUrl = 'https://ko-fi.com/nokarin';
const kBuyMeACoffeeUrl = 'https://www.buymeacoffee.com/nokarin';
const kOpenCollectiveUrl = 'https://opencollective.com/nokarin';
const kThanksDevUrl = 'https://thanks.dev/u/gh/nokarin-dev';
const kTrakteerUrl = 'https://trakteer.id/nokarin';
const kTakoUrl = 'https://tako.id/nokarin';

const kInternationalSupport = SupportGroup(
  title: 'support.international',
  subtitle: 'support.international_sub',
  links: [
    SupportLink(name: 'Ko-fi', url: kKoFiUrl, primary: true),
    SupportLink(name: 'Buy Me a Coffee', url: kBuyMeACoffeeUrl),
    SupportLink(name: 'Open Collective', url: kOpenCollectiveUrl),
    SupportLink(name: 'thanks.dev', url: kThanksDevUrl),
  ],
);

const kIndonesiaSupport = SupportGroup(
  title: 'support.indonesia',
  subtitle: 'support.indonesia_sub',
  links: [
    SupportLink(name: 'Trakteer', url: kTrakteerUrl, primary: true),
    SupportLink(name: 'Tako', url: kTakoUrl),
  ],
);

bool preferIndonesianSupport(Locale locale) => locale.languageCode == 'id';

List<SupportGroup> supportGroups({required bool indonesiaFirst}) {
  return indonesiaFirst
      ? const [kIndonesiaSupport, kInternationalSupport]
      : const [kInternationalSupport, kIndonesiaSupport];
}
