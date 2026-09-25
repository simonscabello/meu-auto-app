import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/dashboard/presentation/alerts_screen.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';
import 'package:meu_auto/shared/widgets/app_progress_bar.dart';

/// Complements the status-phrase and cost-label spec next door: the singular
/// wordings, how an alert row reads, and whether the whole thing survives a
/// small phone with the font turned up.
void main() {
  group('singular wording', () {
    testWidgets('one overdue item conjugates in the singular', (tester) async {
      await _pump(tester, _dashboard(overdue: 1));
      expect(find.text('1 item vencido'), findsOneWidget);
    });

    testWidgets('one due-soon item conjugates in the singular', (tester) async {
      await _pump(tester, _dashboard(dueSoon: 1));
      expect(find.text('1 item vence em breve'), findsOneWidget);
    });

    // An unknown history is not "em dia". It is said once, in the verdict's
    // quiet second line, and never in the status colours.
    testWidgets('one unknown item conjugates in the singular', (tester) async {
      await _pump(tester, _dashboard(unknownHistory: 1));
      expect(find.text('Nada vencido até agora'), findsOneWidget);
      expect(find.text('1 item sem data da última vez'), findsOneWidget);
      expect(find.text('Tudo em dia'), findsNothing);
    });
  });

  // Início names the late item itself and how late it is. It used to say
  // only "1 item vencido", which made the owner tap to learn *what* — and then
  // read the same item again on the next page.
  group('alert rows', () {
    testWidgets('name the late item and how late, not a count', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          overdue: 1,
          items: [
            _alert(
              title: 'Calibrar os pneus',
              remainingDays: -13,
              severity: AlertSeverity.vencido,
            ),
          ],
        ),
      );

      expect(find.text('Precisa de atenção'), findsOneWidget);
      expect(find.text('Calibrar os pneus'), findsOneWidget);
      expect(find.text('Venceu há 13 dias'), findsOneWidget);
      expect(find.text('1 item vencido'), findsNothing);
    });

    testWidgets('an item opens itself', (tester) async {
      Alert? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(
                overdue: 1,
                items: [
                  _alert(
                    title: 'Calibrar os pneus',
                    remainingDays: -13,
                    severity: AlertSeverity.vencido,
                  ),
                ],
              ),
              onAlertTap: (alert) => opened = alert,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Calibrar os pneus'));
      expect(opened?.title, 'Calibrar os pneus');
    });

    testWidgets('beyond two, the rest are one tap away', (tester) async {
      var listOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(
                overdue: 2,
                dueSoon: 1,
                items: [
                  _alert(
                    title: 'Calibrar os pneus',
                    remainingDays: -13,
                    severity: AlertSeverity.vencido,
                  ),
                  _alert(
                    title: 'Correia dentada',
                    remainingKm: -1200,
                    severity: AlertSeverity.vencido,
                  ),
                  _alert(title: 'IPVA 2026', remainingDays: 12),
                ],
              ),
              onSeeAllAlerts: () => listOpened = true,
            ),
          ),
        ),
      );

      expect(find.text('Calibrar os pneus'), findsOneWidget);
      expect(find.text('Correia dentada'), findsOneWidget);
      expect(find.text('IPVA 2026'), findsNothing);
      await tester.tap(find.text('Ver mais 1 item'));
      expect(listOpened, isTrue);
    });

    testWidgets('a close item says when, in days', (tester) async {
      await _pump(
        tester,
        _dashboard(
          dueSoon: 1,
          items: [_alert(title: 'Licenciamento 2026', remainingDays: 20)],
        ),
      );
      expect(find.text('Vence em 20 dias'), findsOneWidget);
    });

    testWidgets(
      'joins the subtitle the server sent with the remaining figures',
      (tester) async {
        await _pumpAlerts(tester, [
          _alert(
            title: 'Bateria',
            subtitle: 'Garantia',
            remainingDays: 240,
            remainingKm: null,
          ),
        ]);

        expect(find.text('Bateria'), findsOneWidget);
        expect(
          find.text('Garantia · Vence em cerca de 8 meses'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a dimension that came back null never renders as zero', (
      tester,
    ) async {
      await _pumpAlerts(tester, [
        _alert(title: 'Alinhamento', remainingDays: 8, remainingKm: null),
      ]);

      // The exact match is the proof: had the null been coalesced to zero, the
      // detail line would carry a distance clause as well. 'vence agora' is
      // what remainingKmPhrase(0) produces, so its absence is the guard.
      expect(find.text('Vence em 8 dias'), findsOneWidget);
      expect(find.text('Vence agora'), findsNothing);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('an alert with no remaining figures shows no detail line', (
      tester,
    ) async {
      await _pumpAlerts(tester, [_alert(title: 'Revisão programada')]);

      // Only the status chip is left beside the title, so the guard has to be
      // the phrases the detail line itself would produce.
      expect(find.text('Revisão programada'), findsOneWidget);
      expect(find.textContaining('Faltam'), findsNothing);
      expect(find.text('Vence agora'), findsNothing);
      expect(find.text('Vence hoje'), findsNothing);
    });
  });

  group('what comes next', () {
    testWidgets('upcoming items are listed with how far they are', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          upcoming: [
            _upcoming(
              title: 'Troca de óleo do motor',
              remainingKm: 4200,
              remainingDays: 30,
            ),
            _upcoming(
              title: 'IPVA 2027',
              remainingDays: 197,
              dueOn: const CivilDate(2027, 1, 20),
            ),
          ],
        ),
      );

      expect(find.text('Próximos cuidados'), findsOneWidget);
      expect(find.text('Faltam 4.200 km ou 30 dias'), findsOneWidget);
      expect(find.text('Vence em 20/01/2027'), findsOneWidget);
    });

    // A gauge on every row was a metric added because the data existed. The
    // fraction lives on the plan's own screen.
    testWidgets('Início draws no progress bars', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(
                upcoming: [
                  _upcoming(title: 'Troca de óleo do motor', remainingKm: 4200),
                  _upcoming(title: 'Pastilhas de freio', remainingKm: 18000),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AppProgressBar), findsNothing);
    });

    testWidgets('with something late, unknown items keep a quiet row', (
      tester,
    ) async {
      await _pump(
        tester,
        _dashboard(
          overdue: 1,
          unknownHistory: 7,
          items: [
            _alert(
              title: 'Calibrar os pneus',
              remainingDays: -13,
              severity: AlertSeverity.vencido,
            ),
          ],
        ),
      );

      expect(find.text('Calibrar os pneus'), findsOneWidget);
      expect(find.text('7 itens sem data da última vez'), findsOneWidget);
    });

    testWidgets('no row about unknown items when there are none', (
      tester,
    ) async {
      await _pump(tester, _dashboard(overdue: 1, unknownHistory: 0));
      expect(find.textContaining('sem data da última vez'), findsNothing);
    });
  });

  // What the car cost lives on Histórico, where the question is the reason
  // to open the tab. Início answers "now" and "next" and nothing else.
  group('what is not on Início', () {
    testWidgets('the costs block', (tester) async {
      await _pump(tester, _dashboard(totalCents: 154000));
      expect(find.textContaining('Gastos registrados'), findsNothing);
      expect(find.text('R\$ 1.540,00'), findsNothing);
    });

    testWidgets('the last fill, even on a car that refuels', (tester) async {
      await _pump(
        tester,
        _dashboard(last: _lastFill()),
        refuelingSupported: true,
      );
      expect(find.text('Último abastecimento'), findsNothing);
    });

    testWidgets('a third quick action for the mileage', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: DashboardContent(
              dashboard: _dashboard(),
              refuelingSupported: true,
              onRegisterAbastecimento: () {},
              onRegisterMaintenance: () {},
              onOdometerTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Atualizar km'), findsNothing);
      expect(find.text('Abastecer'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsOneWidget);
    });
  });

  group('odometer age', () {
    test('a recent reading says its date, an old one says how old', () {
      const today = CivilDate(2026, 9, 24);
      expect(
        odometerCaption(const CivilDate(2026, 9, 24), today),
        'Atualizada hoje',
      );
      expect(
        odometerCaption(const CivilDate(2026, 9, 23), today),
        'Atualizada ontem',
      );
      expect(
        odometerCaption(const CivilDate(2026, 9, 1), today),
        'Atualizada em 1 de setembro',
      );
      expect(
        odometerCaption(const CivilDate(2026, 5, 20), today),
        'Atualizada há 4 meses — toque para conferir',
      );
      expect(odometerIsStale(const CivilDate(2026, 5, 20), today), isTrue);
      expect(odometerIsStale(const CivilDate(2026, 9, 1), today), isFalse);
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
                  today: const CivilDate(2026, 12, 20),
                  dashboard: _dashboard(
                    overdue: 2,
                    dueSoon: 3,
                    needsBaseline: 12,
                    unknownHistory: 14,
                    upcoming: [
                      _upcoming(
                        title: 'Fluido de arrefecimento',
                        remainingKm: 4800,
                        remainingDays: 197,
                        dueOn: const CivilDate(2027, 7, 5),
                      ),
                    ],
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
  AlertSeverity severity = AlertSeverity.venceEmBreve,
}) {
  return Alert(
    kind: AlertKind.manutencao,
    severity: severity,
    title: title,
    subtitle: subtitle,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    referenceType: AlertReferenceType.maintenancePlan,
    referenceId: '22222222-2222-7222-8222-222222222222',
  );
}

Alert _upcoming({
  required String title,
  int? remainingKm,
  int? remainingDays,
  CivilDate? dueOn,
}) {
  return Alert(
    kind: AlertKind.manutencao,
    severity: AlertSeverity.emDia,
    title: title,
    remainingKm: remainingKm,
    remainingDays: remainingDays,
    dueOn: dueOn,
    referenceType: AlertReferenceType.maintenancePlan,
    referenceId: '33333333-3333-7333-8333-333333333333',
  );
}

Future<void> _pumpAlerts(WidgetTester tester, List<Alert> alerts) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: AlertsContent(alerts: alerts)),
    ),
  );
}

Dashboard _dashboard({
  int overdue = 0,
  int dueSoon = 0,
  int needsBaseline = 0,
  int? unknownHistory,
  int periodMonths = 12,
  List<Alert> items = const [],
  List<Alert> upcoming = const [],
  List<String> categories = const [
    'manutencao',
    'ipva',
    'licenciamento',
    'seguro',
  ],
  DashboardProfile profile = DashboardProfile.empty,
  LastAbastecimento? last,
  int totalCents = 154000,
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
      unknownHistory: unknownHistory,
      items: items,
    ),
    upcoming: upcoming,
    profile: profile,
    costs: DashboardCosts(
      periodMonths: periodMonths,
      since: const CivilDate(2025, 8, 26),
      maintenanceCents: const Money.fromCents(112000),
      obligationsCents: const Money.fromCents(32000),
      seguroCents: const Money.fromCents(10000),
      trackedCents: Money.fromCents(totalCents),
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
