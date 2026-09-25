import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_expandable_group.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';
import 'package:meu_auto/shared/widgets/app_quick_action.dart';
import 'package:meu_auto/shared/widgets/app_section_header.dart';
import 'package:meu_auto/shared/widgets/app_segmented.dart';
import 'package:meu_auto/shared/widgets/app_tab_header.dart';

/// A control that a screen reader announces as a button must also be one it
/// can press. Most tappable pieces merge their text into one spoken label
/// with `excludeSemantics`, which also drops the tap action of the InkWell
/// underneath unless the label node carries it itself.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: ListView(children: [child])),
      ),
    );
  }

  void expectTappable(WidgetTester tester, String label) {
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
      reason: '"$label" is announced but cannot be pressed',
    );
  }

  testWidgets('a list row can be pressed by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppListRow(title: 'Troca de óleo', subtitle: 'Faltam 2.000 km', onTap: () {}),
    );
    expectTappable(tester, 'Troca de óleo. Faltam 2.000 km');
    handle.dispose();
  });

  testWidgets('a row shell can be pressed by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppListRowShell(
        onTap: () {},
        semanticLabel: 'Abastecimento',
        child: const Text('Abastecimento'),
      ),
    );
    expectTappable(tester, 'Abastecimento');
    handle.dispose();
  });

  testWidgets('a quick action can be pressed by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppQuickAction(
        icon: Icons.local_gas_station_outlined,
        label: 'Abastecer',
        onTap: () {},
      ),
    );
    expectTappable(tester, 'Abastecer');
    handle.dispose();
  });

  testWidgets('a section link can be pressed by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppSectionHeader(title: 'Vencidos', actionLabel: 'Ver todos', onAction: () {}),
    );
    expectTappable(tester, 'Ver todos');
    handle.dispose();
  });

  testWidgets('a folded group can be opened by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      const AppExpandableGroup(
        title: 'Em dia',
        count: 12,
        children: [Text('Filtro de ar')],
      ),
    );
    expectTappable(tester, 'Em dia, 12 itens');
    handle.dispose();
  });

  testWidgets('the car line of a tab header can be pressed', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppTabHeader(
        title: 'Manutenção',
        contextLabel: 'Prius · QAF5G33',
        onContextTap: () {},
      ),
    );
    expectTappable(tester, 'Prius · QAF5G33. Trocar veículo');
    handle.dispose();
  });

  testWidgets('a segment can be chosen by a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppSegmented<int>(
        value: 0,
        onChanged: (_) {},
        options: const [
          AppSegmentedOption(value: 0, label: 'Tudo'),
          AppSegmentedOption(value: 1, label: 'Manutenções'),
        ],
      ),
    );
    expectTappable(tester, 'Manutenções');
    handle.dispose();
  });
}
