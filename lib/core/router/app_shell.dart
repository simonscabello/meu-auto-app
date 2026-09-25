import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/theme/app_tones.dart';

/// The four top-level destinations, one per job the owner comes to do.
///
/// Início is how the car is and what to do now. Manutenção is what the car
/// needs and when. Documentos holds IPVA, licenciamento and seguro. Histórico
/// is what was done and what it cost.
///
/// Perfil is not a tab. It is the account — a name, a password, the theme,
/// the list of cars — visited a few times a year, and it sits behind the
/// account button on every tab's app bar, where the owner's other apps keep
/// it.
///
/// There is no global add button. Each screen offers its own action, in its
/// own words, and Início names the two that matter most.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,
      // The bar is one step off the page with a hairline along its top: the
      // same edge every card has, so it reads as part of the app rather than
      // as a strip stuck on.
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: tones.stroke)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
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
