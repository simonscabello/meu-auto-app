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

    await _pump(
      tester,
      _seguro(status: SeguroStatus.vencido, remainingDays: -2),
    );
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('O carro está sem cobertura.'), findsOneWidget);
  });

  testWidgets('emergency phone is tappable', (tester) async {
    var called = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SeguroDetailContent(
            seguro: _seguro(),
            onEmergencyCall: () => called++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('0800 727 0800'));
    await tester.pump();
    expect(called, 1);
  });

  testWidgets('a missing premium is omitted, never written as R\$ 0,00', (
    tester,
  ) async {
    await _pump(tester, _seguro(premiumCents: null));

    expect(find.text('Prêmio'), findsNothing);
    expect(find.text('R\$ 0,00'), findsNothing);
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
      home: Scaffold(body: SeguroDetailContent(seguro: seguro)),
    ),
  );
}

Seguro _seguro({
  SeguroStatus status = SeguroStatus.vigente,
  int remainingDays = 136,
  Money? premiumCents = const Money.fromCents(250000),
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
    status: status,
    remainingDays: remainingDays,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10),
  );
}
