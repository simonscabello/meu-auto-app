import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';
import 'package:meu_auto/features/obligation/presentation/seguro_detail_screen.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('each status is rendered from the wire', (tester) async {
    await _pump(tester, _seguro(status: SeguroStatus.vigente));
    expect(find.text('Vigente'), findsOneWidget);
    expect(find.text('Vence em cerca de 5 meses'), findsOneWidget);

    await _pump(
      tester,
      _seguro(status: SeguroStatus.futuro, remainingDays: 12),
    );
    expect(find.text('Futuro'), findsOneWidget);
    expect(find.text('Começa em 12 dias'), findsOneWidget);

    await _pump(
      tester,
      _seguro(status: SeguroStatus.venceEmBreve, remainingDays: 8),
    );
    expect(find.text('Vence em breve'), findsOneWidget);
    expect(find.text('Vence em 8 dias'), findsOneWidget);

    await _pump(
      tester,
      _seguro(status: SeguroStatus.vencido, remainingDays: -2),
    );
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Venceu há 2 dias · carro sem cobertura'), findsOneWidget);
  });

  testWidgets('a renewed policy is history, not a warning', (tester) async {
    await _pump(
      tester,
      _seguro(status: SeguroStatus.vencido, remainingDays: -2, renewed: true),
    );

    expect(find.text('Renovado'), findsOneWidget);
    expect(find.text('Substituído pela apólice seguinte'), findsOneWidget);
    expect(find.text('Vencido'), findsNothing);
  });

  testWidgets('the insurer is the title and the strip says until when', (
    tester,
  ) async {
    await _pump(tester, _seguro());

    expect(find.text('Porto Seguro'), findsOneWidget);
    expect(find.text('Fim'), findsOneWidget);
    expect(find.text('10/01/2027'), findsOneWidget);
    expect(find.text('R\$ 2.500,00'), findsOneWidget);
    expect(find.text('12345'), findsOneWidget);
  });

  testWidgets('emergency phone is tappable', (tester) async {
    var called = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SeguroDetailContent(
          seguro: _seguro(),
          onEmergencyCall: () => called++,
        ),
      ),
    );

    await tester.tap(find.text('0800 727 0800'));
    await tester.pump();
    expect(called, 1);
  });

  testWidgets('the broker number dials too, and names the broker', (
    tester,
  ) async {
    var called = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SeguroDetailContent(
          seguro: _seguro(),
          onBrokerCall: () => called++,
        ),
      ),
    );

    expect(find.text('Corretor · Ana'), findsOneWidget);
    await tester.tap(find.text('11999999999'));
    await tester.pump();
    expect(called, 1);
  });

  testWidgets('edit is the pencil and delete is in the menu', (tester) async {
    var edited = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SeguroDetailContent(
          seguro: _seguro(),
          onEdit: () => edited++,
          onDelete: () => deleted++,
        ),
      ),
    );

    expect(find.text('Excluir seguro'), findsNothing);
    await tester.tap(find.byTooltip('Editar seguro'));
    await tester.pump();
    expect(edited, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir seguro'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('a missing premium is omitted, never written as R\$ 0,00', (
    tester,
  ) async {
    await _pump(tester, _seguro(premiumCents: null));

    expect(find.text('Prêmio'), findsNothing);
    expect(find.text('R\$ 0,00'), findsNothing);
  });

  testWidgets('lays out at 360x640 with the font turned up', (tester) async {
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
              textScaler: TextScaler.linear(1.3),
              size: Size(360, 640),
            ),
            child: SeguroDetailContent(
              seguro: _seguro(notes: 'Cobertura completa.'),
              onEmergencyCall: () {},
              onBrokerCall: () {},
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('telUri keeps digits and a leading plus', () {
    expect(telUri('0800 727-0800'), Uri(scheme: 'tel', path: '08007270800'));
    expect(
      telUri('+55 (11) 99999-0000'),
      Uri(scheme: 'tel', path: '+5511999990000'),
    );
  });
}

Future<void> _pump(WidgetTester tester, Seguro seguro) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: SeguroDetailContent(seguro: seguro),
    ),
  );
}

Seguro _seguro({
  SeguroStatus status = SeguroStatus.vigente,
  int remainingDays = 136,
  Money? premiumCents = const Money.fromCents(250000),
  bool renewed = false,
  String? notes,
}) {
  return Seguro(
    id: 's1',
    vehicleId: 'v1',
    insurerName: 'Porto Seguro',
    policyNumber: '12345',
    startsOn: const CivilDate(2026, 1, 10),
    endsOn: const CivilDate(2027, 1, 10),
    premiumCents: premiumCents,
    emergencyPhone: '0800 727 0800',
    brokerName: 'Ana',
    brokerPhone: '11999999999',
    notes: notes,
    status: status,
    remainingDays: remainingDays,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10),
    renewed: renewed,
  );
}
