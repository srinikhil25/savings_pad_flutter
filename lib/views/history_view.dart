import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ledger_controller.dart';
import '../models/entry.dart';
import '../models/entry_kind.dart';
import '../services/receipt_camera.dart';
import '../theme.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

/// Month-by-month rollup, each expandable to the individual entries.
class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LedgerController>();
    final theme = Theme.of(context);

    if (c.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Nothing logged yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Add your first entry and this fills in month by month.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final months = c.months;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final key = months[i];
        final stats = c.monthStats(key);
        final prev = c.monthStats(shiftMonth(key, -1));
        final delta = stats.netSaved - prev.netSaved;
        final rows = c.entriesIn(key);

        return Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: i == 0,
            title: Text(monthLabel(key), style: theme.textTheme.titleMedium),
            subtitle: Text(
              '${yen(stats.netSaved)} saved · ${stats.count} '
              '${stats.count == 1 ? 'entry' : 'entries'}',
            ),
            trailing: prev.count == 0
                ? null
                : Text(
                    delta == 0 ? 'level' : signedYen(delta),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: delta >= 0
                          ? theme.colorScheme.positive
                          : theme.colorScheme.negative,
                    ),
                  ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _Stat(label: 'In', value: stats.moneyIn),
                    _Stat(label: 'Out', value: stats.moneyOut),
                    _Stat(label: 'To savings', value: stats.savedIn),
                    _Stat(label: 'From savings', value: stats.savedOut),
                  ],
                ),
              ),
              for (final e in rows) _EntryTile(entry: e),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(yen(value), style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = EntryKind.of(entry);
    final arriving = entry.from.isOutside;

    return ListTile(
      leading: CircleAvatar(
        radius: 6,
        backgroundColor: switch (kind.tone) {
          Tone.positive => scheme.positive,
          Tone.warning => scheme.negative,
          Tone.neutral => scheme.onSurfaceVariant,
        },
      ),
      title: Text(kind.label),
      subtitle: Text(
        '${dayLabel(entry.date)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.hasReceipt)
            IconButton(
              icon: const Icon(Icons.receipt_outlined),
              tooltip: 'View receipt',
              onPressed: () => _showReceipt(context, entry),
            ),
          Text(
            yen(entry.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              color: arriving ? scheme.positive : scheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, entry),
          ),
        ],
      ),
    );
  }

  void _showReceipt(BuildContext context, Entry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(ReceiptCamera.decode(entry.receiptPhoto!)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Entry entry) async {
    final controller = context.read<LedgerController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('${yen(entry.amount)} on ${dayLabel(entry.date)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteEntry(entry.id);
  }
}
