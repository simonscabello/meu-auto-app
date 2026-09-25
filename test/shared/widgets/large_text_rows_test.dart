import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_fact_row.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// Past [AppTypography.largeTextScale] a row stops sharing its line: the
/// value and the row's button go under the words. At 1.6 on a 360dp phone,
/// side by side, "Gastos em 12 meses" broke into "Gasto / s em / 12 / mese / s".
void main() {
  Future<void> pump(WidgetTester tester, Widget child, double scale) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 640),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: ListView(children: [child])),
        ),
      ),
    );
  }

  bool isUnder(WidgetTester tester, Finder lower, Finder upper) =>
      tester.getTopLeft(lower).dy >= tester.getBottomLeft(upper).dy;

  const row = AppListRow(
    title: 'Gastos em 12 meses',
    icon: Icons.payments_outlined,
    value: 'R\$\u00A09.655,32',
    strongValue: true,
  );

  testWidgets('a value sits beside the name at the default size', (
    tester,
  ) async {
    await pump(tester, row, 1);
    expect(
      isUnder(
        tester,
        find.text('R\$\u00A09.655,32'),
        find.text('Gastos em 12 meses'),
      ),
      isFalse,
    );
  });

  testWidgets('a value goes under the name with the text enlarged', (
    tester,
  ) async {
    await pump(tester, row, 1.6);
    expect(
      isUnder(
        tester,
        find.text('R\$\u00A09.655,32'),
        find.text('Gastos em 12 meses'),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row button goes under the name with the text enlarged', (
    tester,
  ) async {
    await pump(
      tester,
      AppListRow(
        title: 'Verificar o líquido de arrefecimento',
        subtitle: 'Está na hora de verificar',
        icon: Icons.ac_unit,
        trailing: FilledButton(onPressed: () {}, child: const Text('Feito')),
      ),
      1.6,
    );
    expect(
      isUnder(
        tester,
        find.text('Feito'),
        find.text('Está na hora de verificar'),
      ),
      isTrue,
    );
  });

  testWidgets('an inline fact stacks with the text enlarged', (tester) async {
    await pump(
      tester,
      const AppFactRow(
        label: 'Preço por litro',
        value: 'R\$\u00A06,19',
        inline: true,
      ),
      1.6,
    );
    expect(
      isUnder(tester, find.text('R\$\u00A06,19'), find.text('Preço por litro')),
      isTrue,
    );
  });
}
