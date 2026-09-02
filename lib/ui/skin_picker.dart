import 'package:flutter/material.dart';

import '../fingerprint/registry.dart';
import '../model/card.dart';
import 'fingerprint_view.dart';

/// A row of tappable thumbnails — one per registered art skin — each rendering
/// the *current* card so the choice previews live. Selecting a skin only
/// changes how the card is drawn; the safety code (content hash) is unchanged.
///
/// Shared by the editor (pick a skin while creating/editing) and the card
/// viewer (restyle a saved card without opening the editor).
class SkinPicker extends StatelessWidget {
  final NameCard card;

  /// The chosen skin id, or null for the default skin.
  final String? selectedStyleId;
  final ValueChanged<String> onSelected;

  /// Thumbnail edge in logical pixels.
  final double thumbSize;

  const SkinPicker({
    super.key,
    required this.card,
    required this.selectedStyleId,
    required this.onSelected,
    this.thumbSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveId = selectedStyleId ?? defaultStyle.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ART SKIN',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.hintColor, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in styles)
              _SkinThumb(
                label: s.label,
                selected: s.id == effectiveId,
                onTap: () => onSelected(s.id),
                // Render this specific skin for the current card, no code.
                child: FingerprintView(
                  card: card,
                  size: thumbSize,
                  style: s,
                  showSafetyCode: false,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SkinThumb extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SkinThumb({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label art skin',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  width: selected ? 2.5 : 1,
                  color: selected ? accent : theme.dividerColor,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: child,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? accent : theme.hintColor,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
