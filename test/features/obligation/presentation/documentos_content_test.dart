import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/presentation/documentos_section.dart';

void main() {
  testWidgets('empty kinds keep a way to register each, not a blank section', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DocumentosContent(
              obligations: const [],
              seguros: const [],
              onRegisterIpva: () {},
              onRegisterLicenciamento: () {},
              onRegisterSeguro: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Documentos e prazos'), findsOneWidget);
    expect(find.text('IPVA e licenciamento'), findsOneWidget);
    expect(find.text('Registrar IPVA'), findsOneWidget);
    expect(find.text('Registrar licenciamento'), findsOneWidget);
    expect(find.text('Seguro'), findsOneWidget);
    expect(find.text('Registrar seguro'), findsOneWidget);
  });

  testWidgets('a registered IPVA is a row, not the register action', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DocumentosContent(
              obligations: [_ipva],
              seguros: const [],
              onObligationTap: (_) => opened++,
              onRegisterIpva: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('IPVA 2026'), findsOneWidget);
    expect(find.text('Registrar IPVA'), findsNothing);
    await tester.tap(find.text('IPVA 2026'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('the standalone screen can omit the repeated heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentosContent(
            obligations: const [],
            seguros: const [],
            showHeading: false,
            onRegisterIpva: () {},
            onRegisterLicenciamento: () {},
            onRegisterSeguro: () {},
          ),
        ),
      ),
    );

    expect(find.text('Documentos e prazos'), findsNothing);
    expect(find.text('IPVA e licenciamento'), findsOneWidget);
    expect(find.text('Seguro'), findsOneWidget);
  });
}

final _ipva = Obligation(
  id: 'o1',
  vehicleId: 'v1',
  kind: ObligationKind.ipva,
  referenceYear: 2026,
  dueOn: const CivilDate(2026, 3, 15),
  amountCents: const Money.fromCents(184237),
  status: ObligationStatus.pendente,
  remainingDays: 200,
  createdAt: DateTime.utc(2026, 1, 10),
  updatedAt: DateTime.utc(2026, 1, 10),
);
