import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/application/abastecimento_provider.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_detail_screen.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/cuidados_screen.dart';
import 'package:meu_auto/features/obligation/application/obligation_provider.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_detail_screen.dart';
import 'package:meu_auto/features/obligation/presentation/seguro_detail_screen.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

void main() {
  testWidgets('abastecimento detail loading looks like the sheet', (
    tester,
  ) async {
    final pending = Completer<Abastecimento>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.completeError(StateError('unused'));
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          abastecimentoProvider('a1').overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          home: AbastecimentoDetailScreen(abastecimentoId: 'a1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('abastecimento detail hides a thrown exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          abastecimentoProvider('a1').overrideWith((ref) async {
            throw StateError('Bad state: boom at foo.dart:12');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AbastecimentoDetailScreen(abastecimentoId: 'a1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
    expect(find.textContaining('foo.dart'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('obligation detail loading looks like the sheet', (tester) async {
    final pending = Completer<Obligation>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.completeError(StateError('unused'));
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          obligationProvider('o1').overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          home: ObligationDetailScreen(obligationId: 'o1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('obligation detail hides a thrown exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          obligationProvider('o1').overrideWith((ref) async {
            throw StateError('Exception: stack');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ObligationDetailScreen(obligationId: 'o1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.textContaining('Exception:'), findsNothing);
    expect(find.textContaining('stack'), findsNothing);
  });

  testWidgets('seguro detail loading looks like the sheet', (tester) async {
    final pending = Completer<Seguro>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.completeError(StateError('unused'));
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seguroProvider('s1').overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(home: SeguroDetailScreen(seguroId: 's1')),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('seguro detail hides a thrown exception', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seguroProvider('s1').overrideWith((ref) async {
            throw StateError('HTTP 500');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SeguroDetailScreen(seguroId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.textContaining('HTTP 500'), findsNothing);
    expect(find.textContaining('500'), findsNothing);
  });

  testWidgets('cuidados loading looks like the list', (tester) async {
    final pending = Completer<List<MaintenancePlan>>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(const []);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenancePlansProvider('v1').overrideWith((ref) => pending.future),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CuidadosView(vehicleId: 'v1')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cuidados error is retryable and hides the exception', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenancePlansProvider('v1').overrideWith((ref) async {
            throw StateError('internal 503');
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CuidadosView(vehicleId: 'v1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('503'), findsNothing);
    expect(find.textContaining('internal'), findsNothing);
  });

  testWidgets('cuidados empty still explains what to do', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenancePlansProvider('v1').overrideWith((ref) async => []),
          obligationsProvider('v1').overrideWith((ref) async => []),
          segurosProvider('v1').overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: CuidadosView(vehicleId: 'v1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Os cuidados do seu carro começam aqui'), findsOneWidget);
    expect(find.text('Criar plano'), findsOneWidget);
  });
}
