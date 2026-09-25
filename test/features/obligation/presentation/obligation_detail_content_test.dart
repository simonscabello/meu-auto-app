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
    expect(find.text('Vence em cerca de 3 meses'), findsOneWidget);

    await _pump(
      tester,
      _obligation(status: ObligationStatus.venceEmBreve, remainingDays: 20),
    );
    expect(find.text('Vence em breve'), findsOneWidget);
    expect(find.text('Vence em 20 dias'), findsOneWidget);

    await _pump(
      tester,
      _obligation(status: ObligationStatus.venceEmBreve, remainingDays: 0),
    );
    expect(find.text('Vence hoje'), findsOneWidget);

    await _pump(
      tester,
      _obligation(status: ObligationStatus.vencido, remainingDays: -10),
    );
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Venceu há 10 dias'), findsOneWidget);
  });

  testWidgets('the year is the title, the kind is the app bar', (tester) async {
    await _pump(tester, _obligation());

    expect(find.text('IPVA 2026'), findsOneWidget);
    expect(find.text('IPVA'), findsOneWidget);
  });

  testWidgets('unpaid, registering the payment is the one filled button', (
    tester,
  ) async {
    var opened = 0;
    await _pump(tester, _obligation(), onMarkPaid: () => opened++);

    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Registrar pagamento'));
    await tester.pump();
    expect(opened, 1);

    // The facts answer "by when and how much".
    expect(find.text('Vencimento'), findsOneWidget);
    expect(find.text('15/03/2026'), findsOneWidget);
    expect(find.text('R\$ 1.842,37'), findsOneWidget);
  });

  testWidgets('paid on time says so, and offers no payment button', (
    tester,
  ) async {
    await _pump(
      tester,
      _obligation(
        status: ObligationStatus.pago,
        remainingDays: 4,
        paidOn: const CivilDate(2026, 3, 11),
      ),
    );

    expect(find.text('Pago'), findsOneWidget);
    expect(find.text('No prazo'), findsOneWidget);
    expect(find.text('Registrar pagamento'), findsNothing);
    expect(find.text('11/03/2026'), findsOneWidget);
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
    expect(find.text('Pago com 3 dias de atraso'), findsOneWidget);
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
    expect(find.text('Valor previsto'), findsOneWidget);
  });

  testWidgets('edit is the pencil; undo and delete wait in the menu', (
    tester,
  ) async {
    var edited = 0;
    var undone = 0;
    await _pump(
      tester,
      _obligation(
        status: ObligationStatus.pago,
        paidOn: const CivilDate(2026, 3, 11),
      ),
      onEdit: () => edited++,
      onUndoPayment: () => undone++,
      onDelete: () {},
    );

    // No large buttons for the rare actions on the page itself.
    expect(find.text('Desfazer pagamento'), findsNothing);
    expect(find.text('Excluir IPVA'), findsNothing);

    await tester.tap(find.byTooltip('Editar IPVA'));
    await tester.pump();
    expect(edited, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Excluir IPVA'), findsOneWidget);
    await tester.tap(find.text('Desfazer pagamento'));
    await tester.pumpAndSettle();
    expect(undone, 1);
  });

  testWidgets('a licenciamento reads in lower case inside a sentence', (
    tester,
  ) async {
    await _pump(
      tester,
      _obligation(kind: ObligationKind.licenciamento),
      onEdit: () {},
      onDelete: () {},
    );

    expect(find.text('Licenciamento 2026'), findsOneWidget);
    expect(find.byTooltip('Editar licenciamento'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Excluir licenciamento'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation before running', (tester) async {
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return ObligationDetailContent(
              obligation: _obligation(),
              onDelete: () async {
                final confirmed = await confirmAction(
                  context,
                  title: 'Excluir o IPVA 2026?',
                  message: 'Ele sai da lista deste carro.',
                  confirmLabel: 'Excluir IPVA',
                  destructive: true,
                );
                if (confirmed) deleted++;
              },
            );
          },
        ),
      ),
    );

    Future<void> openDelete() async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir IPVA'));
      await tester.pumpAndSettle();
    }

    await openDelete();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(deleted, 0);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    await openDelete();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Excluir IPVA'),
      ),
    );
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
          onEdit: () {},
          onDelete: () {},
        );
        expect(tester.takeException(), isNull);

        await _pump(
          tester,
          _obligation(kind: ObligationKind.licenciamento),
          theme: theme.value,
          scale: 1.3,
          onMarkPaid: () {},
          onEdit: () {},
          onDelete: () {},
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
  VoidCallback? onMarkPaid,
  VoidCallback? onUndoPayment,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          size: const Size(360, 640),
        ),
        child: ObligationDetailContent(
          obligation: obligation,
          onMarkPaid: onMarkPaid,
          onUndoPayment: onUndoPayment ?? (obligation.isPaid ? () {} : null),
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    ),
  );
}

Obligation _obligation({
  ObligationKind kind = ObligationKind.ipva,
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
    kind: kind,
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
