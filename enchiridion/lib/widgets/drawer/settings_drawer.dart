import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../models/user_settings.dart' as models;
import '../../screens/diagnostics_log_screen.dart';
import '../../theme/app_colors.dart';
import '../../constants/app_strings.dart';

class SettingsPanel extends StatelessWidget {
  final models.UserSettings settings;
  final Function(models.UserSettings) onUpdate;
  final VoidCallback? onLogout;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onUpdate,
    this.onLogout,
  });

  void _update({
    models.ThemeMode? theme,
    int? fontSize,
    double? lineHeight,
    models.FontFamily? fontFamily,
    bool? studyBuddyEnabled,
    int? studyBuddyIntervalMinutes,
  }) {
    onUpdate(settings.copyWith(
      theme: theme,
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
      studyBuddyEnabled: studyBuddyEnabled,
      studyBuddyIntervalMinutes: studyBuddyIntervalMinutes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme Selection
        _buildSectionTitle(AppStrings.themeSection, theme),
        const SizedBox(height: 12),
        Row(
          children: models.ThemeMode.values.map((mode) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ThemeButton(
                  mode: mode,
                  isSelected: settings.theme == mode,
                  onTap: () => _update(theme: mode),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Font Family Selection
        _buildSectionTitle(AppStrings.typefaceSection, theme),
        const SizedBox(height: 12),
        Row(
          children: models.FontFamily.values.map((font) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _FontButton(
                  fontFamily: font,
                  isSelected: settings.fontFamily == font,
                  onTap: () => _update(fontFamily: font),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Font Size Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(AppStrings.sizeSection, theme),
            Text(
              '${settings.fontSize}%',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.neonTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: settings.fontSize.toDouble(),
          min: 75,
          max: 200,
          divisions: 25,
          onChanged: (value) => _update(fontSize: value.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('A', style: theme.textTheme.bodySmall),
            Text('A', style: theme.textTheme.titleLarge),
          ],
        ),

        const SizedBox(height: 32),

        // Line Height Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(AppStrings.spacingSection, theme),
            Text(
              settings.lineHeight.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.neonTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: settings.lineHeight,
          min: 1.0,
          max: 2.5,
          divisions: 15,
          onChanged: (value) => _update(lineHeight: value),
        ),

        // Android-only: ambient prompts are armed through a WorkManager chain
        // with no iOS/desktop equivalent (arming is Platform.isAndroid-gated in
        // SettingsProvider), so rendering these controls anywhere else offers a
        // switch that silently does nothing.
        if (defaultTargetPlatform == TargetPlatform.android) ...[
          const SizedBox(height: 32),
          _buildSectionTitle(AppStrings.studyBuddySection, theme),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.studyBuddyEnabled,
            onChanged: (value) => _update(studyBuddyEnabled: value),
            title: const Text('Study Buddy prompts'),
            subtitle: const Text(
                'A practice question every so often, even when the app is closed.'),
            contentPadding: EdgeInsets.zero,
          ),
          _StudyBuddyIntervalSlider(
            intervalMinutes: settings.studyBuddyIntervalMinutes,
            enabled: settings.studyBuddyEnabled,
            onChangedEnd: (minutes) =>
                _update(studyBuddyIntervalMinutes: minutes),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Diagnostics log'),
            subtitle: const Text(
                'Timeline of app and Study Buddy activity, for troubleshooting.'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsLogScreen()),
            ),
          ),
        ],

        if (onLogout != null) ...[
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Interval slider for Study Buddy's ambient prompt spacing.
///
/// Tracks the dragged value locally and only reports it back to the parent
/// (which persists to prefs and re-arms the native WorkManager chain — a
/// real cancel-and-reschedule since the interval-change fix uses REPLACE)
/// on release. Reporting on every drag tick would spam that native call for
/// every one of the slider's 21 divisions crossed while dragging.
class _StudyBuddyIntervalSlider extends StatefulWidget {
  final int intervalMinutes;
  final bool enabled;
  final ValueChanged<int> onChangedEnd;

  const _StudyBuddyIntervalSlider({
    required this.intervalMinutes,
    required this.enabled,
    required this.onChangedEnd,
  });

  @override
  State<_StudyBuddyIntervalSlider> createState() =>
      _StudyBuddyIntervalSliderState();
}

class _StudyBuddyIntervalSliderState extends State<_StudyBuddyIntervalSlider> {
  late double _value = widget.intervalMinutes.toDouble().clamp(15, 120);

  @override
  void didUpdateWidget(covariant _StudyBuddyIntervalSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intervalMinutes != widget.intervalMinutes) {
      _value = widget.intervalMinutes.toDouble().clamp(15, 120);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Every'),
            Text(
              '${_value.round()} min',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.neonTeal,
              ),
            ),
          ],
        ),
        Slider(
          value: _value,
          min: 15,
          max: 120,
          divisions: 21,
          onChanged: widget.enabled
              ? (value) => setState(() => _value = value)
              : null,
          onChangeEnd: widget.enabled
              ? (value) => widget.onChangedEnd(value.round())
              : null,
        ),
      ],
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final models.ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeButton({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (mode) {
      case models.ThemeMode.light:
        backgroundColor = AppColors.paper;
        textColor = AppColors.inkCharcoal;
        borderColor = Colors.grey.shade300;
        break;
      case models.ThemeMode.sepia:
        backgroundColor = AppColors.sepiaBackground;
        textColor = AppColors.sepiaText;
        borderColor = AppColors.sepiaBorder;
        break;
      case models.ThemeMode.dark:
        backgroundColor = AppColors.deepSpace;
        textColor = AppColors.frost;
        borderColor = AppColors.inkCharcoal;
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: isSelected ? AppColors.brandPink : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            mode.name.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _FontButton extends StatelessWidget {
  final models.FontFamily fontFamily;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontButton({
    required this.fontFamily,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fontName;
    String displayFamily;

    switch (fontFamily) {
      case models.FontFamily.sans:
        fontName = 'Sans';
        displayFamily = 'sans-serif';
        break;
      case models.FontFamily.serif:
        fontName = 'Serif';
        displayFamily = 'serif';
        break;
      case models.FontFamily.mono:
        fontName = 'Mono';
        displayFamily = 'monospace';
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandPink.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.brandPink : theme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            fontName,
            style: TextStyle(
              fontSize: 14,
              fontFamily: displayFamily,
              color: isSelected
                  ? AppColors.brandPink
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
