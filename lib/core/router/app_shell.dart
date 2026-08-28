import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The four top-level destinations, split by where in time they sit.
///
/// Início is now, Cuidados is what is coming, Histórico is what happened, and
/// Perfil is the account. That division is why four is enough: every screen
/// in the app answers one of those questions, and a fifth tab would only be a
/// second door into one of them.
///
/// There is no global add button. The one that used to sit in the middle of
/// this bar opened a sheet of seven things, which made adding a two-step
/// choice from a control that could not say what it would do; and it was
/// present on screens where none of the seven was the obvious next move.
/// Each screen now offers its own action, in its own words.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Início',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Cuidados',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
            tooltip: '',
          ),
        ],
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
