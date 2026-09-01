import 'package:flutter/material.dart';

import '../fingerprint/registry.dart';
import '../fingerprint/style.dart';
import '../model/card.dart';
import '../model/fingerprint_hash.dart';

/// Renders a card's fingerprint art plus its human-readable safety code.
///
/// The art is always re-derived from the card here (never cached/transmitted) —
/// that is exactly what makes it a verification image: what you see is a pure
/// function of the bytes in front of you.
class FingerprintView extends StatelessWidget {
  final NameCard card;
  final double size;
  final bool showSafetyCode;
  final FingerprintStyle? style;

  const FingerprintView({
    super.key,
    required this.card,
    this.size = 220,
    this.showSafetyCode = true,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final fp = Fingerprint.ofCard(card);
    final s = style ?? defaultStyle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _FingerprintPainter(s, fp),
            isComplex: true,
          ),
        ),
        if (showSafetyCode) ...[
          const SizedBox(height: 10),
          Text(
            fp.safetyCode,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
              fontFamily: 'monospace',
              letterSpacing: 2,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'safety code',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).hintColor, letterSpacing: 1),
          ),
        ],
      ],
    );
  }
}

class _FingerprintPainter extends CustomPainter {
  final FingerprintStyle style;
  final Fingerprint fp;

  _FingerprintPainter(this.style, this.fp);

  @override
  void paint(Canvas canvas, Size size) => style.paint(canvas, size, fp.digest);

  @override
  bool shouldRepaint(_FingerprintPainter old) =>
      old.fp != fp || old.style.id != style.id;
}
