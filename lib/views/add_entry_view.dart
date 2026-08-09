import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/ledger_controller.dart';
import '../models/entry.dart';
import '../models/entry_kind.dart';
import '../services/receipt_camera.dart';
import '../theme.dart';
import '../utils/calc.dart';
import '../utils/format.dart';

/// StatefulWidget because a form is the textbook case for local mutable state:
/// the typed amount belongs to this screen and nothing else needs to see it
/// until Save is pressed.
class AddEntryView extends StatefulWidget {
  const AddEntryView({super.key, this.presetKindId, required this.onDone});

  final String? presetKindId;
  final VoidCallback onDone;

  @override
  State<AddEntryView> createState() => _AddEntryViewState();
}

class _AddEntryViewState extends State<AddEntryView> {
  late EntryKind _kind = EntryKind.byId(widget.presetKindId ?? 'scholarship');
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _receiptPhoto;
  bool _busy = false;
  bool _amountTouched = false;

  @override
  void initState() {
    super.initState();
    _applyDefaultAmount();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// The scholarship is always the same number, so pre-fill it — but never
  /// clobber something the user has already typed.
  void _applyDefaultAmount() {
    if (_amountTouched) return;
    final target = context.read<LedgerController>().settings.monthlyTarget;
    _amountController.text = _kind.id == 'scholarship' ? '$target' : '';
  }

  int get _amount => int.tryParse(_amountController.text.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

  bool get _valid => _amount > 0;

  Future<void> _pickPhoto({required bool fromGallery}) async {
    try {
      final photo = await ReceiptCamera().capture(fromGallery: fromGallery);
      if (photo != null && mounted) setState(() => _receiptPhoto = photo);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera unavailable: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);

    final controller = context.read<LedgerController>();
    final error = await controller.addEntry(
      kind: _kind,
      amount: _amount,
      date: _date,
      note: _noteController.text,
      receiptPhoto: _receiptPhoto,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${yen(_amount)} — ${_kind.label.toLowerCase()}')),
    );
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LedgerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('What happened?', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),

        for (final group in KindGroup.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              group.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          // Wrap reflows the chips onto as many lines as the width needs,
          // so the same code fits a phone and a desktop window.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in EntryKind.inGroup(group))
                ChoiceChip(
                  label: Text(k.label),
                  selected: _kind.id == k.id,
                  onSelected: (_) => setState(() {
                    _kind = k;
                    _applyDefaultAmount();
                  }),
                  selectedColor: switch (k.tone) {
                    Tone.warning => scheme.negative.withValues(alpha: 0.2),
                    _ => scheme.primaryContainer,
                  },
                ),
            ],
          ),
        ],

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(_kind.hint,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),

        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '¥ ',
          ),
          onChanged: (_) => setState(() => _amountTouched = true),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final v in <int>{c.settings.monthlyTarget, 10000, 20000, 50000})
              ActionChip(
                label: Text(plain(v)),
                onPressed: () => setState(() {
                  _amountTouched = true;
                  _amountController.text = '$v';
                }),
              ),
          ],
        ),

        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: const Text('Date'),
          subtitle: Text(dayLabel(_date)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(DateTime.now().year - 3),
              lastDate: DateTime(DateTime.now().year + 3),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),

        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. konbini shift, October rent',
          ),
        ),

        const SizedBox(height: 20),
        _ReceiptSection(
          photo: _receiptPhoto,
          onCamera: () => _pickPhoto(fromGallery: false),
          onGallery: () => _pickPhoto(fromGallery: true),
          onRemove: () => setState(() => _receiptPhoto = null),
        ),

        const SizedBox(height: 20),
        if (_valid) _Preview(kind: _kind, amount: _amount),

        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _valid && !_busy ? _save : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_valid ? 'Save ${yen(_amount)}' : 'Enter an amount'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: widget.onDone, child: const Text('Cancel')),
      ],
    );
  }
}

/// Lecture 07 in the UI: capture a receipt with the device camera.
class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.photo,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final String? photo;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt (optional)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Taken with the device camera and stored with the entry.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  ReceiptCamera.decode(photo!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(ReceiptCamera.sizeLabel(photo!),
                      style: theme.textTheme.bodySmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCamera,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the consequence of the entry before it is committed — the thing that
/// makes the shortfall alert actionable rather than a post-mortem.
class _Preview extends StatelessWidget {
  const _Preview({required this.kind, required this.amount});

  final EntryKind kind;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LedgerController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bankDelta = kind.to == Ref.bank
        ? amount
        : kind.from == Ref.bank
            ? -amount
            : 0;
    final savedDelta = kind.to == Ref.savings
        ? amount
        : kind.from == Ref.savings
            ? -amount
            : 0;

    final bankAfter = c.bank + bankDelta;
    final cur = thisMonth();
    final savedAfter = c.monthStats(cur).netSaved + savedDelta;
    final lastMonth = c.monthStats(shiftMonth(cur, -1));
    final overdrawn = bankAfter < 0;

    return Card(
      color: overdrawn
          ? scheme.negative.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account: ${yen(bankAfter)} after this',
              style: theme.textTheme.titleSmall?.copyWith(
                color: overdrawn ? scheme.negative : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              overdrawn
                  ? 'That takes the account below zero — check the amount.'
                  : lastMonth.count > 0
                      ? 'Month total would be ${yen(savedAfter)} vs ${yen(lastMonth.netSaved)} last month.'
                      : 'Saved this month would be ${yen(savedAfter)}.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
