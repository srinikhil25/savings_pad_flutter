import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils/calc.dart';

/// The reason the app exists: it tells you when a month is going the wrong way
/// without being asked.
///
/// StatefulWidget purely so the vibration motor (Lecture 07) can be pulsed
/// once when a danger-level alert first appears — not on every rebuild.
class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key, required this.alert, this.onTap});

  final LedgerAlert alert;
  final VoidCallback? onTap;

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  @override
  void initState() {
    super.initState();
    _buzzIfSerious();
  }

  @override
  void didUpdateWidget(AlertBanner old) {
    super.didUpdateWidget(old);
    if (old.alert.id != widget.alert.id) _buzzIfSerious();
  }

  /// HapticFeedback drives the linear vibration motor described in Lecture 07.
  /// It is a no-op on platforms without one, so no capability check is needed.
  void _buzzIfSerious() {
    if (widget.alert.level == AlertLevel.danger) {
      HapticFeedback.heavyImpact();
    } else if (widget.alert.level == AlertLevel.warning) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (Color colour, IconData icon) = switch (widget.alert.level) {
      AlertLevel.danger => (scheme.negative, Icons.error_outline),
      AlertLevel.warning => (scheme.caution, Icons.warning_amber_outlined),
      AlertLevel.good => (scheme.positive, Icons.check_circle_outline),
      AlertLevel.info => (scheme.onSurfaceVariant, Icons.info_outline),
    };

    return Card(
      color: colour.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colour.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colour, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.alert.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: colour, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.alert.detail,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (widget.onTap != null)
                Icon(Icons.chevron_right, color: colour, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
