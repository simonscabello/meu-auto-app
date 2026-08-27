import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/presentation/documentos_section.dart';

void main() {
  testWidgets('empty kinds show the register copy, not a blank section', (
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
    expect(find.text('Nenhum IPVA registrado'), findsOneWidget);
    expect(
      find.text('Registre o IPVA deste ano para acompanhar o prazo.'),
      findsOneWidget,
    );
    expect(find.text('Registrar IPVA'), findsOneWidget);
    expect(find.text('Nenhum licenciamento registrado'), findsOneWidget);
    expect(find.text('Nenhum seguro registrado'), findsOneWidget);
  });

  testWidgets('a registered IPVA is a card, not the empty copy', (
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
            ),
          ),
        ),
      ),
    );

    expect(find.text('IPVA 2026'), findsOneWidget);
    expect(find.text('Nenhum IPVA registrado'), findsNothing);
    await tester.tap(find.text('IPVA 2026'));
    await tester.pump();
    expect(opened, 1);
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
