import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/auth/application/auth_controller.dart';
import 'package:meu_auto/features/auth/domain/auth_status.dart';
import 'package:meu_auto/features/auth/domain/user.dart';
import 'package:meu_auto/features/vehicle/presentation/vehicle_context_title.dart';
import 'package:meu_auto/shared/widgets/app_expandable_group.dart';
import 'package:meu_auto/shared/widgets/app_form_section.dart';
import 'package:meu_auto/shared/widgets/app_group.dart';
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
      AppListRow(
        title: 'Troca de óleo',
        subtitle: 'Faltam 2.000 km',
        onTap: () {},
      ),
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
      AppSectionHeader(
        title: 'Vencidos',
        actionLabel: 'Ver todos',
        onAction: () {},
      ),
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

  // A heading that is not its own node makes the node around it the
  // heading, and on the web a heading does not expose the buttons inside
  // it: "Adicionar item" under "O que foi feito" could not be reached.
  testWidgets('a row under a form section heading stays pressable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppFormSection(
        title: 'O que foi feito',
        children: [
          AppGroup(
            children: [
              AppListRow(
                title: 'Adicionar item',
                icon: Icons.add,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
    expectTappable(tester, 'Adicionar item');
    final heading = tester.getSemantics(find.text('O que foi feito'));
    expect(heading.getSemanticsData().label, 'O que foi feito');
    handle.dispose();
  });

  // A lone tappable row that is not its own node lends its button to the
  // node around it: the whole "O que foi feito" card was announced, and
  // outlined, as "Adicionar item".
  testWidgets('a lone tappable row in a group is only as big as itself', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      AppGroup(
        title: 'O que foi feito',
        children: [
          const AppListRow(title: 'Alinhamento', value: r'R$ 70,00'),
          const AppListRow(title: 'Balanceamento', value: r'R$ 80,00'),
          AppListRow(title: 'Adicionar item', icon: Icons.add, onTap: () {}),
        ],
      ),
    );
    final node = tester.getSemantics(find.bySemanticsLabel('Adicionar item'));
    expect(node.rect.height, lessThan(80));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('the account button can be pressed by a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_LoggedIn.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: ProfileButton(onPressed: () {})),
        ),
      ),
    );
    await tester.pump();
    expectTappable(tester, 'Perfil e conta');
    handle.dispose();
  });
}

final class _LoggedIn extends AuthController {
  @override
  Future<AuthStatus> build() async => AuthLoggedIn(
    User(
      id: 'u1',
      name: 'Ana',
      email: 'ana@example.com',
      createdAt: DateTime(2026),
    ),
  );
}
