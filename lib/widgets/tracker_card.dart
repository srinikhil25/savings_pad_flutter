import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

/// A headline number with optional supporting detail.
///
/// Stateless by design: it renders exactly what it is given and owns no state,
/// which is the split the responsive-design lecture draws between
/// StatelessWidget and StatefulWidget.
class TrackerCard extends StatelessWidget {
  const TrackerCard({
    super.key,
    required this.label,
    required this.amount,
    this.subtitle,
    this.trailing,
    this.hero = false,
    this.footer,
  });

  final String label;
  final int amount;
  final String? subtitle;
  final Widget? trailing;
  final bool hero;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Expanded so a long goal name wraps instead of overflowing —
                // the classic Row overflow the lecture warns about.
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 6),
            Text(
              yen(amount),
              style: (hero
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: amount < 0 ? scheme.negative : scheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 12),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
