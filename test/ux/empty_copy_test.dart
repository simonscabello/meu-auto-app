import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/timeline/presentation/timeline_screen.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';

void main() {
  testWidgets('empty copy speaks from the owner, not the database', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: const [
              AppEmptyState(
                title: 'Cadastre seu primeiro veículo',
                message:
                    'Com o carro cadastrado, os prazos e o histórico ficam neste app.',
              ),
              AppEmptyState(title: 'A quilometragem do seu carro começa aqui'),
              AppEmptyState(
                title: 'O histórico de serviços do seu carro começa aqui',
              ),
              AppEmptyState(title: 'Os cuidados do seu carro começam aqui'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Cadastre seu primeiro veículo'), findsOneWidget);
    expect(
      find.text('A quilometragem do seu carro começa aqui'),
      findsOneWidget,
    );
    expect(
      find.text('O histórico de serviços do seu carro começa aqui'),
      findsOneWidget,
    );
    expect(find.text('Os cuidados do seu carro começam aqui'), findsOneWidget);
    expect(find.textContaining('Nenhum'), findsNothing);
    expect(find.textContaining('encontrado'), findsNothing);
  });

  testWidgets('the timeline empty state keeps the owner-side title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TimelineContent(state: PagedState(hasMore: false)),
        ),
      ),
    );

    expect(find.text('O histórico do seu carro começa aqui'), findsOneWidget);
    expect(find.text('Registrar manutenção'), findsOneWidget);
  });
}
