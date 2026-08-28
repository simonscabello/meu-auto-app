import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

/// The container that came back, and the rules that keep it from becoming the
/// card-around-everything it replaced.
void main() {
  testWidgets('the label sits outside the surface, the rows inside it', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppGroup(
        title: 'Documentos e prazos',
        children: [
          AppListRow(icon: Icons.receipt_long_outlined, title: 'IPVA 2026'),
          AppListRow(icon: Icons.description_outlined, title: 'Licenciamento'),
        ],
      ),
    );

    final label = tester.getRect(find.text('Documentos e prazos'));
    final surface = tester.getRect(find.byType(DecoratedBox).first);

    expect(label.bottom, lessThanOrEqualTo(surface.top));
    expect(
      tester.getRect(find.text('IPVA 2026')).left,
      greaterThan(surface.left),
    );
  });

  testWidgets('a group with nothing in it draws nothing', (tester) async {
    await _pump(tester, const AppGroup(title: 'Seguro', children: []));

    expect(find.text('Seguro'), findsNothing);
    expect(find.byType(DecoratedBox), findsNothing);
  });

  // The caveat belongs to the group, not to any row in it — what a total
  // includes, why a list is short. Putting it in a row would make it look
  // like one more item.
  testWidgets('the footnote is under the surface, not a row in it', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppGroup(
        title: 'Custo registrado',
        footnote: 'Inclui manutenção e seguro',
        children: [AppListRow(title: 'R\$ 1.540,00')],
      ),
    );

    final surface = tester.getRect(find.byType(DecoratedBox).first);
    expect(
      tester.getRect(find.text('Inclui manutenção e seguro')).top,
      greaterThanOrEqualTo(surface.bottom),
    );
  });

  testWidgets('rows are separated by a hairline, never by a gap', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppGroup(
        children: [
          AppListRow(title: 'Um'),
          AppListRow(title: 'Dois'),
          AppListRow(title: 'Três'),
        ],
      ),
    );

    expect(find.byType(Divider), findsNWidgets(2));
  });
}

Future<void> _pump(WidgetTester tester, Widget group) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: group),
      ),
    ),
  );
}
