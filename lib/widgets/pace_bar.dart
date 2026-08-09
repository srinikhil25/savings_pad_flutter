import 'package:flutter/material.dart';

import '../theme.dart';

/// Progress toward the goal, with a marker showing where the plan says you
/// should be by now. Being right of the marker means you are ahead.
///
/// Drawn with a Stack over LayoutBuilder rather than a plain
/// LinearProgressIndicator, because the marker has to be positioned as a
/// fraction of the actual painted width.
class PaceBar extends StatelessWidget {
  const PaceBar({
    super.key,
    required this.fraction,
    required this.paceFraction,
  });

  /// How full the bar is, 0..1.
  final double fraction;

  /// Where the on-plan marker sits, 0..1.
  final double paceFraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 12,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                width: width * fraction.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  color: scheme.positive,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (paceFraction > 0)
                Positioned(
                  left: (width * paceFraction.clamp(0.0, 1.0) - 1)
                      .clamp(0.0, width - 2),
                  child: Container(
                    width: 2,
                    height: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
