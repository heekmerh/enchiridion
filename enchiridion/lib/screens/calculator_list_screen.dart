import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calculator_definition.dart';
import '../services/storage_service.dart';
import '../services/access_service.dart';
import '../config/freemium_config.dart';
import '../utils/bottom_inset.dart';
import '../widgets/common/coming_soon.dart';
import 'calculator_screen.dart';
import 'unlock_screen.dart';

class CalculatorListScreen extends StatefulWidget {
  const CalculatorListScreen({super.key});

  @override
  State<CalculatorListScreen> createState() => _CalculatorListScreenState();
}

class _CalculatorListScreenState extends State<CalculatorListScreen> {
  final Set<String> _favorites = {};
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final access = await AccessService.instance.hasFullAccess();
    if (!mounted) return;
    final storage = context.read<StorageService>();
    final favIds = storage.getFavorites();
    setState(() {
      _hasAccess = access;
      _favorites
        ..clear()
        ..addAll(favIds);
    });
  }

  bool _isLocked(CalculatorDefinition calc) {
    // An unbuilt calculator is not paywalled content and must never show a
    // lock — coming-soon wins over the freemium gate.
    if (calc.isComingSoon) return false;
    if (_hasAccess) return false;
    // Compute the free-slot index over that category's implemented entries
    // only, so a coming-soon entry can never consume the free slot. Because
    // `availableFirst` (used by `groupedCalculatorsInDisplayOrder`) is
    // stable, this filtered order matches exactly what the user sees.
    final categoryCalcs = kCalculators
        .where((c) => c.category == calc.category && c.hasContent)
        .toList();
    final index = categoryCalcs.indexWhere((c) => c.id == calc.id);
    return index >= kFreeCalculatorsPerCategory;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final grouped = groupedCalculatorsInDisplayOrder();
    // Filter stale favourites for now-unbuilt ids so a coming-soon entry
    // can never surface in the Favorites section.
    final favCalcs = kCalculators
        .where((c) => _favorites.contains(c.id) && c.hasContent)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculators'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: 8 + bottomViewportInset(context)),
        children: [
          if (favCalcs.isNotEmpty) ...[
            _sectionHeader(theme, 'Favorites'),
            ...favCalcs.map((c) => _calcTile(context, c, isFavorite: true)),
            const Divider(height: 24),
          ],
          ...grouped.entries.expand((entry) => [
                _sectionHeader(theme, entry.key),
                ...entry.value.map((c) => _calcTile(context, c)),
              ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _calcTile(
    BuildContext context,
    CalculatorDefinition calc, {
    bool isFavorite = false,
  }) {
    final comingSoon = calc.isComingSoon;
    final locked = _isLocked(calc);
    final cs = Theme.of(context).colorScheme;

    if (comingSoon) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: ComingSoonStyle.container(cs),
          child: Icon(Icons.schedule, color: ComingSoonStyle.icon(cs), size: 20),
        ),
        title: Text(calc.title, style: TextStyle(color: ComingSoonStyle.title(cs))),
        subtitle: Text(
          calc.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ComingSoonStyle.body(cs)),
        ),
        trailing: const ComingSoonBadge(compact: true),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${calc.title} — $kComingSoonLabel'),
            behavior: SnackBarBehavior.floating,
          ));
        },
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            locked ? cs.surfaceContainerHighest : cs.primaryContainer,
        child: Icon(
          locked ? Icons.lock_outline : Icons.calculate_outlined,
          color: locked
              ? ComingSoonStyle.icon(cs)
              : cs.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        calc.title,
        style: locked ? TextStyle(color: ComingSoonStyle.title(cs)) : null,
      ),
      subtitle: Text(
        calc.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: locked ? TextStyle(color: ComingSoonStyle.body(cs)) : null,
      ),
      trailing: locked
          ? Icon(Icons.lock_outline, size: 16, color: ComingSoonStyle.icon(cs))
          : isFavorite
              ? const Icon(Icons.favorite, size: 18, color: Colors.pink)
              : null,
      onTap: () async {
        if (locked) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UnlockScreen()),
          );
          if (mounted) await _loadData();
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CalculatorScreen(calculatorId: calc.id),
          ),
        );
        if (mounted) await _loadData();
      },
    );
  }
}
