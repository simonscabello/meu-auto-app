import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/quick_add_sheet.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Semantics(
        button: true,
        label: 'Adicionar',
        excludeSemantics: true,
        child: FloatingActionButton(
          tooltip: 'Adicionar',
          onPressed: () => QuickAddSheet.show(context),
          child: const Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(
              index: 0,
              currentIndex: navigationShell.currentIndex,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Início',
              onTap: _goBranch,
            ),
            _NavItem(
              index: 1,
              currentIndex: navigationShell.currentIndex,
              icon: Icons.build_outlined,
              selectedIcon: Icons.build,
              label: 'Cuidados',
              onTap: _goBranch,
            ),
            const SizedBox(width: 72),
            _NavItem(
              index: 2,
              currentIndex: navigationShell.currentIndex,
              icon: Icons.history,
              selectedIcon: Icons.history,
              label: 'Histórico',
              onTap: _goBranch,
            ),
            _NavItem(
              index: 3,
              currentIndex: navigationShell.currentIndex,
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Perfil',
              onTap: _goBranch,
            ),
          ],
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: () => onTap(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTapTarget,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 24),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
