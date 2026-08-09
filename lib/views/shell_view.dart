import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ledger_controller.dart';
import 'add_entry_view.dart';
import 'history_view.dart';
import 'home_view.dart';
import 'settings_view.dart';

/// RESPONSIVE DESIGN (Lecture 04-05).
///
/// One widget tree, three layouts, chosen by available width — not by
/// platform. Resizing the desktop window or rotating the phone moves between
/// them live, because LayoutBuilder rebuilds on every constraint change.
///
///   < 600px   phone      bottom navigation bar, one screen at a time
///   600-1000  tablet     navigation rail beside the content
///   > 1000px  desktop    navigation rail + Home pinned as a second column
class ShellView extends StatefulWidget {
  const ShellView({super.key});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  int _index = 0;

  static const _destinations = [
    _Destination('Home', Icons.savings_outlined, Icons.savings),
    _Destination('Add', Icons.add_circle_outline, Icons.add_circle),
    _Destination('History', Icons.receipt_long_outlined, Icons.receipt_long),
    _Destination('Setup', Icons.settings_outlined, Icons.settings),
  ];

  /// Set when Home sends you to the Add screen with a kind already chosen.
  String? _pendingKindId;

  void _go(int index) => setState(() {
        if (index != 1) _pendingKindId = null;
        _index = index;
      });

  void _openAdd([String? kindId]) {
    setState(() {
      _pendingKindId = kindId;
      _index = 1;
    });
  }

  Widget _page(int index) {
    return switch (index) {
      0 => HomeView(onQuickAdd: _openAdd),
      1 => AddEntryView(
          key: ValueKey(_pendingKindId),
          presetKindId: _pendingKindId,
          onDone: () => _go(0),
        ),
      2 => const HistoryView(),
      _ => const SettingsView(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final needsAttention =
        context.select<LedgerController, bool>((c) => c.needsAttention);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isPhone = width < 600;
        final isDesktop = width >= 1000;

        final body = _page(_index);

        if (isPhone) {
          return Scaffold(
            appBar: _appBar(needsAttention),
            body: SafeArea(child: body),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _go,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: _appBar(needsAttention),
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                // Expanded stops the child fighting the Row for width, which
                // is the fix the lecture recommends over shrinkWrap.
                Expanded(flex: 3, child: body),
                if (isDesktop && _index != 0) ...[
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: HomeView(onQuickAdd: _openAdd, compact: true),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(bool needsAttention) {
    return AppBar(
      title: const Text('Savings Pad'),
      actions: [
        if (needsAttention)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Something needs your attention',
              child: Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
