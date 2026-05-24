import 'package:flutter/material.dart';
import '../../models/user_settings.dart' as models;
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
  }) {
    onUpdate(settings.copyWith(
      theme: theme,
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
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
            color: isSelected
                ? AppColors.brandPink
                : theme.dividerColor,
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
