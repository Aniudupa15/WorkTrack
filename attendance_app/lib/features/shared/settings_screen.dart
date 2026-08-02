import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/features/shared/theme_controller.dart';

/// App preferences. Currently the appearance (theme) selection, persisted
/// across launches via [ThemeController].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'APPEARANCE',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  mode: ThemeMode.system,
                  current: controller.mode,
                  icon: Icons.brightness_auto_rounded,
                  label: 'System default',
                  onSelected: controller.setMode,
                ),
                Divider(height: 1, color: colors.border),
                _ThemeTile(
                  mode: ThemeMode.light,
                  current: controller.mode,
                  icon: Icons.light_mode_rounded,
                  label: 'Light',
                  onSelected: controller.setMode,
                ),
                Divider(height: 1, color: colors.border),
                _ThemeTile(
                  mode: ThemeMode.dark,
                  current: controller.mode,
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  onSelected: controller.setMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text(
              'PunchIn',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.current,
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final ThemeMode mode;
  final ThemeMode current;
  final IconData icon;
  final String label;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = mode == current;
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? colors.brand : colors.textSecondary,
      ),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.brand)
          : const Icon(Icons.circle_outlined),
      onTap: () => onSelected(mode),
    );
  }
}
