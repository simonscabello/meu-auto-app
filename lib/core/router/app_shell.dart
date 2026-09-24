import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The four top-level destinations, one per job the owner comes to do.
///
/// Início is how the car is and what to do now. Manutenção is what the car
/// needs and when. Documentos holds IPVA, licenciamento and seguro. Histórico
/// is what was done and what it cost — one of the three things the product
/// promises, and for a while reachable only from the last row of the
/// maintenance list.
///
/// Perfil is not a tab. It is the account — a name, a password, the theme,
/// the list of cars — visited a few times a year, and it sits behind the
/// account button on every tab's app bar, where the owner's other apps keep
/// it. The tab it held is worth more as Histórico.
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
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Manutenção',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Documentos',
            tooltip: '',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Histórico',
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
