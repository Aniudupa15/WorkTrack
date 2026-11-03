import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One destination in [AppBottomNav].
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge = false,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;

  /// Shows a small red dot on the icon (something needs attention).
  final bool badge;
}

/// The app's bottom tab bar: white, hairline top border, and the active tab's
/// icon sitting on a soft teal pill.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _tab(context, items[i], i == currentIndex, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, AppNavItem item, bool active, int index) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkResponse(
        onTap: () => onTap(index),
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              height: 30,
              decoration: BoxDecoration(
                color: active ? colors.brandSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    active ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 22,
                    color: active ? colors.brand : colors.textTertiary,
                  ),
                  if (item.badge)
                    Positioned(
                      top: 4,
                      right: 14,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? colors.brandStrong : colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
