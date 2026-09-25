import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/abastecimento/domain/abastecimento.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_detail_screen.dart';
import 'package:meu_auto/features/abastecimento/presentation/abastecimento_list_screen.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';
import 'package:meu_auto/features/maintenance/presentation/maintenance_list_screen.dart';
import 'package:meu_auto/features/timeline/presentation/timeline_screen.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';

import '../support/line_breaks.dart';

/// A Galaxy S23 is 360dp wide, and a person there saw "37,65 / L",
/// "5 set · Sem consumo / ainda" and "Consum / o" while every overflow test
/// passed: nothing overflowed, it just broke badly. These run the history
/// and the fill screens between the default size and the point where rows
/// stack ([AppTypography.largeTextScale]), where those breaks lived.
void main() {
  const phone = Size(360, 780);
  const scales = [1.0, 1.1, 1.15, 1.2, 1.3];

  final screens = <String, Widget Function()>{
    'fuel list': () => AbastecimentoListContent(
      state: PagedState(
        hasMore: false,
        items: [
          _fill(
            volumeMl: 37650,
            totalCents: 24058,
            status: ConsumptionStatus.insufficientData,
          ),
          _fill(
            volumeMl: 137650,
            totalCents: 124058,
            status: ConsumptionStatus.ok,
            value: 17.82,
          ),
          _fill(
            volumeMl: 42000,
            totalCents: 26711,
            status: ConsumptionStatus.partialFill,
            fuel: AbastecimentoFuel.etanol,
          ),
        ],
      ),
      onOpen: (_) {},
    ),
    'maintenance list': () => MaintenanceRecordList(
      state: PagedState(
        hasMore: false,
        items: [
          _record(['Troca de óleo do motor', 'Filtro de óleo'], 48000),
          _record([
            'Pastilhas de freio dianteiras',
            'Fluido de freio',
            'Alinhamento',
          ], 138000),
          _record(['Calibragem dos pneus'], 0),
        ],
      ),
      onOpen: (_) {},
    ),
    'history summary without consumption': () => SingleChildScrollView(
      child: TimelineSummary(
        costs: const DashboardCosts(
          periodMonths: 12,
          since: CivilDate(2025, 9, 25),
          maintenanceCents: Money.fromCents(866287),
          obligationsCents: Money.zero,
          seguroCents: Money.zero,
          trackedCents: Money.fromCents(866287),
          trackedCategories: ['maintenance'],
        ),
        lastFill: _lastFill(ConsumptionStatus.insufficientData),
        onCostsTap: () {},
        onFuelTap: () {},
      ),
    ),
    'history summary with consumption': () => SingleChildScrollView(
      child: TimelineSummary(
        lastFill: _lastFill(ConsumptionStatus.ok, value: 17.82),
        onFuelTap: () {},
      ),
    ),
    'fill detail without consumption': () => AbastecimentoDetailContent(
      fill: _fill(
        volumeMl: 37650,
        totalCents: 24058,
        status: ConsumptionStatus.insufficientData,
      ),
    ),
    'fill detail with consumption': () => AbastecimentoDetailContent(
      fill: _fill(
        volumeMl: 37650,
        totalCents: 24058,
        status: ConsumptionStatus.ok,
        value: 17.82,
      ),
    ),
  };

  for (final entry in screens.entries) {
    for (final scale in scales) {
      testWidgets('${entry.key} breaks cleanly at text scale $scale', (
        tester,
      ) async {
        await _pump(tester, phone, scale, entry.value());
        expect(tester.takeException(), isNull);
        expectCleanLineBreaks(tester);
      });
    }
  }

  for (final scale in scales) {
    testWidgets('history filter labels share one size at scale $scale', (
      tester,
    ) async {
      await _pump(
        tester,
        phone,
        scale,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppSegmented<int>(
            options: const [
              AppSegmentedOption(value: 0, label: 'Tudo'),
              AppSegmentedOption(value: 1, label: 'Manutenções'),
              AppSegmentedOption(value: 2, label: 'Abastecimentos'),
            ],
            value: 2,
            onChanged: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final sizes = {
        for (final label in ['Tudo', 'Manutenções', 'Abastecimentos'])
          _renderedFontSize(tester, label),
      };
      expect(sizes, hasLength(1), reason: 'labels at $sizes');
      if (scale == 1.0) {
        // On a 360dp phone at the default size, every label keeps it.
        expect(sizes.single, closeTo(15, 0.01));
      }
    });
  }
}

/// The size a label is actually drawn at: its font size times any
/// [FittedBox] scale above it.
double _renderedFontSize(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
  final span = paragraph.text as TextSpan;
  final size = paragraph.textScaler.scale(span.style!.fontSize!);
  final box = tester.renderObject<RenderBox>(
    find.ancestor(of: find.text(label), matching: find.byType(FittedBox)),
  );
  final scale = box.size.width / paragraph.size.width;
  return double.parse((size * (scale > 1 ? 1 : scale)).toStringAsFixed(2));
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double scale,
  Widget child,
) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: Scaffold(body: SafeArea(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

final _instant = DateTime.utc(2026, 9, 5, 10);

Abastecimento _fill({
  required int volumeMl,
  required int totalCents,
  required ConsumptionStatus status,
  double? value,
  AbastecimentoFuel fuel = AbastecimentoFuel.gasolina,
}) {
  return Abastecimento(
    id: 'fill-$volumeMl',
    vehicleId: '11111111-1111-7111-8111-111111111111',
    occurredOn: const CivilDate(2026, 9, 5),
    mileageKm: 139011,
    volumeMl: volumeMl,
    totalCostCents: Money.fromCents(totalCents),
    pricePerLiterCents: const Money.fromCents(639),
    fuel: fuel,
    fullTank: status != ConsumptionStatus.partialFill,
    consumption: Consumption(
      value: value,
      unit: 'km_per_liter',
      status: status,
    ),
    createdAt: _instant,
    updatedAt: _instant,
  );
}

LastAbastecimento _lastFill(ConsumptionStatus status, {double? value}) {
  return LastAbastecimento(
    id: 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
    occurredOn: const CivilDate(2026, 9, 5),
    totalCostCents: const Money.fromCents(24058),
    volumeMl: 37650,
    pricePerLiterCents: const Money.fromCents(639),
    fuel: AbastecimentoFuel.gasolina,
    consumption: Consumption(
      value: value,
      unit: 'km_per_liter',
      status: status,
    ),
  );
}

MaintenanceRecord _record(List<String> names, int totalCents) {
  return MaintenanceRecord(
    id: 'record-${names.first}',
    vehicleId: '11111111-1111-7111-8111-111111111111',
    occurredOn: const CivilDate(2026, 9, 21),
    mileageKm: 137730,
    kind: MaintenanceRecordKind.declared,
    totalCostCents: Money.fromCents(totalCents),
    items: [
      for (final name in names)
        MaintenanceRecordItem(
          id: 'line-$name',
          maintenanceItemId: '44444444-4444-7444-8444-444444444444',
          itemSlug: 'troca_oleo',
          itemName: name,
        ),
    ],
    createdAt: _instant,
    updatedAt: _instant,
  );
}
