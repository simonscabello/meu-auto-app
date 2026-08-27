import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/presentation/login_screen.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_confirm_screen.dart';
import 'package:meu_auto/features/auth/presentation/password_reset_request_screen.dart';
import 'package:meu_auto/features/auth/presentation/register_screen.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/auth/presentation/splash_screen.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/features/catalog/presentation/vehicle_catalog_sheet.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';
import 'package:meu_auto/features/dashboard/presentation/dashboard_screen.dart';
import 'package:meu_auto/features/profile/presentation/delete_account_screen.dart';
import 'package:meu_auto/features/profile/presentation/profile_screen.dart';
import 'package:meu_auto/features/costs/presentation/costs_screen.dart';
import 'package:meu_auto/features/maintenance/application/maintenance_item_provider.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_plan.dart';
import 'package:meu_auto/features/maintenance/presentation/cuidados_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_form_screen.dart';
import 'package:meu_auto/features/maintenance/presentation/vehicle_profile_screen.dart';
import 'package:meu_auto/features/onboarding/presentation/calibrar_flow.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';
import 'package:meu_auto/features/timeline/presentation/timeline_screen.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_detail_screen.dart';
import 'package:meu_auto/shared/widgets/app_date_picker.dart';
import 'package:meu_auto/shared/widgets/app_number_field.dart';
import 'package:meu_auto/shared/widgets/app_empty_state.dart';
import 'package:meu_auto/shared/widgets/app_error_state.dart';

/// Every screen has to survive the combination that actually breaks layouts in
/// the field: a small, cheap phone plus the system font scaled up.
///
/// 360x640 is the low end still in wide use in Brazil, and 1.3 is a text scale
/// a person with tired eyes reaches for. A RenderFlex overflow raises during
/// paint, and `tester.takeException` is what turns that into a failing test
/// instead of a yellow stripe nobody sees on CI.
/// Nothing on these screens renders a timestamp; the model requires the two
/// fields, so they are pinned rather than taken from the clock.
final _fixedInstant = DateTime.utc(2026, 8, 26, 10);

void main() {
  const small = Size(360, 640);

  /// 1.0 is the default, 1.3 is a tired-eyes setting, and 1.6 is roughly where
  /// the iOS accessibility sizes land. The third tier is what catches a Row
  /// that only fits because pt-BR happened to be short enough.
  const scales = [1.0, 1.3, 1.6];

  final screens = <String, Widget Function()>{
    'splash': SplashScreen.new,
    'login': LoginScreen.new,
    'register': RegisterScreen.new,
    'password reset request': PasswordResetRequestScreen.new,
    'password reset confirm': () =>
        const PasswordResetConfirmScreen(token: 'test-token'),
    'profile': _ProfileHarness.new,
    'delete account': _DeleteAccountHarness.new,
    'maintenance form': () => ProviderScope(
      overrides: [
        maintenanceItemsProvider.overrideWith(
          (ref) async => const <MaintenanceItem>[],
        ),
      ],
      child: const MaintenanceFormScreen(
        vehicleId: '11111111-1111-7111-8111-111111111111',
        currentMileageKm: 0,
      ),
    ),
    'calibrar intro': () => const Scaffold(
      body: CalibrarIntroContent(
        questionCount: 4,
        onStart: _noop,
        onLater: _noop,
      ),
    ),
    'calibrar question': _CalibrarQuestionHarness.new,
    'perfil do carro': () => const Scaffold(
      body: VehicleProfileContent(
        profile: MaintenanceProfile(
          status: MaintenanceProfileStatus.incomplete,
          powertrainKnown: false,
          planCount: 12,
          notApplicableCount: 1,
          missingHistoryCount: 5,
          questions: [
            MaintenanceProfileQuestion(
              id: 'timing_drive',
              prompt: 'Seu carro usa correia dentada ou corrente?',
              help:
                  'Se a correia arrebentar, o motor vai junto — por isso vale '
                  'saber. Está no manual, e o mecânico também sabe.',
              options: [
                MaintenanceProfileOption(
                  value: 'belt',
                  label: 'Correia dentada',
                ),
                MaintenanceProfileOption(
                  value: 'chain',
                  label: 'Corrente de comando',
                ),
                MaintenanceProfileOption(value: 'unknown', label: 'Não sei'),
              ],
            ),
          ],
          answers: {},
        ),
        notApplicable: [
          MaintenancePlan(
            id: 'p9',
            maintenanceItemId: 'i9',
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
          ),
        ],
      ),
    ),
    'calibrar done': () =>
        const Scaffold(body: CalibrarDoneContent(configured: 3)),
    'cuidados': () => const CuidadosContent(
      plans: [
        MaintenancePlan(
          id: 'p1',
          maintenanceItemId: 'i1',
          itemSlug: 'troca_oleo',
          itemName: 'Troca de óleo do motor',
          itemKind: MaintenanceItemKind.maintenance,
          alertKm: 1000,
          alertDays: 15,
          origin: MaintenancePlanOrigin.suggested,
          strategy: MaintenanceStrategy.periodic,
          historyStatus: MaintenanceHistoryStatus.notAsked,
          status: MaintenanceStatus.semBaseline,
        ),
        MaintenancePlan(
          id: 'p2',
          maintenanceItemId: 'i2',
          itemSlug: 'calibrar_pneus',
          itemName: 'Calibrar os pneus',
          itemKind: MaintenanceItemKind.care,
          intervalDays: 15,
          alertKm: 500,
          alertDays: 5,
          origin: MaintenancePlanOrigin.suggested,
          strategy: MaintenanceStrategy.periodic,
          historyStatus: MaintenanceHistoryStatus.notAsked,
          status: MaintenanceStatus.venceEmBreve,
          remainingDays: 8,
        ),
      ],
    ),
    // The catalogue's two form pieces. The summary is the widest one — a long
    // model name plus a currency value on one card is exactly where 360px and
    // a 1.3 text scale collide.
    'catalog summary': () => Scaffold(
      body: ListView(
        children: [
          VehicleCatalogSummary(
            selection: VehicleCatalogSelection(
              modelYearId: 'year-1',
              brandName: 'VW - VolksWagen',
              modelName: 'AMAROK CD2.0 16V/S CD2.0 16V TDI 4x2 Die',
              modelYear: 2017,
              fipeCode: '002129-6',
              fipePrice: FipePrice(
                price: const Money.fromCents(8005500),
                referenceMonth: const CivilDate(2026, 8, 1),
                collectedAt: DateTime(2026, 8, 26),
              ),
            ),
            onChange: _noop,
            onClear: _noop,
          ),
        ],
      ),
    ),
    'catalog summary without price': () => Scaffold(
      body: ListView(
        children: const [
          VehicleCatalogSummary(
            selection: VehicleCatalogSelection(
              modelYearId: 'year-1',
              brandName: 'Toyota',
              modelName: 'PRIUS 1.8 16V 5p Aut. (Híbrido)',
              modelYear: 2017,
            ),
            onChange: _noop,
            onClear: _noop,
          ),
        ],
      ),
    ),
    'catalog prompt': () => Scaffold(
      body: ListView(children: const [VehicleCatalogPrompt(onPressed: _noop)]),
    ),
    'timeline': () => const TimelineContent(
      state: PagedState(
        items: [
          TimelineEntry(
            kind: TimelineEntryKind.manutencao,
            id: 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa',
            occurredOn: CivilDate(2026, 8, 10),
            title: 'Troca de óleo do motor, Filtro de óleo',
            subtitle: 'Oficina do João',
            amountCents: Money.fromCents(42000),
            mileageKm: 98200,
          ),
          TimelineEntry(
            kind: TimelineEntryKind.odometro,
            id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
            occurredOn: CivilDate(2026, 7, 2),
            subtitle: 'manual',
            mileageKm: 48320,
          ),
        ],
        hasMore: false,
      ),
    ),
    'timeline empty': () =>
        const TimelineContent(state: PagedState(hasMore: false)),
    'costs': () => const Scaffold(
      body: CostsContent(
        costs: DashboardCosts(
          periodMonths: 12,
          since: CivilDate(2025, 8, 26),
          maintenanceCents: Money.fromCents(112000),
          obligationsCents: Money.fromCents(32000),
          seguroCents: Money.fromCents(10000),
          trackedCents: Money.fromCents(154000),
          trackedCategories: ['manutencao', 'ipva', 'licenciamento', 'seguro'],
        ),
        selectedMonths: 12,
      ),
    ),
    'dashboard': () => const Scaffold(
      body: DashboardContent(
        dashboard: Dashboard(
          profile: DashboardProfile(
            status: MaintenanceProfileStatus.incomplete,
            powertrainKnown: true,
            openQuestions: 1,
          ),
          vehicle: DashboardVehicle(
            id: '11111111-1111-7111-8111-111111111111',
            brand: 'Fiat',
            model: 'Argo',
            nickname: 'Argolino',
            plate: 'ABC1D23',
          ),
          odometer: DashboardOdometer(
            currentKm: 48320,
            recordedOn: CivilDate(2026, 8, 10),
          ),
          alerts: DashboardAlerts(
            overdue: 1,
            dueSoon: 1,
            needsBaseline: 2,
            items: [],
          ),
          costs: DashboardCosts(
            periodMonths: 12,
            since: CivilDate(2025, 8, 26),
            maintenanceCents: Money.fromCents(112000),
            obligationsCents: Money.fromCents(32000),
            seguroCents: Money.fromCents(10000),
            trackedCents: Money.fromCents(154000),
            trackedCategories: [
              'manutencao',
              'ipva',
              'licenciamento',
              'seguro',
            ],
          ),
        ),
      ),
    ),
    'vehicle empty': () => const AppEmptyState(
      title: 'Cadastre seu primeiro veículo',
      message:
          'Com o carro cadastrado, os prazos e o histórico ficam neste app.',
      actionLabel: 'Cadastrar',
      onAction: _noop,
    ),
    'odometer empty': () => const AppEmptyState(
      title: 'A quilometragem do seu carro começa aqui',
      message:
          'Toque em atualizar quilometragem para registrar a primeira leitura.',
    ),
    'maintenance empty': () => const AppEmptyState(
      title: 'O histórico de serviços do seu carro começa aqui',
      message:
          'Cada serviço registrado vira o histórico que o carro leva na revenda.',
      actionLabel: 'Registrar manutenção',
      onAction: _noop,
    ),
    // The widest the sheet gets: a long model name, a plate and a seven-digit
    // reading, all on a 360px screen with the type scaled up.
    'vehicle detail': () => VehicleDetailContent(
      vehicle: Vehicle(
        id: '11111111-1111-7111-8111-111111111111',
        vehicleType: VehicleType.car,
        brand: 'VW - VolksWagen',
        model: 'AMAROK CD2.0 16V/S CD2.0 16V TDI 4x2 Die',
        version: 'Highline 4Motion Automática',
        manufactureYear: 2017,
        modelYear: 2018,
        plate: 'ABC1D23',
        color: 'Cinza grafite',
        fuelType: FuelType.diesel,
        renavam: '12345678901',
        chassis: '9BWZZZ377VT004251',
        currentMileageKm: 1234567,
        currentMileageAt: const CivilDate(2026, 8, 10),
        createdAt: _fixedInstant,
        updatedAt: _fixedInstant,
      ),
    ),
    'vehicle detail, bare': () => VehicleDetailContent(
      vehicle: Vehicle(
        id: '11111111-1111-7111-8111-111111111111',
        vehicleType: VehicleType.car,
        brand: 'Fiat',
        model: 'Argo',
        currentMileageKm: 0,
        createdAt: _fixedInstant,
        updatedAt: _fixedInstant,
      ),
    ),
    'form fields': _FormFieldsHarness.new,
    'error offline': () => AppErrorState.fromError(
      error: const ApiFailure.semConexao(),
      onRetry: _noop,
    ),
    'error internal': () => const AppErrorState(
      message: 'Algo deu errado no servidor.',
      requestId: 'req-abc-123',
      onRetry: _noop,
    ),
  };

  for (final entry in screens.entries) {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      for (final scale in scales) {
        testWidgets(
          '${entry.key} lays out on 360x640, ${theme.key}, text scale $scale',
          (tester) async {
            tester.view.physicalSize = small * 3;
            tester.view.devicePixelRatio = 3;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  tokenStorageProvider.overrideWith(
                    (ref) => TokenStorage.memory(),
                  ),
                ],
                child: MaterialApp(
                  theme: theme.value,
                  home: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                      size: small,
                    ),
                    child: entry.value(),
                  ),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));

            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

/// The three masked fields side by side. They are new, they carry a suffix,
/// a helper line and a currency symbol at once, and that is the combination
/// that runs out of width first.
class _FormFieldsHarness extends StatefulWidget {
  const _FormFieldsHarness();

  @override
  State<_FormFieldsHarness> createState() => _FormFieldsHarnessState();
}

class _FormFieldsHarnessState extends State<_FormFieldsHarness> {
  final money = TextEditingController(text: 'R\$ 1.234.567,89');
  late final TextEditingController km = kmController(1234567);

  @override
  void dispose() {
    money.dispose();
    km.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppMoneyField(controller: money, label: 'Valor total'),
          const SizedBox(height: 12),
          AppKmField(
            controller: km,
            label: 'Quilometragem atual',
            helperText: 'É daqui que o Meu Auto conta os próximos cuidados.',
          ),
          const SizedBox(height: 12),
          AppDateField(value: CivilDate.todayLocal(), onPick: _noop),
          const SizedBox(height: 12),
          const AppDateField(
            value: CivilDate(2026, 2, 28),
            onPick: _noop,
            errorText: 'Informe a data.',
          ),
        ],
      ),
    );
  }
}

class _CalibrarQuestionHarness extends StatefulWidget {
  const _CalibrarQuestionHarness();

  @override
  State<_CalibrarQuestionHarness> createState() =>
      _CalibrarQuestionHarnessState();
}

class _CalibrarQuestionHarnessState extends State<_CalibrarQuestionHarness> {
  final mileage = TextEditingController(text: '48320');

  @override
  void dispose() {
    mileage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CalibrarQuestionContent(
        progressLabel: '2 de 5',
        title: 'Quando foi a última troca de óleo?',
        occurredOn: null,
        mileage: mileage,
        submitting: false,
        offline: false,
        currentMileageKm: 48320,
        onPickDate: () {},
        onConfirm: () {},
        onDontKnow: () {},
        onSkipAll: () {},
      ),
    );
  }
}

final _profileUser = User(
  id: '11111111-1111-1111-1111-111111111111',
  name: 'Ana',
  email: 'ana@example.com',
  createdAt: DateTime.parse('2026-01-15T12:00:00Z').toLocal(),
);

class _ProfileHarness extends StatefulWidget {
  const _ProfileHarness();

  @override
  State<_ProfileHarness> createState() => _ProfileHarnessState();
}

class _ProfileHarnessState extends State<_ProfileHarness> {
  final name = TextEditingController(text: 'Ana');

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfileContent(
        user: _profileUser,
        nameController: name,
        nameError: null,
        banner: null,
        savingName: false,
        nameDirty: false,
        loggingOut: false,
        themeMode: ThemeMode.system,
        onSaveName: () {},
        onNameChanged: () {},
        onThemeMode: (_) {},
        onVehicles: () {},
        onLogout: () {},
        onDeleteAccount: () {},
      ),
    );
  }
}

class _DeleteAccountHarness extends StatefulWidget {
  const _DeleteAccountHarness();

  @override
  State<_DeleteAccountHarness> createState() => _DeleteAccountHarnessState();
}

class _DeleteAccountHarnessState extends State<_DeleteAccountHarness> {
  final password = TextEditingController();

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DeleteAccountContent(
        passwordController: password,
        passwordError: null,
        banner: null,
        submitting: false,
        hasPassword: false,
        onPasswordChanged: () {},
        onSubmit: () {},
      ),
    );
  }
}

void _noop() {}
