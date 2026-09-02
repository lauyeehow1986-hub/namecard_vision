import 'biostat_style.dart';
import 'geometric_style.dart';
import 'harmonograph_style.dart';
import 'style.dart';

/// All fingerprint styles known to the app, keyed by [FingerprintStyle.id].
///
/// New skins register here. [defaultStyle] is what new cards use and what the
/// verification image is rendered with unless a card records a different id.
/// Every registered style is a faithful, deterministic encoding of the full
/// digest — decorative-only skins must not live here (see [FingerprintStyle]).
const FingerprintStyle defaultStyle = BiostatStyle();

/// The skins offered in the editor's picker, in display order.
const List<FingerprintStyle> styles = [
  defaultStyle,
  GeometricStyle(),
  HarmonographStyle(),
];

final Map<String, FingerprintStyle> styleRegistry = {
  for (final s in styles) s.id: s,
};

/// Look up a style by id, falling back to [defaultStyle] for unknown/null ids
/// so an old card (or one made in a newer build with a skin this build lacks)
/// never fails to render.
FingerprintStyle styleById(String? id) => styleRegistry[id] ?? defaultStyle;
