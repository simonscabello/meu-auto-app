import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_plan_provider.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_profile_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/maintenance/presentation/vehicle_profile_screen.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';
import 'package:meu_auto/shared/widgets/app_skeleton.dart';

/// The one screen where personalisation is visible, and the only one that lists
/// what the car does not have. Everything asserted here is copy or a decision
/// about what to show — the state itself always came from the server.
void main() {
  testWidgets('asks the question the server wrote, with all its options', (
    tester,
  ) async {
    await _pump(
      tester,
      _profile(
        questions: const [
          MaintenanceProfileQuestion(
            id: 'timing_drive',
            prompt: 'Seu carro usa correia dentada ou corrente?',
            help: 'Está no manual do carro.',
            options: [
              MaintenanceProfileOption(value: 'belt', label: 'Correia dentada'),
              MaintenanceProfileOption(
                value: 'chain',
                label: 'Corrente de comando',
              ),
              MaintenanceProfileOption(value: 'unknown', label: 'Não sei'),
            ],
          ),
        ],
      ),
    );

    expect(
      find.text('Seu carro usa correia dentada ou corrente?'),
      findsOneWidget,
    );
    expect(find.text('Está no manual do carro.'), findsOneWidget);
    expect(find.text('Correia dentada'), findsOneWidget);
    expect(find.text('Corrente de comando'), findsOneWidget);
    // "Não sei" is never buried behind a "mais opções": it is as available as
    // the answers that decide something.
    expect(find.text('Não sei'), findsOneWidget);
  });

  testWidgets('sends back the value the server offered, not the label', (
    tester,
  ) async {
    final answered = <String>[];
    await _pump(
      tester,
      _profile(
        questions: const [
          MaintenanceProfileQuestion(
            id: 'timing_drive',
            prompt: 'Correia ou corrente?',
            help: '',
            options: [
              MaintenanceProfileOption(value: 'chain', label: 'Corrente'),
            ],
          ),
        ],
      ),
      onAnswer: (question, answer) => answered.add('$question=$answer'),
    );

    await tester.tap(find.text('Corrente'));
    await tester.pump();

    expect(answered, ['timing_drive=chain']);
  });

  testWidgets('a vehicle with no plan says so instead of inventing one', (
    tester,
  ) async {
    await _pump(
      tester,
      _profile(status: MaintenanceProfileStatus.unknown, planCount: 0),
    );

    expect(
      find.textContaining('Ainda não temos um plano para este carro'),
      findsOneWidget,
    );
  });

  testWidgets('asks for the fuel when that is what is blocking everything', (
    tester,
  ) async {
    await _pump(tester, _profile(powertrainKnown: false));

    expect(find.text('Qual o combustível do seu carro?'), findsOneWidget);
    expect(find.textContaining('a gente não chuta'), findsOneWidget);
    expect(find.text('Informar'), findsOneWidget);
  });

  testWidgets('nothing open reads as finished, not as empty', (tester) async {
    await _pump(tester, _profile(status: MaintenanceProfileStatus.ready));

    expect(find.textContaining('Não falta nada por aqui'), findsOneWidget);
    expect(find.text('Qual o combustível do seu carro?'), findsNothing);
  });

  testWidgets('lists what the car does not have, and offers to undo it', (
    tester,
  ) async {
    final restored = <String>[];
    await _pump(
      tester,
      _profile(status: MaintenanceProfileStatus.ready, notApplicableCount: 1),
      notApplicable: [_notApplicablePlan()],
      onRestore: (plan) => restored.add(plan.itemSlug),
    );

    expect(find.text('Seu carro não usa'), findsOneWidget);
    expect(find.text('Correia dentada'), findsOneWidget);
    expect(find.text('Usa corrente de comando.'), findsOneWidget);

    await tester.tap(find.text('Tem sim'));
    await tester.pump();

    expect(restored, ['correia_dentada']);
  });

  testWidgets('never shows the words the schema uses', (tester) async {
    await _pump(
      tester,
      _profile(status: MaintenanceProfileStatus.ready, notApplicableCount: 1),
      notApplicable: [_notApplicablePlan()],
    );

    for (final jargon in [
      'not_applicable',
      'aplicabilidade',
      'estratégia',
      'condition_based',
      'powertrain',
    ]) {
      expect(find.textContaining(jargon), findsNothing, reason: jargon);
    }
  });
  // Loading and error follow the same shape as every other read screen; what is
  // worth asserting is that the profile does not fall back to a blank page,
  // because a blank "what your car has" reads as "your car has nothing".
  testWidgets('VehicleProfileView shows a skeleton while loading', (
    tester,
  ) async {
    final pending = Completer<MaintenanceProfile>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(_profile());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceProfileProvider(
            _vehicleId,
          ).overrideWith((ref) => pending.future),
          maintenancePlansWithHiddenProvider(
            _vehicleId,
          ).overrideWith((ref) async => const <MaintenancePlan>[]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VehicleProfileView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('VehicleProfileView shows a retryable offline error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceProfileProvider(
            _vehicleId,
          ).overrideWith((ref) async => throw const ApiFailure.semConexao()),
          maintenancePlansWithHiddenProvider(
            _vehicleId,
          ).overrideWith((ref) async => const <MaintenancePlan>[]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VehicleProfileView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppErrorState.offlineTitle), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  // The list of hidden items is a second request. It failing must not take the
  // questions down with it — those are the actionable half of the screen.
  testWidgets('the questions still render when the hidden list fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceProfileProvider(_vehicleId).overrideWith(
            (ref) async => _profile(
              questions: const [
                MaintenanceProfileQuestion(
                  id: 'timing_drive',
                  prompt: 'Correia ou corrente?',
                  help: '',
                  options: [
                    MaintenanceProfileOption(value: 'chain', label: 'Corrente'),
                  ],
                ),
              ],
            ),
          ),
          maintenancePlansWithHiddenProvider(
            _vehicleId,
          ).overrideWith((ref) async => throw const ApiFailure.semConexao()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VehicleProfileView(vehicleId: _vehicleId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Correia ou corrente?'), findsOneWidget);
    expect(find.text('Seu carro não usa'), findsNothing);
  });
}

const _vehicleId = '11111111-1111-7111-8111-111111111111';

MaintenanceProfile _profile({
  MaintenanceProfileStatus status = MaintenanceProfileStatus.incomplete,
  bool powertrainKnown = true,
  int planCount = 12,
  int notApplicableCount = 0,
  int missingHistoryCount = 0,
  List<MaintenanceProfileQuestion> questions = const [],
}) {
  return MaintenanceProfile(
    status: status,
    powertrainKnown: powertrainKnown,
    planCount: planCount,
    notApplicableCount: notApplicableCount,
    missingHistoryCount: missingHistoryCount,
    questions: questions,
    answers: const {},
  );
}

MaintenancePlan _notApplicablePlan() {
  return const MaintenancePlan(
    id: 'plan-belt',
    maintenanceItemId: 'item-belt',
    itemSlug: 'correia_dentada',
    itemName: 'Correia dentada',
    itemKind: MaintenanceItemKind.maintenance,
    alertKm: 1000,
    alertDays: 15,
    origin: MaintenancePlanOrigin.user,
    strategy: MaintenanceStrategy.notApplicable,
    historyStatus: MaintenanceHistoryStatus.notAsked,
    notes: 'Usa corrente de comando.',
    status: MaintenanceStatus.naoSeAplica,
  );
}

Future<void> _pump(
  WidgetTester tester,
  MaintenanceProfile profile, {
  List<MaintenancePlan> notApplicable = const [],
  void Function(String question, String answer)? onAnswer,
  ValueChanged<MaintenancePlan>? onRestore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: VehicleProfileContent(
          profile: profile,
          notApplicable: notApplicable,
          onAnswer: onAnswer,
          onRestore: onRestore,
        ),
      ),
    ),
  );
}
