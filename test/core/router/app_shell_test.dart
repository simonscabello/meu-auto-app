import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meu_auto/core/router/app_shell.dart';
import 'package:meu_auto/core/theme/app_theme.dart';

void main() {
  // One tab per job: now, what the car needs, its documents, and what was done
  // and what it cost. Perfil is the account and lives behind the app bar's
  // account button, which is what freed the fourth tab for Histórico.
  testWidgets(
    'the four tabs are Início, Manutenção, Documentos and Histórico',
    (tester) async {
      final router = GoRouter(
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
            branches: [
              _branch('/', 'home'),
              _branch('/care', 'care'),
              _branch('/documents', 'documents'),
              _branch('/history', 'history'),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();

      for (final label in ['Início', 'Manutenção', 'Documentos', 'Histórico']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Perfil'), findsNothing);
      expect(find.text('Cuidados'), findsNothing);

      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      expect(find.text('history'), findsOneWidget);

      await tester.tap(find.text('Documentos'));
      await tester.pumpAndSettle();
      expect(find.text('documents'), findsOneWidget);
    },
  );
}

StatefulShellBranch _branch(String path, String label) {
  return StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => Text(label))],
  );
}
