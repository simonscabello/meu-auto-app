import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/shared/widgets/app_discard_guard.dart';

/// The guard the forms had never fired for typed text: `canPop` was read at
/// build time and typing does not rebuild the screen. These pin the fix — the
/// question comes up for text typed after the screen was built.
void main() {
  testWidgets('back after typing asks before discarding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Opener()));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Oficina do Zé');
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Descartar o que você preencheu?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Oficina do Zé'), findsOneWidget);

    await navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('an untouched form leaves without a question', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Opener()));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Descartar o que você preencheu?'), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}

class _Opener extends StatelessWidget {
  const _Opener();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const _Form())),
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _workshop = TextEditingController();

  @override
  void dispose() {
    _workshop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDiscardGuard(
      listenable: _workshop,
      isDirty: () => _workshop.text.trim().isNotEmpty,
      child: Scaffold(body: TextField(controller: _workshop)),
    );
  }
}
