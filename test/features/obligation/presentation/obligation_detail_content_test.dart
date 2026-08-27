import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/presentation/obligation_detail_screen.dart';
import 'package:meu_auto/shared/widgets/app_confirm.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  testWidgets('each unpaid status is rendered from the wire', (tester) async {
    await _pump(
      tester,
      _obligation(status: ObligationStatus.pendente, remainingDays: 80),
    );
    expect(find.text('Pendente'), findsOneWidget);

    await _pump(
      tester,
      _obligation(status: ObligationStatus.venceEmBreve, remainingDays: 0),
    );
    expect(find.text('Vence em breve'), findsOneWidget);
    expect(find.text('vence hoje'), findsOneWidget);

    await _pump(
      tester,
      _obligation(status: ObligationStatus.vencido, remainingDays: -10),
    );
    expect(find.text('Vencido'), findsOneWidget);
  });

  testWidgets('paid on time shows Pago and Em dia', (tester) async {
    await _pump(
      tester,
      _obligation(
        status: ObligationStatus.pago,
        remainingDays: 4,
        paidOn: const CivilDate(2026, 3, 11),
      ),
    );

    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('Em dia'), findsOneWidget);
    expect(find.text('Marcar como pago'), findsNothing);
    expect(find.text('Desfazer pagamento'), findsOneWidget);
  });

  testWidgets('paid late keeps Pago and the delay phrase', (tester) async {
    await _pump(
      tester,
      _obligation(
        status: ObligationStatus.pago,
        remainingDays: -3,
        paidOn: const CivilDate(2026, 3, 18),
      ),
    );

    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('pago com 3 dias de atraso'), findsOneWidget);
  });

  testWidgets('a missing amount is omitted, never written as R\$ 0,00', (
    tester,
  ) async {
    await _pump(tester, _obligation(amountCents: null));

    expect(find.text('Valor'), findsNothing);
    expect(find.text('R\$ 0,00'), findsNothing);
    expect(find.text('R\$ 1.842,37'), findsNothing);
  });

  testWidgets('a paid amount that differs from the predicted one shows both', (
    tester,
  ) async {
    await _pump(
      tester,
      _obligation(
        status: ObligationStatus.pago,
        amountCents: const Money.fromCents(184237),
        paidAmountCents: const Money.fromCents(190000),
        paidOn: const CivilDate(2026, 3, 18),
      ),
    );

    expect(find.text('R\$ 1.842,37'), findsOneWidget);
    expect(find.text('R\$ 1.900,00'), findsOneWidget);
    expect(find.text('Valor pago'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation before running', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ObligationDetailContent(
                obligation: _obligation(),
                onDelete: () async {
                  final confirmed = await confirmAction(
                    context,
                    title: 'Excluir este IPVA?',
                    message: 'O registro some da lista.',
                    confirmLabel: 'Excluir',
                    destructive: true,
                  );
                  if (confirmed) deleted++;
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  group('360x640 with the font turned up', () {
    for (final theme in {
      'light': AppTheme.light,
      'dark': AppTheme.dark,
    }.entries) {
      testWidgets('obligation detail lays out in ${theme.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 640) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          _obligation(
            status: ObligationStatus.pago,
            remainingDays: -3,
            paidOn: const CivilDate(2026, 3, 18),
            paidAmountCents: const Money.fromCents(190000),
            notes: 'Pago no banco.',
          ),
          theme: theme.value,
          scale: 1.3,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Obligation obligation, {
  ThemeData? theme,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          size: const Size(360, 640),
        ),
        child: Scaffold(
          body: ObligationDetailContent(
            obligation: obligation,
            onUndoPayment: obligation.isPaid ? () {} : null,
          ),
        ),
      ),
    ),
  );
}

Obligation _obligation({
  ObligationStatus status = ObligationStatus.pendente,
  int remainingDays = 200,
  Money? amountCents = const Money.fromCents(184237),
  Money? paidAmountCents,
  CivilDate? paidOn,
  String? notes,
}) {
  return Obligation(
    id: 'o1',
    vehicleId: 'v1',
    kind: ObligationKind.ipva,
    referenceYear: 2026,
    dueOn: const CivilDate(2026, 3, 15),
    amountCents: amountCents,
    paidOn: paidOn,
    paidAmountCents: paidAmountCents,
    notes: notes,
    status: status,
    remainingDays: remainingDays,
    createdAt: DateTime.utc(2026, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10),
  );
}
