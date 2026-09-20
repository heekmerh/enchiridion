import 'package:flutter/material.dart';

import '../models/exam_module.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../utils/bottom_inset.dart';

/// Leaderboard with an aggregated cross-module board plus one tab per
/// available exam module (PLAB today). Coming-soon modules have no data and
/// get no tab.
class LeaderboardScreen extends StatefulWidget {
  /// Module tab to open on. Null (or an unavailable module) opens Overall.
  final String? initialModule;

  const LeaderboardScreen({super.key, this.initialModule});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _limit = 20;

  /// Tabs: Overall first, then one per available module.
  late final List<_BoardTab> _tabs;
  late int _tabIndex;
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const _BoardTab(label: 'Overall', moduleId: null),
      for (final module in kExamModules)
        if (module.isAvailable)
          _BoardTab(label: module.label, moduleId: module.id),
    ];
    final initial = widget.initialModule;
    _tabIndex = _tabs.indexWhere((tab) => tab.moduleId == initial);
    if (_tabIndex < 0) _tabIndex = 0;
    _future = _load(_tabs[_tabIndex]);
  }

  Future<List<LeaderboardEntry>> _load(_BoardTab tab) {
    final moduleId = tab.moduleId;
    if (moduleId == null) {
      return LeaderboardService().fetch(limit: _limit);
    }
    return LeaderboardService().fetchForModule(moduleId, limit: _limit);
  }

  Future<void> _refresh() async {
    final next = _load(_tabs[_tabIndex]);
    setState(() => _future = next);
    await next;
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _tabIndex = index;
      _future = _load(_tabs[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        children: [
          if (_tabs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < _tabs.length; i++)
                    ButtonSegment(value: i, label: Text(_tabs[i].label)),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (selection) =>
                    _selectTab(selection.first),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const _ScrollableMessage(
                icon: Icons.error_outline,
                message: "Couldn't load the leaderboard. Pull to try again.",
              );
            }
            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return const _ScrollableMessage(
                icon: Icons.leaderboard_outlined,
                message: 'No points on the board yet — answer a few '
                    'questions to get started.',
              );
            }

            return ListView.separated(
              padding: EdgeInsets.only(bottom: bottomViewportInset(context)),
              itemCount: entries.length,
              separatorBuilder: (context, index) {
                final gap = index + 1 < entries.length &&
                    entries[index + 1].rank != entries[index].rank + 1;
                return gap
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Text(
                            '⋯',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      )
                    : const Divider(height: 1);
              },
              itemBuilder: (context, index) =>
                  _LeaderboardRow(entry: entries[index]),
            );
          },
        ),
      ),
            ),
          ],
      ),
    );
  }
}

class _BoardTab {
  final String label;
  final String? moduleId;

  const _BoardTab({required this.label, this.moduleId});
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      color: entry.isYou ? cs.primaryContainer.withValues(alpha: 0.4) : null,
      child: ListTile(
        leading: SizedBox(
          width: 32,
          child: Text(
            '#${entry.rank}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: entry.rank <= 3 ? cs.primary : null,
            ),
          ),
        ),
        title: Text(
          entry.displayName,
          style: entry.isYou
              ? const TextStyle(fontWeight: FontWeight.bold)
              : null,
        ),
        trailing: Text(
          '${entry.totalPoints} pts',
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ScrollableMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ScrollableMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
