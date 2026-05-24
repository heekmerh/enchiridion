import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calculator_definition.dart';
import '../services/storage_service.dart';
import '../services/access_service.dart';
import '../config/freemium_config.dart';
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
      _favorites.addAll(favIds);
    });
  }

  bool _isLocked(CalculatorDefinition calc) {
    if (_hasAccess) return false;
    final categoryCalcs =
        kCalculators.where((c) => c.category == calc.category).toList();
    final index = categoryCalcs.indexWhere((c) => c.id == calc.id);
    return index >= kFreeCalculatorsPerCategory;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final grouped = groupByCategory(kCalculators);
    final favCalcs =
        kCalculators.where((c) => _favorites.contains(c.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculators'),
        backgroundColor: cs.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
    final locked = _isLocked(calc);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: locked
            ? cs.surfaceContainerHighest
            : cs.primaryContainer,
        child: Icon(
          locked ? Icons.lock_outline : Icons.calculate_outlined,
          color: locked
              ? cs.onSurface.withValues(alpha: 0.4)
              : cs.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        calc.title,
        style: locked
            ? TextStyle(color: cs.onSurface.withValues(alpha: 0.5))
            : null,
      ),
      subtitle: Text(
        calc.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: locked
            ? TextStyle(color: cs.onSurface.withValues(alpha: 0.35))
            : null,
      ),
      trailing: locked
          ? Icon(Icons.lock_outline, size: 16,
              color: cs.onSurface.withValues(alpha: 0.4))
          : isFavorite
              ? const Icon(Icons.favorite, size: 18, color: Colors.pink)
              : null,
      onTap: () {
        if (locked) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UnlockScreen()),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CalculatorScreen(calculatorId: calc.id),
          ),
        );
      },
    );
  }
}
