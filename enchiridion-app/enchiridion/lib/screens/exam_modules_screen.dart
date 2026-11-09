import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/exam_module.dart';
import '../providers/study_stats_provider.dart';
import '../utils/bottom_inset.dart';
import '../widgets/common/coming_soon.dart';
import 'exam_prep_home_screen.dart';

/// Exam-prep module picker. PLAB opens the full exam-prep section (mock
/// exam, performance stats, leaderboard); every other module shows
/// coming-soon until its question bank ships.
class ExamModulesScreen extends StatelessWidget {
  const ExamModulesScreen({super.key});

  void _openModule(BuildContext context, ExamModule module) {
    if (!module.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${module.label} — $kComingSoonLabel'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamPrepHomeScreen(moduleId: module.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statsProvider = context.watch<StudyStatsProvider>();
    final overall = statsProvider.overallExamTotals;

    return Scaffold(
      appBar: AppBar(title: const Text('Exam Prep')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + bottomViewportInset(context),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Aggregated across all modules.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ModuleMetric(
                        label: 'Answered',
                        value: '${overall.questionsAnswered}'),
                    const SizedBox(width: 10),
                    _ModuleMetric(
                        label: 'Points',
                        value: '${overall.performancePoints}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final module in kExamModules) ...[
            _ModuleCard(
              module: module,
              onTap: () => _openModule(context, module),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final ExamModule module;
  final VoidCallback onTap;

  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final comingSoon = !module.isAvailable;
    final statsProvider = context.watch<StudyStatsProvider>();
    final totals = statsProvider.totalsForModule(module.id);

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: comingSoon
                    ? ComingSoonStyle.container(cs)
                    : cs.primaryContainer,
                child: Icon(
                  Icons.quiz_outlined,
                  color: comingSoon
                      ? ComingSoonStyle.icon(cs)
                      : cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: comingSoon
                            ? ComingSoonStyle.title(cs)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comingSoon
                          ? kComingSoonLabel
                          : '${totals.questionsAnswered} answered · '
                              '${totals.performancePoints} pts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: comingSoon
                            ? ComingSoonStyle.body(cs)
                            : cs.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
              if (comingSoon)
                const ComingSoonBadge(compact: true)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleMetric extends StatelessWidget {
  final String label;
  final String value;

  const _ModuleMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
