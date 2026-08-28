import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';

/// Complements the status-phrase and cost-label spec next door: the singular
/// wordings, how an alert row reads, and whether the whole thing survives a
/// small phone with the font turned up.
void main() {
  group('singular wording', () {
    testWidgets('one overdue item conjugates in the singular', (tester) async {
      await _pump(tester, _dashboard(overdue: 1));
      expect(find.text('1 item precisa de atenção'), findsOneWidget);
    });

    testWidgets('one due-soon item conjugates in the singular', (tester) async {
      await _pump(tester, _dashboard(dueSoon: 1));
      expect(find.text('1 item vence em breve'), findsOneWidget);
    });

    // The history prompt is Cuidados work. Início says how the car is, and a
    // count of unanswered setup questions is not how the car is.
    testWidgets('an unfilled history is silent here, whatever the count', (
      tester,
    ) async {
      await _pump(tester, _dashboard(needsBaseline: 1));
      expect(find.textContaining('ainda não tem histórico'), findsNothing);

      await _pump(tester, _dashboard(needsBaseline: 12));
      expect(find.textContaining('ainda não têm histórico'), findsNothing);
      expect(find.text('Tudo em dia'), findsOneWidget);
    });
  });

  group('alert rows', () {
    testWidgets(
      'joins the subtitle the server sent with the remaining figures',
      (tester) async {
        await _pump(
          tester,
          _dashboard(
            dueSoon: 1,
            items: [
              _alert(
                title: 'Bateria',
                subtitle: 'Garantia',
                remainingDays: 240,
                remainingKm: null,
              ),
            ],
          ),
        );

        expect(find.text('Bateria'), findsOneWidget);
        expect(find.text('Garantia · faltam cerca de 8 meses'), findsOneWidget);
      },
    );

    testWidgets('a dimension that came back null never renders as zero', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          dueSoon: 1,
          items: [
            _alert(title: 'Alinhamento', remainingDays: 8, remainingKm: null),
          ],
        ),
      );

      // The exact match is the proof: had the null been coalesced to zero, the
      // detail line would carry a distance clause as well. 'vence agora' is
      // what remainingKmPhrase(0) produces, so its absence is the guard —
      // searching for '0 km' would hit the odometer reading instead.
      expect(find.text('faltam 8 dias'), findsOneWidget);
      expect(find.text('vence agora'), findsNothing);
      expect(find.textContaining('· faltam'), findsNothing);
    });

    testWidgets('an alert with no remaining figures shows no detail line', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(dueSoon: 1, items: [_alert(title: 'Revisão programada')]),
      );

      // Only the status chip is left beside the title. The banner above still
      // says "1 item vence em breve", so the guard has to be the phrases the
      // detail line itself would produce, not the word "vence".
      expect(find.text('Revisão programada'), findsOneWidget);
      expect(find.textContaining('faltam'), findsNothing);
      expect(find.text('vence agora'), findsNothing);
      expect(find.text('vence hoje'), findsNothing);
    });
  });

  group('cost categories', () {
    testWidgets('a single category is not joined with "e"', (tester) async {
      await _pump(tester, _dashboard(categories: ['manutencao']));
      expect(find.text('Inclui manutenção'), findsOneWidget);
    });

    testWidgets('an unmapped category is shown rather than dropped', (
      tester,
    ) async {
      await _pump(tester, _dashboard(categories: ['manutencao', 'pedagio']));
      expect(find.text('Inclui manutenção e pedagio'), findsOneWidget);
    });
  });

  group('last abastecimento', () {
    testWidgets('sits after próximos cuidados and before custos', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          dueSoon: 1,
          items: [_alert(title: 'Bateria')],
          last: _lastFill(),
        ),
        refuelingSupported: true,
      );

      expect(
        tester.getTopLeft(find.text('Último abastecimento')).dy,
        greaterThan(tester.getTopLeft(find.text('Próximos cuidados')).dy),
      );
      expect(
        tester.getTopLeft(find.textContaining('Custo registrado')).dy,
        greaterThan(tester.getTopLeft(find.text('Último abastecimento')).dy),
      );
    });

    testWidgets('an electric vehicle does not get the block', (tester) async {
      await _pump(
        tester,
        _dashboard(last: _lastFill()),
        refuelingSupported: false,
      );

      expect(find.text('Último abastecimento'), findsNothing);
    });
  });

  // The screen that carries the most text in the app, on the phone that gives
  // it the least room. A RenderFlex overflow surfaces through takeException.
  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('a full dashboard lays out in ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme.value,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.3),
                size: Size(360, 640),
              ),
              child: Scaffold(
                body: DashboardContent(
                  dashboard: _dashboard(
                    overdue: 2,
                    dueSoon: 3,
                    needsBaseline: 12,
                    items: [
                      _alert(
                        title: 'Correia dentada',
                        remainingKm: -1200,
                        remainingDays: -40,
                      ),
                      _alert(
                        title: 'Troca de óleo do motor',
                        remainingKm: 1550,
                        remainingDays: 62,
                      ),
                      _alert(
                        title: 'Bateria',
                        subtitle: 'Garantia',
                        remainingDays: 240,
                      ),
                      _alert(title: 'IPVA', remainingDays: 12),
                      _alert(title: 'Calibrar os pneus', remainingDays: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  });

  // The discreet prompt about what we still do not know. It appears when there
  // is something real to ask and disappears the moment it is answered — a
  // prompt that never ends is noise.
  group('profilePromptOf', () {
    test('says nothing when nothing is open', () {
      expect(profilePromptOf(DashboardProfile.empty), isNull);
    });

    // Open questions are answerable on "O que o seu carro tem" and nowhere
    // else, so counting them on Início was a number with no button under it.
    // Only the two gaps that stop the app working are still reported here.
    test('says nothing about answerable questions it cannot ask', () {
      expect(
        profilePromptOf(
          const DashboardProfile(
            status: MaintenanceProfileStatus.incomplete,
            powertrainKnown: true,
            openQuestions: 3,
          ),
        ),
        isNull,
      );
    });

    test('asks for the fuel first, because it blocks everything else', () {
      final prompt = profilePromptOf(
        const DashboardProfile(
          status: MaintenanceProfileStatus.incomplete,
          powertrainKnown: false,
          openQuestions: 0,
        ),
      );
      expect(prompt, contains('combustível'));
    });

    test('a car with no plan is told so, not left silent', () {
      expect(
        profilePromptOf(
          const DashboardProfile(
            status: MaintenanceProfileStatus.unknown,
            powertrainKnown: true,
            openQuestions: 0,
          ),
        ),
        contains('Ainda não temos um plano'),
      );
    });

    test('never uses the words the schema uses', () {
      for (final profile in [
        const DashboardProfile(
          status: MaintenanceProfileStatus.incomplete,
          powertrainKnown: false,
          openQuestions: 0,
        ),
        const DashboardProfile(
          status: MaintenanceProfileStatus.incomplete,
          powertrainKnown: true,
          openQuestions: 2,
        ),
      ]) {
        final prompt = profilePromptOf(profile) ?? '';
        expect(prompt, isNot(contains('aplicab')));
        expect(prompt, isNot(contains('estratégia')));
        expect(prompt, isNot(contains('powertrain')));
      }
    });
  });
}

Future<void> _pump(
  WidgetTester tester,
  Dashboard dashboard, {
  bool refuelingSupported = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: DashboardContent(
          dashboard: dashboard,
          refuelingSupported: refuelingSupported,
        ),
      ),
    ),
  );
}

Alert _alert({
  required String title,
  String? subtitle,
  int? remainingKm,
  int? remainingDays,
}) {
  return Alert(
    kind: AlertKind.manutencao,
    severity: AlertSeverity.venceEmBreve,
    title: title,
    subtitle: subtitle,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    referenceType: AlertReferenceType.maintenancePlan,
    referenceId: '22222222-2222-7222-8222-222222222222',
  );
}

Dashboard _dashboard({
  int overdue = 0,
  int dueSoon = 0,
  int needsBaseline = 0,
  int periodMonths = 12,
  List<Alert> items = const [],
  List<String> categories = const [
    'manutencao',
    'ipva',
    'licenciamento',
    'seguro',
  ],
  DashboardProfile profile = DashboardProfile.empty,
  LastAbastecimento? last,
}) {
  return Dashboard(
    vehicle: const DashboardVehicle(
      id: '11111111-1111-7111-8111-111111111111',
      brand: 'Fiat',
      model: 'Argo',
      nickname: 'Argolino',
      plate: 'ABC1D23',
    ),
    odometer: const DashboardOdometer(
      currentKm: 48320,
      recordedOn: CivilDate(2026, 8, 10),
    ),
    alerts: DashboardAlerts(
      overdue: overdue,
      dueSoon: dueSoon,
      needsBaseline: needsBaseline,
      items: items,
    ),
    profile: profile,
    costs: DashboardCosts(
      periodMonths: periodMonths,
      since: const CivilDate(2025, 8, 26),
      maintenanceCents: const Money.fromCents(112000),
      obligationsCents: const Money.fromCents(32000),
      seguroCents: const Money.fromCents(10000),
      trackedCents: const Money.fromCents(154000),
      trackedCategories: categories,
    ),
    lastAbastecimento: last,
  );
}

LastAbastecimento _lastFill() {
  return const LastAbastecimento(
    id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
    occurredOn: CivilDate(2026, 8, 10),
    totalCostCents: Money.fromCents(23840),
    volumeMl: 34700,
    pricePerLiterCents: Money.fromCents(687),
    fuel: AbastecimentoFuel.gasolina,
    consumption: Consumption(
      value: 17.82,
      unit: 'km_per_liter',
      status: ConsumptionStatus.ok,
    ),
  );
}
