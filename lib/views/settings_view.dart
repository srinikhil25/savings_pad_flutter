import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/ledger_controller.dart';
import '../utils/format.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _goalName;
  late final TextEditingController _target;
  late final TextEditingController _months;

  @override
  void initState() {
    super.initState();
    final s = context.read<LedgerController>().settings;
    _goalName = TextEditingController(text: s.goalName);
    _target = TextEditingController(text: '${s.monthlyTarget}');
    _months = TextEditingController(text: '${s.goalMonths}');
  }

  @override
  void dispose() {
    _goalName.dispose();
    _target.dispose();
    _months.dispose();
    super.dispose();
  }

  void _save() {
    final c = context.read<LedgerController>();
    c.updateSettings(c.settings.copyWith(
      goalName: _goalName.text.trim().isEmpty ? 'My goal' : _goalName.text.trim(),
      monthlyTarget: int.tryParse(_target.text) ?? c.settings.monthlyTarget,
      goalMonths: int.tryParse(_months.text) ?? c.settings.goalMonths,
    ));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Plan updated')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LedgerController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('The plan', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _goalName,
          decoration: const InputDecoration(
            labelText: "What you're saving for",
            hintText: "e.g. Parents' trip tickets",
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _target,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Monthly target',
                  prefixText: '¥ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _months,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Months'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Goal: ${yen(c.settings.goal)} over ${c.settings.goalMonths} months.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Save plan')),

        const Divider(height: 40),

        Text('Account', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(c.user?.email ?? 'Not signed in'),
          subtitle: const Text('Sign in with the same account on every device'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: const Text('Sync'),
          subtitle: Text(
            c.error ?? 'Firestore keeps every signed-in device in step, '
                'and queues changes while offline.',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => c.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '${c.entries.length} entries · Savings Pad',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
