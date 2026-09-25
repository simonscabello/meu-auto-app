import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/odometer/domain/odometer_reading.dart';
import 'package:meu_auto/features/odometer/presentation/odometer_history_screen.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('readings are grouped by month, newest first', (tester) async {
    await _pump(tester, _readings);

    expect(find.text('Setembro de 2026'), findsOneWidget);
    expect(find.text('Agosto de 2026'), findsOneWidget);
    expect(find.text('139.011 km'), findsOneWidget);
    expect(find.text('137.900 km'), findsOneWidget);
  });

  testWidgets('each reading says how far the car went since the one before', (
    tester,
  ) async {
    await _pump(tester, _readings);

    expect(find.text('24 set · +166 km'), findsOneWidget);
    expect(find.text('21 set · Abastecimento · +685 km'), findsOneWidget);
    expect(find.text('6 set · Abastecimento · +430 km'), findsOneWidget);
    // Lower than the reading before it: a correction, not the car driving
    // backwards, so no distance.
    expect(find.text('27 ago · Manutenção'), findsOneWidget);
    // The oldest reading has nothing before it.
    expect(find.text('20 ago · Correção'), findsOneWidget);
    expect(find.textContaining('-'), findsNothing);
    expect(find.textContaining('−'), findsNothing);
  });

  testWidgets('the oldest loaded reading waits for the next page', (
    tester,
  ) async {
    await _pump(tester, _readings.sublist(0, 2), hasMore: true);

    expect(find.text('24 set · +166 km'), findsOneWidget);
    expect(find.text('21 set · Abastecimento'), findsOneWidget);
  });

  testWidgets('only readings typed by the owner can be deleted', (
    tester,
  ) async {
    final deleted = <String>[];
    final blocked = <String>[];
    await _pump(
      tester,
      _readings,
      onDelete: (reading) => deleted.add(reading.id),
      onBlockedDelete: (reading) => blocked.add(reading.id),
    );

    expect(find.byTooltip('Excluir leitura'), findsNWidgets(2));
    expect(find.byTooltip('Por que não dá para excluir'), findsNWidgets(3));

    await tester.tap(find.byTooltip('Excluir leitura').first);
    await tester.tap(find.byTooltip('Por que não dá para excluir').first);
    expect(deleted, ['r1']);
    expect(blocked, ['r2']);
  });

  testWidgets('the reading being deleted shows progress, not the button', (
    tester,
  ) async {
    await _pump(tester, _readings, deletingId: 'r1', onDelete: (_) {});

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Excluir leitura'), findsOneWidget);
  });

  testWidgets('an empty history says what fills it and offers the update', (
    tester,
  ) async {
    var updates = 0;
    await _pump(tester, const [], onUpdate: () => updates++);

    expect(find.text('Nenhuma leitura registrada'), findsOneWidget);
    await tester.tap(find.text('Atualizar quilometragem'));
    expect(updates, 1);
  });

  testWidgets('lays out on 360x640 with the font turned up', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.6),
              size: Size(360, 640),
            ),
            child: Scaffold(
              body: OdometerHistoryContent(
                state: PagedState(items: _readings, hasMore: false),
                onDelete: (_) {},
                onBlockedDelete: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<OdometerReading> readings, {
  bool hasMore = false,
  String? deletingId,
  VoidCallback? onUpdate,
  ValueChanged<OdometerReading>? onDelete,
  ValueChanged<OdometerReading>? onBlockedDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: OdometerHistoryContent(
          state: PagedState(items: readings, hasMore: hasMore),
          deletingId: deletingId,
          onUpdate: onUpdate,
          onDelete: onDelete ?? (_) {},
          onBlockedDelete: onBlockedDelete ?? (_) {},
        ),
      ),
    ),
  );
}

final _readings = [
  _reading('r1', 139011, const CivilDate(2026, 9, 24), OdometerSource.manual),
  _reading(
    'r2',
    138845,
    const CivilDate(2026, 9, 21),
    OdometerSource.abastecimento,
  ),
  _reading(
    'r3',
    138160,
    const CivilDate(2026, 9, 6),
    OdometerSource.abastecimento,
  ),
  _reading(
    'r4',
    137730,
    const CivilDate(2026, 8, 27),
    OdometerSource.maintenance,
  ),
  _reading(
    'r5',
    137900,
    const CivilDate(2026, 8, 20),
    OdometerSource.correction,
  ),
];

OdometerReading _reading(
  String id,
  int km,
  CivilDate on,
  OdometerSource source,
) {
  return OdometerReading(
    id: id,
    vehicleId: 'v1',
    mileageKm: km,
    occurredOn: on,
    source: source,
    createdAt: DateTime.utc(on.year, on.month, on.day),
  );
}
