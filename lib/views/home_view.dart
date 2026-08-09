import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ledger_controller.dart';
import '../theme.dart';
import '../utils/calc.dart';
import '../utils/format.dart';
import '../widgets/alert_banner.dart';
import '../widgets/pace_bar.dart';
import '../widgets/tracker_card.dart';

/// The two trackers, and whatever the app currently wants to tell you.
class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.onQuickAdd, this.compact = false});

  final void Function([String? kindId]) onQuickAdd;

  /// True when shown as the pinned second column on a wide screen, where the
  /// call-to-action buttons would be redundant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // watch() rebuilds this subtree whenever the controller notifies —
    // Provider's InheritedWidget doing the plumbing.
    final c = context.watch<LedgerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (c.loading && c.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final progress = c.progress;
    final cur = thisMonth();
    final now = c.monthStats(cur);
    final before = c.monthStats(shiftMonth(cur, -1));
    final delta = now.netSaved - before.netSaved;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (c.error != null) ...[
          Card(
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.cloud_off, color: scheme.onErrorContainer),
              title: Text(c.error!,
                  style: TextStyle(color: scheme.onErrorContainer)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: c.clearError,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        for (final alert in c.alerts) ...[
          AlertBanner(
            alert: alert,
            onTap: alert.opensAdd ? () => onQuickAdd() : null,
          ),
          const SizedBox(height: 12),
        ],

        // Tracker 1 — what is actually in the account right now.
        TrackerCard(
          label: 'In the account',
          amount: c.bank,
          subtitle: '${signedYen(now.moneyIn)} in · ${signedYen(-now.moneyOut)} out this month',
        ),
        const SizedBox(height: 12),

        // Tracker 2 — the savings goal, with the reason attached.
        TrackerCard(
          label: 'Savings stash',
          amount: progress.saved,
          hero: true,
          trailing: Flexible(
            child: Text(
              c.settings.goalName,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaceBar(
                fraction: progress.fraction,
                paceFraction: progress.goal > 0
                    ? progress.expectedByNow / progress.goal
                    : 0,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(progress.fraction * 100).round()}% of ${yen(progress.goal)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    progress.onTrack
                        ? '${yen(progress.aheadBy)} ahead of pace'
                        : '${yen(-progress.aheadBy)} behind pace',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progress.onTrack ? scheme.positive : scheme.negative,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Month ${progress.monthsElapsed} of ${c.settings.goalMonths}'
                '${progress.remainingMonths > 0 ? ' · ${yen(progress.neededPerRemainingMonth)}/month for the remaining ${progress.remainingMonths}' : ' · plan complete'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // This month against last month — the comparison that triggers alerts.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TrackerCard(
                label: 'Saved this month',
                amount: now.netSaved,
                subtitle: before.count == 0
                    ? 'no month before this'
                    : delta == 0
                        ? 'same as last month'
                        : '${signedYen(delta)} vs last month',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TrackerCard(
                label: monthLabel(shiftMonth(cur, -1)),
                amount: before.netSaved,
                subtitle: '${before.count} ${before.count == 1 ? 'entry' : 'entries'}',
              ),
            ),
          ],
        ),

        if (!compact) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => onQuickAdd(
              c.entries.isEmpty ? 'opening' : 'scholarship',
            ),
            icon: const Icon(Icons.add),
            label: Text(
              c.entries.isEmpty
                  ? 'Set your starting bank balance'
                  : 'Log ${yen(c.settings.monthlyTarget)} scholarship',
            ),
          ),
        ],
      ],
    );
  }
}
