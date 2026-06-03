import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/calculator_definition.dart';
import '../services/storage_service.dart';

class CalculatorScreen extends StatefulWidget {
  final String calculatorId;
  const CalculatorScreen({super.key, required this.calculatorId});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  bool _isFavorite = false;
  String? _resultText;
  String? _interpretation;
  String? _educationalNote;
  String? _warningText;

  CalculatorDefinition get _def =>
      kCalculators.firstWhere((c) => c.id == widget.calculatorId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFavorite());
  }

  void _loadFavorite() {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    setState(() => _isFavorite = storage.getFavorites().contains(widget.calculatorId));
  }

  Future<void> _toggleFavorite() async {
    final storage = context.read<StorageService>();
    final newVal = !_isFavorite;
    setState(() => _isFavorite = newVal);
    if (newVal) {
      await storage.addFavorite(widget.calculatorId);
    } else {
      await storage.removeFavorite(widget.calculatorId);
    }
  }

  void _copyResult() {
    if (_resultText == null) return;
    Clipboard.setData(ClipboardData(text: _resultText!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Result copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setResult({
    required String result,
    required String interpretation,
    String? educationalNote,
    String? warning,
  }) {
    setState(() {
      _resultText = '${_def.title}: $result';
      _interpretation = interpretation;
      _educationalNote = educationalNote;
      _warningText = warning;
    });
  }

  void _reset() {
    setState(() {
      _resultText = null;
      _interpretation = null;
      _educationalNote = null;
      _warningText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_def.title),
        backgroundColor: cs.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.pink : null,
            ),
            tooltip: 'Save to favorites',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Description
          Text(
            _def.description,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 20),

          // Calculator-specific inputs
          _buildInputs(context),

          const SizedBox(height: 8),

          // Action row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              if (_resultText != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyResult,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
            ],
          ),

          // Result block
          if (_resultText != null) ...[
            const SizedBox(height: 20),
            _ResultCard(
              resultText: _resultText!,
              interpretation: _interpretation,
              educationalNote: _educationalNote,
              warningText: _warningText,
            ),
          ],

          _ClinicalNotesSection(def: _def),

          const SizedBox(height: 24),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _def.disclaimer,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInputs(BuildContext context) {
    switch (widget.calculatorId) {
      case 'weight-dosing':
        return _WeightDosingForm(onResult: _setResult, onReset: _reset);
      case 'iv-infusion':
        return _IvInfusionForm(onResult: _setResult, onReset: _reset);
      case 'gcs':
        return _GcsForm(onResult: _setResult, onReset: _reset);
      case 'bmi':
        return _BmiForm(onResult: _setResult, onReset: _reset);
      case 'edd-ega':
        return _EddEgaForm(onResult: _setResult, onReset: _reset);
      case 'anion-gap':
        return _AnionGapForm(onResult: _setResult, onReset: _reset);
      case 'creatinine-clearance':
        return _CrClForm(onResult: _setResult, onReset: _reset);
      case 'holliday-segar':
        return _HollidaySegarForm(onResult: _setResult, onReset: _reset);
      default:
        return const Text('Unknown calculator');
    }
  }
}

// ─── Shared result card ───────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String resultText;
  final String? interpretation;
  final String? educationalNote;
  final String? warningText;

  const _ResultCard({
    required this.resultText,
    this.interpretation,
    this.educationalNote,
    this.warningText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            resultText,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
        ),
        if (interpretation != null) ...[
          const SizedBox(height: 12),
          Text('Interpretation',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(interpretation!, style: theme.textTheme.bodyMedium),
        ],
        if (warningText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(warningText!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.orange.shade800)),
                ),
              ],
            ),
          ),
        ],
        if (educationalNote != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(educationalNote!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.teal.shade700)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Shared input widget ──────────────────────────────────────────────────────

class _NumericField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumericField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Calculator 1: Weight-Based Drug Dosing ───────────────────────────────────

class _WeightDosingForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _WeightDosingForm({required this.onResult, required this.onReset});

  @override
  State<_WeightDosingForm> createState() => _WeightDosingFormState();
}

class _WeightDosingFormState extends State<_WeightDosingForm> {
  final _weightCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _maxDoseCtrl = TextEditingController();
  String _weightUnit = 'kg';
  String _frequency = 'once';
  final _freqs = ['once', 'BD', 'TDS', 'QID'];

  @override
  void dispose() {
    _weightCtrl.dispose();
    _doseCtrl.dispose();
    _maxDoseCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawWeight = double.tryParse(_weightCtrl.text);
    final dosePerKg = double.tryParse(_doseCtrl.text);
    if (rawWeight == null || rawWeight <= 0 || dosePerKg == null || dosePerKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid weight and dose per kg')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawWeight : rawWeight * 0.453592;
    double total = weightKg * dosePerKg;
    final maxDose = double.tryParse(_maxDoseCtrl.text);
    String? warning;
    if (maxDose != null && maxDose > 0 && total > maxDose) {
      warning = 'Max dose applied: ${maxDose.toStringAsFixed(1)} mg (calculated: ${total.toStringAsFixed(1)} mg)';
      total = maxDose;
    }
    widget.onResult(
      result: '${total.toStringAsFixed(1)} mg per dose, $_frequency\n'
          'Weight used: ${weightKg.toStringAsFixed(2)} kg × $dosePerKg mg/kg',
      interpretation: 'Administer ${total.toStringAsFixed(1)} mg per dose, $_frequency.',
      educationalNote: null,
      warning: warning ?? 'Verify dose against current formulary and institutional guidelines.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _NumericField(label: 'Weight', controller: _weightCtrl)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _weightUnit,
              items: ['kg', 'lb']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _weightUnit = v!),
            ),
          ],
        ),
        _NumericField(label: 'Dose per kg (mg/kg)', controller: _doseCtrl),
        DropdownButtonFormField<String>(
          initialValue: _frequency,
          decoration: const InputDecoration(
              labelText: 'Frequency', border: OutlineInputBorder(), isDense: true),
          items: _freqs
              .map((f) => DropdownMenuItem(value: f, child: Text(f)))
              .toList(),
          onChanged: (v) => setState(() => _frequency = v!),
        ),
        const SizedBox(height: 12),
        _NumericField(
            label: 'Max dose (mg) — optional', controller: _maxDoseCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 2: IV Infusion Rate ──────────────────────────────────────────

class _IvInfusionForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _IvInfusionForm({required this.onResult, required this.onReset});

  @override
  State<_IvInfusionForm> createState() => _IvInfusionFormState();
}

class _IvInfusionFormState extends State<_IvInfusionForm> {
  final _volumeCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  String _mode = 'mL/hr';
  String _timeUnit = 'hours';
  int _dropFactor = 20;

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final volume = double.tryParse(_volumeCtrl.text);
    final time = double.tryParse(_timeCtrl.text);
    if (volume == null || volume <= 0 || time == null || time <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid volume and time')));
      return;
    }
    String result;
    if (_mode == 'mL/hr') {
      final timeHr = _timeUnit == 'hours' ? time : time / 60;
      final rate = volume / timeHr;
      result = '${rate.toStringAsFixed(1)} mL/hr';
      widget.onResult(
        result: result,
        interpretation: 'Set the infusion pump to ${rate.toStringAsFixed(1)} mL/hr.',
        warning: 'Double-check pump settings before starting infusion.',
      );
    } else {
      final timeMin = _timeUnit == 'minutes' ? time : time * 60;
      final rate = (volume * _dropFactor) / timeMin;
      result = '${rate.toStringAsFixed(1)} drops/min (drop factor: $_dropFactor gtt/mL)';
      widget.onResult(
        result: result,
        interpretation: 'Count ${rate.toStringAsFixed(0)} drops per minute.',
        warning: 'Double-check giving set drop factor before starting infusion.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Total volume (mL)', controller: _volumeCtrl),
        Row(
          children: [
            Expanded(child: _NumericField(label: 'Time', controller: _timeCtrl)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _timeUnit,
              items: ['hours', 'minutes']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _timeUnit = v!),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(
              labelText: 'Mode', border: OutlineInputBorder(), isDense: true),
          items: ['mL/hr', 'gtt/min']
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() => _mode = v!),
        ),
        if (_mode == 'gtt/min') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _dropFactor,
            decoration: const InputDecoration(
                labelText: 'Drop factor (gtt/mL)',
                border: OutlineInputBorder(),
                isDense: true),
            items: [10, 15, 20, 60]
                .map((d) => DropdownMenuItem(value: d, child: Text('$d gtt/mL')))
                .toList(),
            onChanged: (v) => setState(() => _dropFactor = v!),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 3: Glasgow Coma Scale ────────────────────────────────────────

class _GcsForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _GcsForm({required this.onResult, required this.onReset});

  @override
  State<_GcsForm> createState() => _GcsFormState();
}

class _GcsFormState extends State<_GcsForm> {
  int _eye = 4, _verbal = 5, _motor = 6;
  bool _intubated = false;

  static const _eyeOptions = [
    (4, 'Spontaneous'),
    (3, 'To voice'),
    (2, 'To pain'),
    (1, 'None'),
  ];
  static const _verbalOptions = [
    (5, 'Orientated'),
    (4, 'Confused'),
    (3, 'Words'),
    (2, 'Sounds'),
    (1, 'None'),
  ];
  static const _motorOptions = [
    (6, 'Obeys commands'),
    (5, 'Localises pain'),
    (4, 'Withdraws'),
    (3, 'Flexion'),
    (2, 'Extension'),
    (1, 'None'),
  ];

  void _calculate() {
    final total = _intubated ? _eye + _motor : _eye + _verbal + _motor;
    String severity;
    if (total >= 13) {
      severity = 'Mild injury';
    } else if (total >= 9) {
      severity = 'Moderate injury';
    } else {
      severity = 'Severe injury';
    }

    final display = _intubated
        ? 'E$_eye V(T) M$_motor = ${_eye + _motor}T'
        : 'E$_eye V$_verbal M$_motor = $total';

    widget.onResult(
      result: '$display — $severity',
      interpretation: 'Total GCS $total. $severity.',
      educationalNote: 'A GCS ≤ 8 is the conventional threshold for considering airway protection.',
      warning: 'GCS alone does not determine airway management — use full clinical assessment.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gcsDropdown('Eye response (E)', _eye, _eyeOptions,
            (v) => setState(() => _eye = v)),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Patient is intubated'),
          subtitle: const Text('Verbal score recorded as T'),
          value: _intubated,
          onChanged: (v) => setState(() => _intubated = v),
          contentPadding: EdgeInsets.zero,
        ),
        if (!_intubated) ...[
          const SizedBox(height: 4),
          _gcsDropdown('Verbal response (V)', _verbal, _verbalOptions,
              (v) => setState(() => _verbal = v)),
        ],
        const SizedBox(height: 12),
        _gcsDropdown('Motor response (M)', _motor, _motorOptions,
            (v) => setState(() => _motor = v)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }

  Widget _gcsDropdown(
    String label,
    int currentValue,
    List<(int, String)> options,
    void Function(int) onChanged,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: currentValue,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(), isDense: true),
      items: options
          .map((o) =>
              DropdownMenuItem(value: o.$1, child: Text('${o.$1} — ${o.$2}')))
          .toList(),
      onChanged: (v) => onChanged(v!),
    );
  }
}

// ─── Calculator 4: BMI ────────────────────────────────────────────────────────

class _BmiForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _BmiForm({required this.onResult, required this.onReset});

  @override
  State<_BmiForm> createState() => _BmiFormState();
}

class _BmiFormState extends State<_BmiForm> {
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _weightUnit = 'kg';
  String _heightUnit = 'cm';

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawW = double.tryParse(_weightCtrl.text);
    final rawH = double.tryParse(_heightCtrl.text);
    if (rawW == null || rawW <= 0 || rawH == null || rawH <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid weight and height')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawW : rawW * 0.453592;
    final heightM = _heightUnit == 'cm'
        ? rawH / 100
        : _heightUnit == 'm'
            ? rawH
            : rawH * 0.3048;
    final bmi = weightKg / (heightM * heightM);

    String category;
    if (bmi < 18.5) {
      category = 'Underweight';
    } else if (bmi < 25) {
      category = 'Normal weight';
    } else if (bmi < 30) {
      category = 'Overweight';
    } else if (bmi < 35) {
      category = 'Obese — Class I';
    } else if (bmi < 40) {
      category = 'Obese — Class II';
    } else {
      category = 'Obese — Class III (Severe)';
    }

    widget.onResult(
      result: 'BMI: ${bmi.toStringAsFixed(1)} — $category',
      interpretation: 'A BMI of ${bmi.toStringAsFixed(1)} is classified as $category.',
      educationalNote: 'BMI does not account for muscle mass or fat distribution. Interpret in clinical context.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _NumericField(label: 'Weight', controller: _weightCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _weightUnit,
            items: ['kg', 'lb']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _weightUnit = v!),
          ),
        ]),
        Row(children: [
          Expanded(child: _NumericField(label: 'Height', controller: _heightCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _heightUnit,
            items: ['cm', 'm', 'ft']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _heightUnit = v!),
          ),
        ]),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 5: EDD / EGA ──────────────────────────────────────────────────

class _EddEgaForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _EddEgaForm({required this.onResult, required this.onReset});

  @override
  State<_EddEgaForm> createState() => _EddEgaFormState();
}

class _EddEgaFormState extends State<_EddEgaForm> {
  DateTime? _lmp;
  DateTime _referenceDate = DateTime.now();

  Future<void> _pickDate({required bool isLmp}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isLmp ? (now.subtract(const Duration(days: 60))) : now,
      firstDate: DateTime(now.year - 2),
      lastDate: isLmp ? now : DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isLmp) {
        _lmp = picked;
      } else {
        _referenceDate = picked;
      }
    });
  }

  void _calculate() {
    if (_lmp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the LMP date')));
      return;
    }
    final edd = _lmp!.add(const Duration(days: 280));
    final diff = _referenceDate.difference(_lmp!).inDays;
    final weeks = diff ~/ 7;
    final days = diff % 7;

    String egaText = '$weeks weeks $days days';
    String? warning;
    if (_referenceDate.isAfter(edd)) {
      final overdue = _referenceDate.difference(edd).inDays;
      warning = 'Past EDD by $overdue days';
    }

    final eddFormatted =
        '${edd.day} ${_monthName(edd.month)} ${edd.year}';

    widget.onResult(
      result: 'EDD: $eddFormatted\nEGA: $egaText',
      interpretation: 'Estimated delivery date is $eddFormatted. Current gestational age is $egaText.',
      educationalNote: 'EGA is more accurately determined by first-trimester ultrasound when available.',
      warning: warning,
    );
  }

  String _monthName(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dateTile(
          theme,
          label: 'Last Menstrual Period (LMP)',
          date: _lmp,
          onTap: () => _pickDate(isLmp: true),
        ),
        const SizedBox(height: 12),
        _dateTile(
          theme,
          label: 'Reference date (defaults to today)',
          date: _referenceDate,
          onTap: () => _pickDate(isLmp: false),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }

  Widget _dateTile(ThemeData theme, {required String label, DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'Tap to select',
          style: date == null
              ? theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// ─── Calculator 6: Anion Gap ──────────────────────────────────────────────────

class _AnionGapForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _AnionGapForm({required this.onResult, required this.onReset});

  @override
  State<_AnionGapForm> createState() => _AnionGapFormState();
}

class _AnionGapFormState extends State<_AnionGapForm> {
  final _naCtrl = TextEditingController();
  final _clCtrl = TextEditingController();
  final _hco3Ctrl = TextEditingController();

  @override
  void dispose() {
    _naCtrl.dispose();
    _clCtrl.dispose();
    _hco3Ctrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final na = double.tryParse(_naCtrl.text);
    final cl = double.tryParse(_clCtrl.text);
    final hco3 = double.tryParse(_hco3Ctrl.text);
    if (na == null || cl == null || hco3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter all three electrolyte values')));
      return;
    }
    final ag = na - (cl + hco3);
    String category;
    String interp;
    if (ag < 8) {
      category = 'Low';
      interp = 'Low anion gap (< 8 mEq/L). Consider hypoalbuminaemia, multiple myeloma, or lithium toxicity.';
    } else if (ag <= 12) {
      category = 'Normal';
      interp = 'Normal anion gap (8–12 mEq/L). Non-anion gap metabolic acidosis if HCO₃ is low.';
    } else {
      category = 'Elevated (HAGMA)';
      interp = 'Elevated anion gap (> 12 mEq/L). Consider MUDPILES: Methanol, Uraemia, DKA, Propylene glycol/Paracetamol, Isoniazid/Iron, Lactic acidosis, Ethylene glycol, Salicylates.';
    }

    widget.onResult(
      result: 'Anion Gap: ${ag.toStringAsFixed(1)} mEq/L — $category',
      interpretation: interp,
      educationalNote: 'Consider albumin correction if hypoalbuminaemia is present: Corrected AG = AG + 2.5 × (4 − albumin g/dL).',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Sodium Na⁺ (mEq/L)', controller: _naCtrl),
        _NumericField(label: 'Chloride Cl⁻ (mEq/L)', controller: _clCtrl),
        _NumericField(label: 'Bicarbonate HCO₃⁻ (mEq/L)', controller: _hco3Ctrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 7: Creatinine Clearance (Cockcroft-Gault) ────────────────────

class _CrClForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _CrClForm({required this.onResult, required this.onReset});

  @override
  State<_CrClForm> createState() => _CrClFormState();
}

class _CrClFormState extends State<_CrClForm> {
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _scrCtrl = TextEditingController();
  String _sex = 'male';
  String _scrUnit = 'mg/dL';
  String _weightUnit = 'kg';

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _scrCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final age = double.tryParse(_ageCtrl.text);
    final rawW = double.tryParse(_weightCtrl.text);
    final rawScr = double.tryParse(_scrCtrl.text);
    if (age == null || rawW == null || rawScr == null ||
        age <= 0 || rawW <= 0 || rawScr <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid age, weight, and creatinine')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawW : rawW * 0.453592;
    final scrMgDl = _scrUnit == 'mg/dL' ? rawScr : rawScr / 88.4;
    double crcl = ((140 - age) * weightKg) / (72 * scrMgDl);
    if (_sex == 'female') crcl *= 0.85;

    String band;
    if (crcl >= 90) {
      band = 'Normal';
    } else if (crcl >= 60) {
      band = 'Mildly decreased';
    } else if (crcl >= 30) {
      band = 'Moderately decreased';
    } else if (crcl >= 15) {
      band = 'Severely decreased';
    } else {
      band = 'Kidney failure';
    }

    widget.onResult(
      result: 'CrCl: ${crcl.toStringAsFixed(1)} mL/min — $band',
      interpretation: 'Estimated creatinine clearance is ${crcl.toStringAsFixed(1)} mL/min ($band).',
      educationalNote: 'Cockcroft-Gault uses actual body weight. Consider using IBW in obese patients.',
      warning: 'Verify drug-specific renal dosing thresholds against current formulary.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Age (years)', controller: _ageCtrl),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(
              labelText: 'Sex', border: OutlineInputBorder(), isDense: true),
          items: ['male', 'female']
              .map((s) => DropdownMenuItem(
                  value: s, child: Text('${s[0].toUpperCase()}${s.substring(1)}')))
              .toList(),
          onChanged: (v) => setState(() => _sex = v!),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _NumericField(label: 'Weight', controller: _weightCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _weightUnit,
            items: ['kg', 'lb']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _weightUnit = v!),
          ),
        ]),
        Row(children: [
          Expanded(
              child: _NumericField(
                  label: 'Serum creatinine', controller: _scrCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _scrUnit,
            items: ['mg/dL', 'µmol/L']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _scrUnit = v!),
          ),
        ]),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Clinical notes section ──────────────────────────────────────────────────

class _ClinicalNotesSection extends StatefulWidget {
  final CalculatorDefinition def;
  const _ClinicalNotesSection({required this.def});

  @override
  State<_ClinicalNotesSection> createState() => _ClinicalNotesSectionState();
}

class _ClinicalNotesSectionState extends State<_ClinicalNotesSection> {
  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    if ([
      def.explanation,
      def.clinicalInterpretation,
      def.safetyNotes,
      def.commonPitfalls,
      def.osceTips,
    ].every((s) => s.isEmpty)) {
      return const SizedBox.shrink();
    }
    return ExpansionTile(
      title: const Text('Clinical Notes'),
      initiallyExpanded: false,
      children: [
        if (def.explanation.isNotEmpty)
          _noteRow(context, Icons.info_outline, 'Explanation', def.explanation),
        if (def.clinicalInterpretation.isNotEmpty)
          _noteRow(context, Icons.medical_services_outlined,
              'Clinical Interpretation', def.clinicalInterpretation),
        if (def.safetyNotes.isNotEmpty)
          _noteRow(context, Icons.warning_amber_outlined,
              'Safety Notes', def.safetyNotes),
        if (def.commonPitfalls.isNotEmpty)
          _noteRow(context, Icons.error_outline,
              'Common Pitfalls', def.commonPitfalls),
        if (def.osceTips.isNotEmpty)
          _noteRow(context, Icons.school_outlined, 'OSCE Tips', def.osceTips),
      ],
    );
  }
}

Widget _noteRow(
    BuildContext context, IconData icon, String label, String body) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Calculator 8: Holliday-Segar ────────────────────────────────────────────

class _HollidaySegarForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _HollidaySegarForm({required this.onResult, required this.onReset});

  @override
  State<_HollidaySegarForm> createState() => _HollidaySegarFormState();
}

class _HollidaySegarFormState extends State<_HollidaySegarForm> {
  final _weightCtrl = TextEditingController();
  String _weightUnit = 'kg';

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawW = double.tryParse(_weightCtrl.text);
    if (rawW == null || rawW <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid weight')));
      return;
    }
    final w = _weightUnit == 'kg' ? rawW : rawW * 0.453592;
    final first10 = [w, 10.0].reduce((a, b) => a < b ? a : b) * 4;
    final next10 = [w - 10.0, 10.0, 0.0]
            .reduce((a, b) => a > b ? a : b)
            .clamp(0, 10) *
        2;
    final remaining = (w - 20.0).clamp(0, double.infinity) * 1;
    final rateHr = first10 + next10 + remaining;
    final rateDay = rateHr * 24;

    String? warning;
    if (w > 60) {
      warning = 'Holliday-Segar is validated for paediatric weights. Adult maintenance may differ.';
    }

    final breakdown = 'First 10 kg: ${first10.toStringAsFixed(1)} mL/hr'
        '${w > 10 ? ' | Next 10 kg: ${next10.toStringAsFixed(1)} mL/hr' : ''}'
        '${w > 20 ? ' | Remaining ${(w - 20).toStringAsFixed(1)} kg: ${remaining.toStringAsFixed(1)} mL/hr' : ''}';

    widget.onResult(
      result: '${rateHr.toStringAsFixed(1)} mL/hr  (${rateDay.toStringAsFixed(0)} mL/day)',
      interpretation: 'Maintenance fluid rate: ${rateHr.toStringAsFixed(1)} mL/hr.\n$breakdown',
      educationalNote: 'Adjust for clinical context: fever, ongoing losses, cardiac or renal disease.',
      warning: warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _NumericField(label: 'Weight', controller: _weightCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _weightUnit,
            items: ['kg', 'lb']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _weightUnit = v!),
          ),
        ]),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}
