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
      case 'qsofa':
        return _QsofaForm(onResult: _setResult, onReset: _reset);
      case 'news2':
        return _News2Form(onResult: _setResult, onReset: _reset);
      case 'shock-index':
        return _ShockIndexForm(onResult: _setResult, onReset: _reset);
      case 'osmolality':
        return _OsmolalityForm(onResult: _setResult, onReset: _reset);
      case 'corrected-sodium':
        return _CorrectedSodiumForm(onResult: _setResult, onReset: _reset);
      case 'aa-gradient':
        return _AaGradientForm(onResult: _setResult, onReset: _reset);
      case 'pao2-fio2':
        return _PaO2FiO2Form(onResult: _setResult, onReset: _reset);
      case 'bsa':
        return _BsaForm(onResult: _setResult, onReset: _reset);
      case 'egfr-ckd-epi':
        return _EgfrCkdEpiForm(onResult: _setResult, onReset: _reset);
      case 'gentamicin-vancomycin':
        return _GentamicinVancomycinForm(onResult: _setResult, onReset: _reset);
      case 'insulin-dose':
        return _InsulinDoseForm(onResult: _setResult, onReset: _reset);
      case 'paracetamol-dosing':
        return _ParacetamolDosingForm(onResult: _setResult, onReset: _reset);
      case 'apls-weight':
        return _AplsWeightForm(onResult: _setResult, onReset: _reset);
      case 'broselow':
        return _BroselowForm(onResult: _setResult, onReset: _reset);
      case 'pediatric-bp':
        return _PediatricBpForm(onResult: _setResult, onReset: _reset);
      case 'neonatal-bilirubin':
        return _NeonatalBilirubinForm(onResult: _setResult, onReset: _reset);
      case 'apgar':
        return _ApgarForm(onResult: _setResult, onReset: _reset);
      case 'growth-percentile':
        return _GrowthPercentileForm(onResult: _setResult, onReset: _reset);
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
            onChanged: (v) {
              if (v == null || v == _weightUnit) return;
              final current = double.tryParse(_weightCtrl.text);
              if (current != null && current > 0) {
                final converted = _weightUnit == 'kg'
                    ? current * 2.20462   // kg → lb
                    : current / 2.20462;  // lb → kg
                _weightCtrl.text = converted.toStringAsFixed(2);
              }
              setState(() => _weightUnit = v);
            },
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
            onChanged: (v) {
              if (v == null || v == _heightUnit) return;
              final current = double.tryParse(_heightCtrl.text);
              if (current != null && current > 0) {
                double meters;
                switch (_heightUnit) {
                  case 'cm': meters = current / 100; break;
                  case 'm':  meters = current; break;
                  case 'ft': meters = current * 0.3048; break;
                  default:   meters = current / 100;
                }
                double converted;
                switch (v) {
                  case 'cm': converted = meters * 100; break;
                  case 'm':  converted = meters; break;
                  case 'ft': converted = meters / 0.3048; break;
                  default:   converted = meters * 100;
                }
                _heightCtrl.text = converted.toStringAsFixed(2);
              }
              setState(() => _heightUnit = v);
            },
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

// ─── Calculator 9: qSOFA Score ───────────────────────────────────────────────


class _QsofaForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _QsofaForm({required this.onResult, required this.onReset});

  @override
  State<_QsofaForm> createState() => _QsofaFormState();
}

class _QsofaFormState extends State<_QsofaForm> {
  bool _alteredMentation = false;
  bool _rrHigh = false;
  bool _sbpLow = false;

  void _calculate() {
    int score = (_alteredMentation ? 1 : 0) + (_rrHigh ? 1 : 0) + (_sbpLow ? 1 : 0);
    String band;
    String interp;
    if (score >= 2) {
      band = 'High risk';
      interp = 'qSOFA score $score/3 — high risk of poor sepsis outcome. '
          'Initiate full SOFA assessment, blood cultures, and early antibiotics per protocol.';
    } else {
      band = 'Low risk';
      interp = 'qSOFA score $score/3 — low risk by qSOFA criteria. '
          'If sepsis is still clinically suspected, reassess and consider full SOFA score.';
    }
    widget.onResult(
      result: '$score/3 — $band',
      interpretation: interp,
      warning: 'qSOFA is a screening tool only. A score < 2 does not exclude sepsis — use clinical judgement.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Altered mentation (GCS < 15)'),
          value: _alteredMentation,
          onChanged: (v) => setState(() => _alteredMentation = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Respiratory rate ≥ 22 breaths/min'),
          value: _rrHigh,
          onChanged: (v) => setState(() => _rrHigh = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('Systolic BP ≤ 100 mmHg'),
          value: _sbpLow,
          onChanged: (v) => setState(() => _sbpLow = v),
          contentPadding: EdgeInsets.zero,
        ),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 10: NEWS2 Score ──────────────────────────────────────────────

class _News2Form extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _News2Form({required this.onResult, required this.onReset});

  @override
  State<_News2Form> createState() => _News2FormState();
}

class _News2FormState extends State<_News2Form> {
  bool _onO2 = false;
  int _consciousnessScore = 0; // ACVPU: Alert=0, any other=3
  bool _hypercapnic = false;

  // NEWS2 RR scoring
  static int _scoreRR(int rr) {
    if (rr <= 8) return 3;
    if (rr <= 11) return 1;
    if (rr <= 20) return 0;
    if (rr <= 24) return 2;
    return 3;
  }

  // NEWS2 SpO2 scale 1 scoring
  static int _scoreSpo2Scale1(int spo2) {
    if (spo2 <= 91) return 3;
    if (spo2 <= 93) return 2;
    if (spo2 <= 95) return 1;
    return 0;
  }

  // NEWS2 SpO2 scale 2 scoring (hypercapnic respiratory failure, target 88-92%)
  static int _scoreSpo2Scale2(int spo2) {
    if (spo2 <= 83) return 3;
    if (spo2 <= 85) return 2;
    if (spo2 <= 87) return 1;
    if (spo2 <= 92) return 0;
    if (spo2 <= 94) return 1;
    if (spo2 <= 96) return 2;
    return 3;
  }

  // NEWS2 SBP scoring
  static int _scoreSBP(int sbp) {
    if (sbp <= 90) return 3;
    if (sbp <= 100) return 2;
    if (sbp <= 110) return 1;
    if (sbp <= 219) return 0;
    return 3;
  }

  // NEWS2 HR scoring
  static int _scoreHR(int hr) {
    if (hr <= 40) return 3;
    if (hr <= 50) return 1;
    if (hr <= 90) return 0;
    if (hr <= 110) return 1;
    if (hr <= 130) return 2;
    return 3;
  }

  // NEWS2 temperature scoring
  static int _scoreTemp(double temp) {
    if (temp <= 35.0) return 3;
    if (temp <= 36.0) return 1;
    if (temp <= 38.0) return 0;
    if (temp <= 39.0) return 1;
    return 2;
  }

  final _rrCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _sbpCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();

  @override
  void dispose() {
    _rrCtrl.dispose();
    _spo2Ctrl.dispose();
    _sbpCtrl.dispose();
    _hrCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rrVal = double.tryParse(_rrCtrl.text);
    final spo2Val = double.tryParse(_spo2Ctrl.text);
    final sbpVal = double.tryParse(_sbpCtrl.text);
    final hrVal = double.tryParse(_hrCtrl.text);
    final tempVal = double.tryParse(_tempCtrl.text);

    if (rrVal == null || rrVal <= 0 || spo2Val == null || spo2Val <= 0 ||
        sbpVal == null || sbpVal <= 0 || hrVal == null || hrVal <= 0 ||
        tempVal == null || tempVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid values for all parameters')));
      return;
    }

    final rrScore = _scoreRR(rrVal.round());
    final spo2Score = _hypercapnic
        ? _scoreSpo2Scale2(spo2Val.round())
        : _scoreSpo2Scale1(spo2Val.round());
    final o2Score = _onO2 ? 2 : 0;
    final sbpScore = _scoreSBP(sbpVal.round());
    final hrScore = _scoreHR(hrVal.round());
    final tempScore = _scoreTemp(tempVal);

    final total = rrScore + spo2Score + o2Score + sbpScore + hrScore + tempScore + _consciousnessScore;

    String band;
    String response;
    if (total == 0) {
      band = 'Low';
      response = 'Routine monitoring.';
    } else if (total <= 4) {
      band = 'Low-medium';
      response = 'Increase observation frequency.';
    } else if (total <= 6) {
      band = 'Medium';
      response = 'Urgent clinical review required.';
    } else {
      band = 'High';
      response = 'Emergency assessment — consider critical care review.';
    }

    widget.onResult(
      result: '$total — $band',
      interpretation: 'NEWS2 score $total ($band risk). $response',
      educationalNote: 'Scale 2 SpO2 scoring applies for patients with hypercapnic respiratory failure (COPD target SpO2 88–92%).',
      warning: 'NEWS2 is for adult general ward use. Not validated in pregnancy or paediatrics.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Respiratory rate (breaths/min)', controller: _rrCtrl),
        SwitchListTile(
          title: const Text('Hypercapnic resp failure (SpO2 target 88–92%)'),
          subtitle: const Text('Uses NEWS2 SpO2 scale 2'),
          value: _hypercapnic,
          onChanged: (v) => setState(() => _hypercapnic = v),
          contentPadding: EdgeInsets.zero,
        ),
        _NumericField(label: 'SpO2 (%)', controller: _spo2Ctrl),
        SwitchListTile(
          title: const Text('On supplemental O2'),
          value: _onO2,
          onChanged: (v) => setState(() => _onO2 = v),
          contentPadding: EdgeInsets.zero,
        ),
        _NumericField(label: 'Systolic BP (mmHg)', controller: _sbpCtrl),
        _NumericField(label: 'Heart rate (bpm)', controller: _hrCtrl),
        _NumericField(label: 'Temperature (°C)', controller: _tempCtrl),
        DropdownButtonFormField<int>(
          initialValue: _consciousnessScore,
          decoration: const InputDecoration(
              labelText: 'Consciousness (ACVPU)',
              border: OutlineInputBorder(),
              isDense: true),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Alert (0)')),
            DropdownMenuItem(value: 3, child: Text('Voice/Pain/Unresponsive (3)')),
          ],
          onChanged: (v) => setState(() => _consciousnessScore = v!),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 11: Shock Index ──────────────────────────────────────────────

class _ShockIndexForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _ShockIndexForm({required this.onResult, required this.onReset});

  @override
  State<_ShockIndexForm> createState() => _ShockIndexFormState();
}

class _ShockIndexFormState extends State<_ShockIndexForm> {
  final _hrCtrl = TextEditingController();
  final _sbpCtrl = TextEditingController();

  @override
  void dispose() {
    _hrCtrl.dispose();
    _sbpCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final hr = double.tryParse(_hrCtrl.text);
    final sbp = double.tryParse(_sbpCtrl.text);
    if (hr == null || hr <= 0 || sbp == null || sbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid HR and SBP')));
      return;
    }
    final si = hr / sbp;
    String band;
    if (si < 0.6) {
      band = 'Normal';
    } else if (si < 1.0) {
      band = 'Mildly elevated';
    } else {
      band = 'Shock likely (≥ 1.0)';
    }
    widget.onResult(
      result: '${si.toStringAsFixed(2)} — $band',
      interpretation: 'Shock Index of ${si.toStringAsFixed(2)} suggests $band haemodynamic status.',
      warning: 'Shock Index is a screening tool — assess clinical picture in full (pallor, cap refill, mental status).',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Heart rate (bpm)', controller: _hrCtrl),
        _NumericField(label: 'Systolic BP (mmHg)', controller: _sbpCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 12: Osmolality & Osmolar Gap ─────────────────────────────────

class _OsmolalityForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _OsmolalityForm({required this.onResult, required this.onReset});

  @override
  State<_OsmolalityForm> createState() => _OsmolalityFormState();
}

class _OsmolalityFormState extends State<_OsmolalityForm> {
  final _naCtrl = TextEditingController();
  final _glucoseCtrl = TextEditingController();
  final _bunCtrl = TextEditingController();
  final _measuredCtrl = TextEditingController();

  @override
  void dispose() {
    _naCtrl.dispose();
    _glucoseCtrl.dispose();
    _bunCtrl.dispose();
    _measuredCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final na = double.tryParse(_naCtrl.text);
    final glucose = double.tryParse(_glucoseCtrl.text);
    final bun = double.tryParse(_bunCtrl.text);
    if (na == null || na <= 0 || glucose == null || glucose <= 0 || bun == null || bun <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid Na, glucose, and BUN values')));
      return;
    }
    final calculated = 2 * na + glucose / 18 + bun / 2.8;
    final measuredText = _measuredCtrl.text.trim();
    final measured = double.tryParse(measuredText);

    String resultStr;
    String interp;
    if (measured != null && measured > 0) {
      final gap = measured - calculated;
      final gapBand = gap > 10 ? 'Elevated (> 10)' : 'Normal (≤ 10)';
      resultStr = 'Calc: ${calculated.toStringAsFixed(1)} mOsm/kg | Gap: ${gap.toStringAsFixed(1)} mOsm/kg — $gapBand';
      interp = 'Calculated osmolality ${calculated.toStringAsFixed(1)} mOsm/kg. '
          'Osmolar gap ${gap.toStringAsFixed(1)} mOsm/kg ($gapBand). '
          '${gap > 10 ? 'Elevated gap — consider toxic alcohols (methanol, ethylene glycol, isopropanol), mannitol, or severe uraemia.' : 'Normal osmolar gap.'}';
    } else {
      resultStr = 'Calculated: ${calculated.toStringAsFixed(1)} mOsm/kg (no measured value entered)';
      interp = 'Calculated osmolality ${calculated.toStringAsFixed(1)} mOsm/kg. '
          'Normal range: 275–295 mOsm/kg. '
          'Enter measured osmolality to calculate the osmolar gap.';
    }

    widget.onResult(
      result: resultStr,
      interpretation: interp,
      educationalNote: 'Formula: 2×Na + glucose(mg/dL)/18 + BUN(mg/dL)/2.8.',
      warning: 'A normal osmolar gap does not reliably exclude early toxic alcohol ingestion.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Sodium Na⁺ (mEq/L)', controller: _naCtrl),
        _NumericField(label: 'Glucose (mg/dL)', controller: _glucoseCtrl),
        _NumericField(label: 'BUN (mg/dL)', controller: _bunCtrl),
        _NumericField(label: 'Measured osmolality (mOsm/kg) — optional', controller: _measuredCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 13: Corrected Sodium (Hyperglycemia) ─────────────────────────

class _CorrectedSodiumForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _CorrectedSodiumForm({required this.onResult, required this.onReset});

  @override
  State<_CorrectedSodiumForm> createState() => _CorrectedSodiumFormState();
}

class _CorrectedSodiumFormState extends State<_CorrectedSodiumForm> {
  final _naCtrl = TextEditingController();
  final _glucoseCtrl = TextEditingController();

  @override
  void dispose() {
    _naCtrl.dispose();
    _glucoseCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final na = double.tryParse(_naCtrl.text);
    final glucose = double.tryParse(_glucoseCtrl.text);
    if (na == null || na <= 0 || glucose == null || glucose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid sodium and glucose values')));
      return;
    }
    if (glucose <= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Glucose must be > 100 mg/dL for correction to apply')));
      return;
    }
    final corrected = na + 0.016 * (glucose - 100);
    String naInterp;
    if (corrected < 135) {
      naInterp = 'Corrected Na low — hyponatraemia persists after glucose correction; further evaluation needed.';
    } else if (corrected <= 145) {
      naInterp = 'Corrected Na normal — hyponatraemia is dilutional and should resolve with glucose treatment.';
    } else {
      naInterp = 'Corrected Na high — hypernatraemia present; review fluid management.';
    }

    widget.onResult(
      result: 'Corrected Na: ${corrected.toStringAsFixed(1)} mEq/L',
      interpretation: naInterp,
      educationalNote: 'Formula: Na + 0.016 × (glucose mg/dL − 100). Applies Katz correction factor.',
      warning: 'This calculator uses the Katz 1973 correction factor (0.016). '
          'Some guidelines use 0.024 for glucose > 400 mg/dL.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Measured sodium (mEq/L)', controller: _naCtrl),
        _NumericField(label: 'Glucose (mg/dL)', controller: _glucoseCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 14: A-a Gradient ─────────────────────────────────────────────

class _AaGradientForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _AaGradientForm({required this.onResult, required this.onReset});

  @override
  State<_AaGradientForm> createState() => _AaGradientFormState();
}

class _AaGradientFormState extends State<_AaGradientForm> {
  final _pao2Ctrl = TextEditingController();
  final _paco2Ctrl = TextEditingController();
  final _fio2Ctrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _pbCtrl = TextEditingController();

  @override
  void dispose() {
    _pao2Ctrl.dispose();
    _paco2Ctrl.dispose();
    _fio2Ctrl.dispose();
    _ageCtrl.dispose();
    _pbCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final pao2 = double.tryParse(_pao2Ctrl.text);
    final paco2 = double.tryParse(_paco2Ctrl.text);
    final fio2 = double.tryParse(_fio2Ctrl.text);
    if (pao2 == null || pao2 <= 0 || paco2 == null || paco2 <= 0 ||
        fio2 == null || fio2 <= 0 || fio2 > 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid PaO2, PaCO2, and FiO2 (fraction 0.21–1.0)')));
      return;
    }
    final pbText = _pbCtrl.text.trim();
    final pb = double.tryParse(pbText);
    final barometric = (pb != null && pb > 0) ? pb : 760.0;

    final pAO2 = fio2 * (barometric - 47) - paco2 / 0.8;
    final aaGradient = pAO2 - pao2;

    String interp;
    final ageText = _ageCtrl.text.trim();
    final age = double.tryParse(ageText);
    if (age != null && age > 0) {
      final expected = age / 4 + 4;
      final elevated = aaGradient > expected;
      interp = 'A-a gradient ${aaGradient.toStringAsFixed(1)} mmHg '
          '(expected ≈ ${expected.toStringAsFixed(1)} mmHg for age ${age.toStringAsFixed(0)}y). '
          '${elevated ? 'Elevated — consider V/Q mismatch, shunt, diffusion impairment, or PE.' : 'Within expected range — consider hypoventilation or low FiO2 as cause of hypoxaemia.'}';
    } else {
      final elevated = aaGradient > 15;
      interp = 'A-a gradient ${aaGradient.toStringAsFixed(1)} mmHg. '
          '${elevated ? 'Elevated (> 15 mmHg) — consider V/Q mismatch, shunt, or diffusion impairment.' : 'Normal range — consider hypoventilation or low FiO2.'}';
    }

    widget.onResult(
      result: '${aaGradient.toStringAsFixed(1)} mmHg',
      interpretation: interp,
      educationalNote: 'Formula: PAO2 = FiO2 × (PB − 47) − PaCO2 / 0.8; A-a = PAO2 − PaO2.',
      warning: 'FiO2 must be entered as a fraction (e.g., 0.40 for 40%), not a percentage.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'PaO2 (mmHg)', controller: _pao2Ctrl),
        _NumericField(label: 'PaCO2 (mmHg)', controller: _paco2Ctrl),
        _NumericField(label: 'FiO2 (fraction, e.g. 0.21–1.0)', controller: _fio2Ctrl),
        _NumericField(label: 'Age (years) — optional for expected range', controller: _ageCtrl),
        _NumericField(label: 'Barometric pressure (mmHg, default 760)', controller: _pbCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Calculator 15: PaO2/FiO2 Ratio ─────────────────────────────────────────

class _PaO2FiO2Form extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _PaO2FiO2Form({required this.onResult, required this.onReset});

  @override
  State<_PaO2FiO2Form> createState() => _PaO2FiO2FormState();
}

class _PaO2FiO2FormState extends State<_PaO2FiO2Form> {
  final _pao2Ctrl = TextEditingController();
  final _fio2Ctrl = TextEditingController();

  @override
  void dispose() {
    _pao2Ctrl.dispose();
    _fio2Ctrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final pao2 = double.tryParse(_pao2Ctrl.text);
    final fio2 = double.tryParse(_fio2Ctrl.text);
    if (pao2 == null || pao2 <= 0 || fio2 == null || fio2 < 0.21 || fio2 > 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid PaO2 and FiO2 (fraction 0.21–1.0)')));
      return;
    }
    final pf = pao2 / fio2;
    String band;
    if (pf > 400) {
      band = 'Normal oxygenation';
    } else if (pf >= 300) {
      band = 'Mild ARDS (300–400)';
    } else if (pf >= 200) {
      band = 'Moderate ARDS (200–300)';
    } else {
      band = 'Severe ARDS (< 200)';
    }
    widget.onResult(
      result: '${pf.toStringAsFixed(0)} mmHg — $band',
      interpretation: 'P/F ratio ${pf.toStringAsFixed(0)} mmHg ($band). '
          '${pf < 300 ? 'Consider mechanical ventilation strategy per ARDS protocol.' : ''}',
      educationalNote: 'Berlin ARDS criteria require PEEP ≥ 5 cmH2O at measurement. P/F ratio alone does not diagnose ARDS.',
      warning: 'FiO2 must be entered as a fraction (e.g., 0.60 for 60%), not a percentage.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'PaO2 (mmHg)', controller: _pao2Ctrl),
        _NumericField(label: 'FiO2 (fraction, e.g. 0.21–1.0)', controller: _fio2Ctrl),
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

// ─── Drug Dosing Calculator D1: BSA (Mosteller) ──────────────────────────────

class _BsaForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _BsaForm({required this.onResult, required this.onReset});

  @override
  State<_BsaForm> createState() => _BsaFormState();
}

class _BsaFormState extends State<_BsaForm> {
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
    final rawWeight = double.tryParse(_weightCtrl.text);
    final rawHeight = double.tryParse(_heightCtrl.text);
    if (rawWeight == null || rawWeight <= 0 || rawHeight == null || rawHeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid weight and height')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawWeight : rawWeight / 2.20462;
    final heightCm = _heightUnit == 'cm' ? rawHeight : rawHeight * 100.0;
    // Mosteller: BSA = sqrt(height_cm * weight_kg / 3600)
    final product = heightCm * weightKg / 3600.0;
    final bsa = product > 0 ? _sqrtOf(product) : 0.0;
    widget.onResult(
      result: 'BSA: ${bsa.toStringAsFixed(2)} m²',
      interpretation: 'Calculated body surface area (Mosteller): ${bsa.toStringAsFixed(2)} m². '
          'Used for chemotherapy, cardiac output, and drug dose adjustments.',
      educationalNote: 'Mosteller formula: BSA = √(height_cm × weight_kg / 3600). '
          'Typical adult BSA: 1.6–2.0 m². Not validated for extreme weights.',
    );
  }

  double _sqrtOf(double x) {
    double guess = x / 2.0;
    for (int i = 0; i < 50; i++) {
      guess = (guess + x / guess) / 2.0;
    }
    return guess;
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
            items: ['cm', 'm']
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

// ─── Drug Dosing Calculator D2: eGFR (CKD-EPI 2021 race-free) ────────────────

class _EgfrCkdEpiForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _EgfrCkdEpiForm({required this.onResult, required this.onReset});

  @override
  State<_EgfrCkdEpiForm> createState() => _EgfrCkdEpiFormState();
}

class _EgfrCkdEpiFormState extends State<_EgfrCkdEpiForm> {
  final _ageCtrl = TextEditingController();
  final _scrCtrl = TextEditingController();
  String _sex = 'male';
  String _scrUnit = 'mg/dL';

  @override
  void dispose() {
    _ageCtrl.dispose();
    _scrCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final age = double.tryParse(_ageCtrl.text);
    final rawScr = double.tryParse(_scrCtrl.text);
    if (age == null || age <= 0 || rawScr == null || rawScr <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid age and serum creatinine')));
      return;
    }
    // Convert µmol/L to mg/dL if needed
    final scrMgDl = _scrUnit == 'mg/dL' ? rawScr : rawScr / 88.4;

    // 2021 CKD-EPI race-free coefficients (no race variable — Pitfall #6)
    final bool isFemale = _sex == 'female';
    final double kappa = isFemale ? 0.7 : 0.9;
    final double alpha = isFemale ? -0.241 : -0.302;
    final double sexFactor = isFemale ? 1.012 : 1.0;

    final double ratio = scrMgDl / kappa;
    final double minPart = ratio < 1.0 ? ratio : 1.0;
    final double maxPart = ratio > 1.0 ? ratio : 1.0;

    final double egfr = 142 *
        _powCalc(minPart, alpha) *
        _powCalc(maxPart, -1.200) *
        _powCalc(0.9938, age) *
        sexFactor;

    String band;
    if (egfr >= 90) {
      band = 'G1 – Normal or high';
    } else if (egfr >= 60) {
      band = 'G2 – Mildly decreased';
    } else if (egfr >= 45) {
      band = 'G3a – Mild–moderate decrease';
    } else if (egfr >= 30) {
      band = 'G3b – Moderate–severe decrease';
    } else if (egfr >= 15) {
      band = 'G4 – Severely decreased';
    } else {
      band = 'G5 – Kidney failure';
    }

    widget.onResult(
      result: 'eGFR: ${egfr.toStringAsFixed(1)} mL/min/1.73 m² — $band',
      interpretation: 'Calculated estimate using 2021 CKD-EPI race-free equation: '
          '${egfr.toStringAsFixed(1)} mL/min/1.73 m² ($band). '
          'Adjust drug doses for renally cleared medications.',
      educationalNote: 'Uses the 2021 CKD-EPI race-free equation — no race variable. '
          'Confirm CKD diagnosis with repeat measurement ≥ 3 months apart before staging.',
      warning: 'This is a calculated estimate. Verify against clinical context and '
          'laboratory-reported eGFR before making prescribing decisions.',
    );
  }

  // b^e via Taylor series for ln and exp (avoids dart:math import)
  double _powCalc(double base, double exp) {
    if (base <= 0) return 0.0;
    return _expCalc(exp * _lnCalc(base));
  }

  double _lnCalc(double x) {
    if (x <= 0) return double.negativeInfinity;
    double y = (x - 1) / (x + 1);
    double result = 0.0;
    double term = y;
    for (int i = 1; i <= 60; i++) {
      result += term / (2 * i - 1);
      term *= y * y;
    }
    return 2 * result;
  }

  double _expCalc(double x) {
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 60; i++) {
      term *= x / i;
      result += term;
      if (term.abs() < 1e-15) break;
    }
    return result;
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

// ─── Drug Dosing Calculator D3: Gentamicin/Vancomycin Dosing ─────────────────

class _GentamicinVancomycinForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _GentamicinVancomycinForm({required this.onResult, required this.onReset});

  @override
  State<_GentamicinVancomycinForm> createState() =>
      _GentamicinVancomycinFormState();
}

class _GentamicinVancomycinFormState extends State<_GentamicinVancomycinForm> {
  final _weightCtrl = TextEditingController();
  String _drug = 'Gentamicin';
  String _weightUnit = 'kg';

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawWeight = double.tryParse(_weightCtrl.text);
    if (rawWeight == null || rawWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid weight')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawWeight : rawWeight / 2.20462;

    String result;
    String interpretation;
    String educationalNote;

    if (_drug == 'Gentamicin') {
      final dose = weightKg * 5.0;
      result = 'Gentamicin: ${dose.toStringAsFixed(1)} mg once daily (suggested)';
      interpretation = 'Suggested gentamicin dose: ${dose.toStringAsFixed(1)} mg once daily '
          '(5 mg/kg/day). Adjust based on CrCl and measured trough/peak levels.';
      educationalNote = 'Once-daily dosing based on actual body weight. '
          'Use ideal body weight in obese patients (BMI > 30). '
          'Monitor trough levels (target < 1 mg/L) and check renal function.';
    } else {
      final doseMin = weightKg * 15.0;
      final doseMax = weightKg * 20.0;
      result = 'Vancomycin: ${doseMin.toStringAsFixed(0)}–${doseMax.toStringAsFixed(0)} mg per dose';
      interpretation = 'Suggested vancomycin dose range: '
          '${doseMin.toStringAsFixed(0)}–${doseMax.toStringAsFixed(0)} mg '
          '(15–20 mg/kg/dose) every 8–12 hours. Adjust interval by CrCl.';
      educationalNote = 'Vancomycin dosing is highly variable. '
          'Target AUC/MIC 400–600 mg·h/L (or trough 10–20 mg/L per local guidelines). '
          'Consider loading dose of 25–30 mg/kg for serious infections.';
    }

    widget.onResult(
      result: result,
      interpretation: interpretation,
      educationalNote: educationalNote,
      warning: 'Renally adjust dose by CrCl. Verify trough levels, peak levels, '
          'and consult current formulary before prescribing. These are suggested '
          'starting doses only — individualise to patient renal function and response.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _drug,
          decoration: const InputDecoration(
              labelText: 'Drug', border: OutlineInputBorder(), isDense: true),
          items: ['Gentamicin', 'Vancomycin']
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (v) => setState(() => _drug = v!),
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
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Drug Dosing Calculator D4: Insulin Dose (Correction) ────────────────────

class _InsulinDoseForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _InsulinDoseForm({required this.onResult, required this.onReset});

  @override
  State<_InsulinDoseForm> createState() => _InsulinDoseFormState();
}

class _InsulinDoseFormState extends State<_InsulinDoseForm> {
  final _cbgCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _isfCtrl = TextEditingController();
  String _cbgUnit = 'mmol/L';

  @override
  void dispose() {
    _cbgCtrl.dispose();
    _targetCtrl.dispose();
    _isfCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawCbg = double.tryParse(_cbgCtrl.text);
    final rawTarget = double.tryParse(_targetCtrl.text);
    final rawIsf = double.tryParse(_isfCtrl.text);
    if (rawCbg == null || rawCbg <= 0 ||
        rawTarget == null || rawTarget <= 0 ||
        rawIsf == null || rawIsf <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter valid CBG, target glucose, and ISF')));
      return;
    }
    // Convert mmol/L to mg/dL for calculation
    final cbgMgDl = _cbgUnit == 'mmol/L' ? rawCbg * 18.0182 : rawCbg;
    final targetMgDl = _cbgUnit == 'mmol/L' ? rawTarget * 18.0182 : rawTarget;
    // Convert ISF to mg/dL units when CBG is in mmol/L (user enters ISF in same units as CBG)
    final isfMgDl = _cbgUnit == 'mmol/L' ? rawIsf * 18.0182 : rawIsf;
    final raw = (cbgMgDl - targetMgDl) / isfMgDl;
    final correctionDose = raw < 0 ? 0.0 : raw;

    final cbgDisplay = _cbgUnit == 'mmol/L'
        ? '${rawCbg.toStringAsFixed(1)} mmol/L'
        : '${rawCbg.toStringAsFixed(0)} mg/dL';

    widget.onResult(
      result: 'Correction dose: ${correctionDose.toStringAsFixed(1)} units',
      interpretation: 'Current CBG $cbgDisplay. '
          'Correction dose: ${correctionDose.toStringAsFixed(1)} units of rapid-acting insulin. '
          '${correctionDose == 0.0 ? 'CBG is at or below target — no correction needed.' : ''}',
      educationalNote: 'Correction dose = (CBG − target) ÷ ISF. '
          'Negative values are clamped to 0. '
          'ISF (Insulin Sensitivity Factor): the drop in blood glucose per unit of insulin.',
      warning: 'This is a correction dose estimate only — it is NOT a substitute for your '
          'prescribed insulin regimen. Always follow your care team\'s instructions. '
          'Hypoglycaemia risk: do not stack correction doses.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
              child: _NumericField(
                  label: 'Current blood glucose (CBG)', controller: _cbgCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _cbgUnit,
            items: ['mmol/L', 'mg/dL']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _cbgUnit = v!),
          ),
        ]),
        _NumericField(
            label: 'Target glucose (same unit as CBG)',
            controller: _targetCtrl),
        _NumericField(
            label: 'ISF (${_cbgUnit == 'mmol/L' ? 'mmol/L' : 'mg/dL'} drop per unit of insulin)',
            controller: _isfCtrl),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Drug Dosing Calculator D5: Paracetamol (Acetaminophen) Dosing ───────────

class _ParacetamolDosingForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _ParacetamolDosingForm({required this.onResult, required this.onReset});

  @override
  State<_ParacetamolDosingForm> createState() => _ParacetamolDosingFormState();
}

class _ParacetamolDosingFormState extends State<_ParacetamolDosingForm> {
  final _weightCtrl = TextEditingController();
  String _weightUnit = 'kg';
  String _ageGroup = 'adult';

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawWeight = double.tryParse(_weightCtrl.text);
    if (rawWeight == null || rawWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter valid weight')));
      return;
    }
    final weightKg = _weightUnit == 'kg' ? rawWeight : rawWeight / 2.20462;

    String result;
    String interpretation;
    String educationalNote;
    String? warning;

    if (_ageGroup == 'child') {
      // Child (<12 y): 15 mg/kg/dose, max 4 doses/24h, max 60 mg/kg/day
      final perDose = weightKg * 15.0;
      final dailyByDose = perDose * 4;
      final maxDailyByKg = weightKg * 60.0;
      final daily = dailyByDose < maxDailyByKg ? dailyByDose : maxDailyByKg;
      result = '${perDose.toStringAsFixed(0)} mg/dose | ${daily.toStringAsFixed(0)} mg/day max';
      interpretation = 'Child dose (15 mg/kg/dose): ${perDose.toStringAsFixed(0)} mg per dose, '
          'up to 4 doses per 24 hours. Maximum daily dose: ${daily.toStringAsFixed(0)} mg '
          '(60 mg/kg/day cap).';
      educationalNote = 'Interval: every 4–6 hours as needed. '
          'Do not exceed 4 doses in 24 hours. '
          'Reduce in malnourished children or hepatic impairment.';
    } else {
      // Adult: 500–1000 mg q4-6h, max 4 g/day
      result = '500–1000 mg per dose (q4–6h) | max 4 g/day';
      interpretation = 'Standard adult dose: 500–1000 mg per dose every 4–6 hours as needed, '
          'up to 4 doses per 24 hours. Maximum daily dose: 4000 mg (4 g/day).';
      educationalNote = 'Weight-based dosing (15 mg/kg) may be preferred for lower weight adults '
          '(< 50 kg). Reduce maximum daily dose in hepatic impairment, chronic alcohol use, '
          'or malnutrition.';
      // Warn if weight-based limit is below 4 g adult cap
      final weightBasedDaily = weightKg * 60.0;
      if (weightBasedDaily < 4000.0) {
        warning = 'Patient weight ${weightKg.toStringAsFixed(1)} kg: weight-based limit '
            '(${weightBasedDaily.toStringAsFixed(0)} mg/day, ${(weightKg * 15).toStringAsFixed(0)} mg/dose × 4) '
            'is below the standard 4 g/day adult cap. Verify against formulary.';
      }
    }

    widget.onResult(
      result: result,
      interpretation: interpretation,
      educationalNote: educationalNote,
      warning: warning ??
          'Verify dose against patient weight, hepatic function, and current formulary. '
          'Paracetamol toxicity risk is higher with fasting, hepatic impairment, '
          'or concomitant hepatotoxic drugs.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
              child: _NumericField(label: 'Weight', controller: _weightCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _weightUnit,
            items: ['kg', 'lb']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _weightUnit = v!),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _ageGroup,
          decoration: const InputDecoration(
              labelText: 'Age group', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'adult', child: Text('Adult')),
            DropdownMenuItem(
                value: 'child', child: Text('Child (< 12 years)')),
          ],
          onChanged: (v) => setState(() => _ageGroup = v!),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P2: APLS Weight Estimation ───────────────────────

class _AplsWeightForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _AplsWeightForm({required this.onResult, required this.onReset});

  @override
  State<_AplsWeightForm> createState() => _AplsWeightFormState();
}

class _AplsWeightFormState extends State<_AplsWeightForm> {
  final _ageCtrl = TextEditingController();
  String _ageUnit = 'years';

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawAge = double.tryParse(_ageCtrl.text);
    if (rawAge == null || rawAge < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid age')));
      return;
    }

    double estimatedKg;
    String formula;

    if (_ageUnit == 'months') {
      // < 1 year: weight (kg) = 0.5 × (months + 9)
      if (rawAge <= 0 || rawAge > 12) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Age in months should be 1–12 for this band')));
        return;
      }
      estimatedKg = 0.5 * (rawAge + 9);
      formula = '0.5 × (${rawAge.toStringAsFixed(0)} months + 9) = ${estimatedKg.toStringAsFixed(1)} kg';
    } else {
      // years
      final ageYears = rawAge;
      if (ageYears <= 0 || ageYears > 12) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('APLS formulas apply to children aged 0–12 years')));
        return;
      }
      if (ageYears < 1) {
        // Treat as < 1 year using age in months
        final months = ageYears * 12;
        estimatedKg = 0.5 * (months + 9);
        formula = '0.5 × (${months.toStringAsFixed(1)} months + 9) = ${estimatedKg.toStringAsFixed(1)} kg';
      } else if (ageYears <= 5) {
        // 1–5 years: 2 × (age + 4)
        estimatedKg = 2 * (ageYears + 4);
        formula = '2 × (${ageYears.toStringAsFixed(0)} + 4) = ${estimatedKg.toStringAsFixed(1)} kg';
      } else {
        // 6–12 years: 3 × age + 7
        estimatedKg = 3 * ageYears + 7;
        formula = '3 × ${ageYears.toStringAsFixed(0)} + 7 = ${estimatedKg.toStringAsFixed(1)} kg';
      }
    }

    widget.onResult(
      result: '${estimatedKg.toStringAsFixed(1)} kg (estimated)',
      interpretation: 'Estimated weight: ${estimatedKg.toStringAsFixed(1)} kg\nFormula used: $formula',
      educationalNote: 'APLS formulas: < 1y: 0.5×(months+9); 1–5y: 2×(age+4); 6–12y: 3×age+7.',
      warning: 'This is an estimation — use actual weight for precise drug dosing whenever available.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _NumericField(label: 'Age', controller: _ageCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _ageUnit,
            items: const [
              DropdownMenuItem(value: 'years', child: Text('years')),
              DropdownMenuItem(value: 'months', child: Text('months')),
            ],
            onChanged: (v) => setState(() => _ageUnit = v!),
          ),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P3: Broselow Tape Equivalent ─────────────────────

class _BroselowForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _BroselowForm({required this.onResult, required this.onReset});

  @override
  State<_BroselowForm> createState() => _BroselowFormState();
}

class _BroselowFormState extends State<_BroselowForm> {
  final _lengthCtrl = TextEditingController();

  // Broselow zones: (minCm, maxCm, colour, weightRangeKg)
  static const _zones = [
    (46.0, 59.0, 'Grey',   '3–5 kg'),
    (59.0, 70.0, 'Pink',   '6–7 kg'),
    (70.0, 80.0, 'Red',    '8–9 kg'),
    (80.0, 90.0, 'Purple', '10–11 kg'),
    (90.0, 100.0,'Yellow', '12–14 kg'),
    (100.0, 110.0,'White', '15–18 kg'),
    (110.0, 120.0,'Blue',  '19–22 kg'),
    (120.0, 131.0,'Orange','24–29 kg'),
    (131.0, 146.0,'Green', '30–36 kg'),
  ];

  @override
  void dispose() {
    _lengthCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawLen = double.tryParse(_lengthCtrl.text);
    if (rawLen == null || rawLen <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid length in cm')));
      return;
    }

    if (rawLen < 46) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broselow tape starts at 46 cm')));
      return;
    }
    if (rawLen > 146) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broselow tape not validated above 146 cm — use weight-based dosing')));
      return;
    }

    String colour = '';
    String weightRange = '';
    for (final z in _zones) {
      if (rawLen >= z.$1 && rawLen < z.$2) {
        colour = z.$3;
        weightRange = z.$4;
        break;
      }
    }
    // Edge case: exactly 146 cm falls in Green zone
    if (colour.isEmpty) {
      colour = 'Green';
      weightRange = '30–36 kg';
    }

    widget.onResult(
      result: '$colour zone — $weightRange',
      interpretation: 'Length ${rawLen.toStringAsFixed(0)} cm falls in the $colour Broselow zone.\n'
          'Estimated weight range: $weightRange.\n'
          'Use the midpoint weight with the weight-based dosing calculator for drug dose calculations.',
      educationalNote: 'Drug dose columns are deferred — use the estimated weight with the weight-dosing calculator.',
      warning: 'This is an estimate based on length only. Obtain actual weight for precise dosing whenever possible.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Length / Height (cm)', controller: _lengthCtrl),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Find Zone')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P4: Pediatric BP Percentiles ─────────────────────

class _PediatricBpForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _PediatricBpForm({required this.onResult, required this.onReset});

  @override
  State<_PediatricBpForm> createState() => _PediatricBpFormState();
}

class _PediatricBpFormState extends State<_PediatricBpForm> {
  final _ageCtrl = TextEditingController();
  final _sbpCtrl = TextEditingController();
  final _dbpCtrl = TextEditingController();
  String _sex = 'male';

  // Simplified 95th-percentile SBP by age and sex (2017 AAP CPG, Table 3 approximations)
  // Key: age (years 1–17), value: [male_95th, female_95th]
  static const Map<int, List<int>> _sbp95th = {
    1:  [100, 100], 2:  [102, 101], 3:  [104, 103], 4:  [106, 104],
    5:  [108, 106], 6:  [110, 108], 7:  [111, 110], 8:  [112, 111],
    9:  [114, 113], 10: [115, 115], 11: [117, 117], 12: [120, 119],
    13: [122, 121], 14: [125, 122], 15: [128, 123], 16: [130, 124],
    17: [132, 125],
  };

  static const Map<int, List<int>> _dbp95th = {
    1:  [62, 62], 2:  [63, 63], 3:  [65, 65], 4:  [66, 66],
    5:  [68, 68], 6:  [70, 70], 7:  [71, 71], 8:  [72, 72],
    9:  [74, 74], 10: [75, 75], 11: [76, 76], 12: [78, 78],
    13: [79, 79], 14: [80, 79], 15: [81, 80], 16: [82, 80],
    17: [82, 80],
  };

  @override
  void dispose() {
    _ageCtrl.dispose();
    _sbpCtrl.dispose();
    _dbpCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawAge = int.tryParse(_ageCtrl.text);
    final rawSbp = double.tryParse(_sbpCtrl.text);
    final rawDbp = double.tryParse(_dbpCtrl.text);

    if (rawAge == null || rawAge < 1 || rawAge > 17) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Age must be 1–17 years for paediatric BP classification')));
      return;
    }
    if (rawSbp == null || rawSbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid SBP')));
      return;
    }
    if (rawDbp == null || rawDbp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid DBP')));
      return;
    }

    final sexIdx = _sex == 'male' ? 0 : 1;
    final sbp95 = _sbp95th[rawAge]![sexIdx];
    final dbp95 = _dbp95th[rawAge]![sexIdx];
    final sbp90 = sbp95 - 7;  // approximate 90th from 95th
    final dbp90 = dbp95 - 5;

    String sbpClass;
    String dbpClass;

    // SBP classification
    if (rawSbp < sbp90) {
      sbpClass = 'Normal';
    } else if (rawSbp < sbp95) {
      sbpClass = 'Elevated';
    } else if (rawSbp < sbp95 + 12) {
      sbpClass = 'Stage 1 HTN';
    } else {
      sbpClass = 'Stage 2 HTN';
    }

    // DBP classification
    if (rawDbp < dbp90) {
      dbpClass = 'Normal';
    } else if (rawDbp < dbp95) {
      dbpClass = 'Elevated';
    } else if (rawDbp < dbp95 + 12) {
      dbpClass = 'Stage 1 HTN';
    } else {
      dbpClass = 'Stage 2 HTN';
    }

    // Overall: use worst of SBP/DBP
    const order = ['Normal', 'Elevated', 'Stage 1 HTN', 'Stage 2 HTN'];
    final overall = order.indexOf(sbpClass) >= order.indexOf(dbpClass) ? sbpClass : dbpClass;

    widget.onResult(
      result: 'Overall: $overall (SBP: $sbpClass, DBP: $dbpClass)',
      interpretation: 'Age $rawAge ${_sex == 'male' ? 'M' : 'F'}: '
          'SBP ${rawSbp.toStringAsFixed(0)} mmHg → $sbpClass (95th ≈ $sbp95 mmHg); '
          'DBP ${rawDbp.toStringAsFixed(0)} mmHg → $dbpClass (95th ≈ $dbp95 mmHg).\n'
          'Overall classification: $overall.',
      educationalNote: 'Simplified thresholds — verify against full 2017 AAP tables (height-specific percentiles).',
      warning: 'This uses simplified 2017 AAP thresholds. Confirm against full age/sex/height-specific table. '
          'BP diagnosis requires ≥ 3 measurements on separate occasions.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Age (years, 1–17)', controller: _ageCtrl),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(
              labelText: 'Sex', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _sex = v!),
        ),
        const SizedBox(height: 12),
        _NumericField(label: 'SBP (mmHg)', controller: _sbpCtrl),
        const SizedBox(height: 12),
        _NumericField(label: 'DBP (mmHg)', controller: _dbpCtrl),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Classify')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P5: Neonatal Bilirubin (Phototherapy) ────────────

class _NeonatalBilirubinForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _NeonatalBilirubinForm({required this.onResult, required this.onReset});

  @override
  State<_NeonatalBilirubinForm> createState() => _NeonatalBilirubinFormState();
}

class _NeonatalBilirubinFormState extends State<_NeonatalBilirubinForm> {
  final _bilirubinCtrl = TextEditingController();
  final _ageHoursCtrl  = TextEditingController();
  String _unit = 'mg/dL';
  String _risk = 'low';

  @override
  void dispose() {
    _bilirubinCtrl.dispose();
    _ageHoursCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawBili  = double.tryParse(_bilirubinCtrl.text);
    final rawHours = double.tryParse(_ageHoursCtrl.text);

    if (rawBili == null || rawBili <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid bilirubin level')));
      return;
    }
    if (rawHours == null || rawHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid age in hours')));
      return;
    }
    if (rawHours > 168) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Age > 168 hours: use community guidelines for this age range')));
      return;
    }

    // Convert umol/L to mg/dL if needed
    final biliMgdL = _unit == 'µmol/L' ? rawBili / 17.1 : rawBili;
    final hours = rawHours;

    // Simplified Bhutani-based phototherapy thresholds (mg/dL) by age-hours and risk
    double lowThreshold;
    double highThreshold;

    if (hours <= 24) {
      lowThreshold  = _risk == 'low' ? 12.0 : (_risk == 'medium' ? 10.0 : 8.0);
      highThreshold = _risk == 'low' ? 15.0 : (_risk == 'medium' ? 13.0 : 11.0);
    } else if (hours <= 48) {
      lowThreshold  = _risk == 'low' ? 15.0 : (_risk == 'medium' ? 13.0 : 11.0);
      highThreshold = _risk == 'low' ? 18.0 : (_risk == 'medium' ? 16.0 : 14.0);
    } else if (hours <= 72) {
      lowThreshold  = _risk == 'low' ? 17.0 : (_risk == 'medium' ? 15.0 : 13.0);
      highThreshold = _risk == 'low' ? 20.0 : (_risk == 'medium' ? 18.0 : 16.0);
    } else {
      lowThreshold  = _risk == 'low' ? 18.0 : (_risk == 'medium' ? 16.0 : 14.0);
      highThreshold = _risk == 'low' ? 21.0 : (_risk == 'medium' ? 19.0 : 17.0);
    }

    String zone;
    String guidance;

    if (biliMgdL >= highThreshold) {
      zone = 'High risk zone';
      guidance = 'Consider starting phototherapy. Recheck in 4–6 hours.';
    } else if (biliMgdL >= lowThreshold) {
      zone = 'Intermediate zone';
      guidance = 'Borderline — consider phototherapy based on clinical picture. Recheck in 4–8 hours.';
    } else {
      zone = 'Low risk zone';
      guidance = 'Below phototherapy threshold — routine monitoring. Repeat TcB/TSB per clinical protocol.';
    }

    final umolL = biliMgdL * 17.1;
    widget.onResult(
      result: '$zone — ${biliMgdL.toStringAsFixed(1)} mg/dL (${umolL.toStringAsFixed(0)} µmol/L)',
      interpretation: 'Bilirubin ${biliMgdL.toStringAsFixed(1)} mg/dL at ${hours.toStringAsFixed(0)} hours of age '
          '($_risk risk).\n'
          'Zone: $zone. Phototherapy threshold: low ${lowThreshold.toStringAsFixed(0)} mg/dL, '
          'high ${highThreshold.toStringAsFixed(0)} mg/dL.\n$guidance',
      educationalNote: 'Thresholds derived from simplified Bhutani nomogram. 1 mg/dL = 17.1 µmol/L.',
      warning: 'These thresholds are a guide only — confirm against your local AAP phototherapy nomogram '
          'and institutional guidelines. Not validated for infants < 35 weeks gestation.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: _NumericField(label: 'Bilirubin', controller: _bilirubinCtrl)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _unit,
            items: const [
              DropdownMenuItem(value: 'mg/dL', child: Text('mg/dL')),
              DropdownMenuItem(value: 'µmol/L', child: Text('µmol/L')),
            ],
            onChanged: (v) => setState(() => _unit = v!),
          ),
        ]),
        const SizedBox(height: 12),
        _NumericField(label: 'Age (hours)', controller: _ageHoursCtrl),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _risk,
          decoration: const InputDecoration(
              labelText: 'Risk category', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low (no risk factors)')),
            DropdownMenuItem(value: 'medium', child: Text('Medium (mild risk factors)')),
            DropdownMenuItem(value: 'high', child: Text('High (haemolysis / G6PD / early jaundice)')),
          ],
          onChanged: (v) => setState(() => _risk = v!),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P6: APGAR Score ──────────────────────────────────

class _ApgarForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _ApgarForm({required this.onResult, required this.onReset});

  @override
  State<_ApgarForm> createState() => _ApgarFormState();
}

class _ApgarFormState extends State<_ApgarForm> {
  int _appearance  = 2;
  int _pulse       = 2;
  int _grimace     = 2;
  int _activity    = 2;
  int _respiration = 2;

  void _calculate() {
    final total = _appearance + _pulse + _grimace + _activity + _respiration;
    String band;
    String interp;

    if (total >= 7) {
      band   = 'Reassuring';
      interp = 'APGAR $total/10 — Reassuring. Routine newborn care.';
    } else if (total >= 4) {
      band   = 'Moderately abnormal';
      interp = 'APGAR $total/10 — Moderately abnormal. Supplemental oxygen and stimulation; '
          'prepare for resuscitation if score does not improve at 5 min.';
    } else {
      band   = 'Low';
      interp = 'APGAR $total/10 — Low. Immediate resuscitation required. '
          'Initiate Newborn Life Support protocol.';
    }

    widget.onResult(
      result: '$total/10 — $band',
      interpretation: '$interp\n'
          'A: $_appearance  P: $_pulse  G: $_grimace  A: $_activity  R: $_respiration',
      educationalNote: 'Reassess at 5 min and 10 min if ≤ 6 at 5 min. '
          'Do not delay resuscitation to complete the APGAR score.',
      warning: 'APGAR is a communication tool — not a predictor of long-term neurological outcome.',
    );
  }

  Widget _apgarRow(String label, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          items: const [
            DropdownMenuItem(value: 0, child: Text('0')),
            DropdownMenuItem(value: 1, child: Text('1')),
            DropdownMenuItem(value: 2, child: Text('2')),
          ],
          onChanged: (v) => setState(() => onChanged(v!)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _apgarRow('Appearance (colour)',    _appearance,  (v) => _appearance  = v),
        _apgarRow('Pulse (heart rate)',      _pulse,       (v) => _pulse       = v),
        _apgarRow('Grimace (reflex)',         _grimace,     (v) => _grimace     = v),
        _apgarRow('Activity (muscle tone)',   _activity,    (v) => _activity    = v),
        _apgarRow('Respiration',              _respiration, (v) => _respiration = v),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Calculate')),
      ],
    );
  }
}

// ─── Paediatrics Calculator P7: WHO Growth Percentile ────────────────────────

class _GrowthPercentileForm extends StatefulWidget {
  final void Function({required String result, required String interpretation, String? educationalNote, String? warning}) onResult;
  final VoidCallback onReset;
  const _GrowthPercentileForm({required this.onResult, required this.onReset});

  @override
  State<_GrowthPercentileForm> createState() => _GrowthPercentileFormState();
}

class _GrowthPercentileFormState extends State<_GrowthPercentileForm> {
  final _weightCtrl    = TextEditingController();
  final _heightCtrl    = TextEditingController();
  final _hcCtrl        = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  String _sex = 'male';

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _hcCtrl.dispose();
    _ageMonthsCtrl.dispose();
    super.dispose();
  }

  // Simplified WHO median weight-for-age (kg) and approximate SD by age in months
  static const Map<int, List<double>> _whoWeightMale = {
    0:  [3.3, 0.45], 3: [6.0, 0.73], 6: [7.9, 0.87], 9: [9.2, 0.95],
    12: [10.2, 1.0], 18: [11.5, 1.1], 24: [12.2, 1.2], 36: [14.3, 1.4],
    48: [16.3, 1.6], 60: [18.3, 1.8],
  };
  static const Map<int, List<double>> _whoWeightFemale = {
    0:  [3.2, 0.44], 3: [5.6, 0.67], 6: [7.3, 0.81], 9: [8.6, 0.89],
    12: [9.5, 0.93], 18: [10.8, 1.0], 24: [11.5, 1.1], 36: [13.9, 1.3],
    48: [15.9, 1.5], 60: [18.2, 1.7],
  };

  String _zoneLabel(double z) {
    if (z < -2) return 'Below 3rd percentile (< −2 SD)';
    if (z > 2)  return 'Above 97th percentile (> +2 SD)';
    return 'Normal range (−2 to +2 SD)';
  }

  int _nearestAge(int ageMonths) {
    const ages = [0, 3, 6, 9, 12, 18, 24, 36, 48, 60];
    int best = ages.first;
    int bestDiff = (ageMonths - best).abs();
    for (final a in ages) {
      final diff = (ageMonths - a).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = a;
      }
    }
    return best;
  }

  void _calculate() {
    final rawWeight = double.tryParse(_weightCtrl.text);
    final rawHeight = double.tryParse(_heightCtrl.text);
    final rawAge    = int.tryParse(_ageMonthsCtrl.text);
    final rawHc     = double.tryParse(_hcCtrl.text);

    if (rawWeight == null || rawWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid weight')));
      return;
    }
    if (rawHeight == null || rawHeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid height/length')));
      return;
    }
    if (rawAge == null || rawAge < 0 || rawAge > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Age must be 0–60 months for WHO Growth Standards')));
      return;
    }

    final nearAge = _nearestAge(rawAge);
    final ref     = (_sex == 'male' ? _whoWeightMale : _whoWeightFemale)[nearAge]!;
    final median  = ref[0];
    final sd      = ref[1];

    final weightZ    = (rawWeight - median) / sd;
    final weightZone = _zoneLabel(weightZ);

    // Simplified height-for-age approximation
    final heightMedian = _sex == 'male'
        ? 45.0 + rawAge * 1.2
        : 44.0 + rawAge * 1.18;
    const heightSd = 2.5;
    final heightZ    = (rawHeight - heightMedian) / heightSd;
    final heightZone = _zoneLabel(heightZ);

    final buffer = StringBuffer();
    buffer.writeln('Weight ${rawWeight.toStringAsFixed(1)} kg: $weightZone (z ≈ ${weightZ.toStringAsFixed(1)})');
    buffer.writeln('Height ${rawHeight.toStringAsFixed(1)} cm: $heightZone (z ≈ ${heightZ.toStringAsFixed(1)})');

    if (rawHc != null && rawHc > 0) {
      // Simplified head circumference approximation
      final hcMedian = 34.0 + rawAge * 0.1;
      const hcSd = 1.5;
      final hcZ    = (rawHc - hcMedian) / hcSd;
      final hcZone = _zoneLabel(hcZ);
      buffer.writeln('HC ${rawHc.toStringAsFixed(1)} cm: $hcZone (z ≈ ${hcZ.toStringAsFixed(1)})');
    }

    widget.onResult(
      result: 'Weight: $weightZone',
      interpretation: buffer.toString().trim(),
      educationalNote: 'Simplified WHO z-score bands (not full LMS method). '
          'Results are approximate — use full WHO growth charts for clinical decisions.',
      warning: 'Simplified z-score band estimates only, not precise percentiles. '
          'For clinical growth monitoring, plot on the full WHO growth chart for the child\'s age and sex.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumericField(label: 'Weight (kg)', controller: _weightCtrl),
        const SizedBox(height: 12),
        _NumericField(label: 'Height / Length (cm)', controller: _heightCtrl),
        const SizedBox(height: 12),
        _NumericField(label: 'Head circumference (cm, optional)', controller: _hcCtrl),
        const SizedBox(height: 12),
        _NumericField(label: 'Age (months, 0–60)', controller: _ageMonthsCtrl),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(
              labelText: 'Sex', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
          ],
          onChanged: (v) => setState(() => _sex = v!),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _calculate, child: const Text('Classify')),
      ],
    );
  }
}
