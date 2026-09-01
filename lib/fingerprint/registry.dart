import 'biostat_style.dart';
import 'style.dart';

/// All fingerprint styles known to the app, keyed by [FingerprintStyle.id].
///
/// New skins register here. [defaultStyle] is what new cards use and what the
/// verification image is rendered with unless a card records a different id.
const FingerprintStyle defaultStyle = BiostatStyle();

final Map<String, FingerprintStyle> styleRegistry = {
  defaultStyle.id: defaultStyle,
};

/// Look up a style by id, falling back to [defaultStyle] for unknown ids so an
/// old card never fails to render.
FingerprintStyle styleById(String? id) =>
    styleRegistry[id] ?? defaultStyle;
