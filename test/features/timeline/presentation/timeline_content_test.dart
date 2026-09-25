import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/cursor_page.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/router/app_routes.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';
import 'package:meu_auto/features/timeline/presentation/timeline_screen.dart';
import 'package:meu_auto/shared/widgets/app_list_row.dart';

void main() {
  setUpAll(ensurePtBrFormatting);

  group('routeForTimelineEntry', () {
    test('a maintenance row opens the record from Prompt 13', () {
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.manutencao)),
        AppRoutes.maintenanceRecord(_id),
      );
    });

    test('an odometer row opens the history from Prompt 11', () {
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.odometro)),
        AppRoutes.odometer,
      );
    });

    test('IPVA and licenciamento open the obligation from Prompt 17', () {
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.ipva)),
        AppRoutes.obligation(_id),
      );
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.licenciamento)),
        AppRoutes.obligation(_id),
      );
    });

    test('an unknown kind has nowhere to go', () {
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.desconhecido)),
        isNull,
      );
    });

    test('an abastecimento row opens the fill', () {
      expect(
        routeForTimelineEntry(_entry(kind: TimelineEntryKind.abastecimento)),
        AppRoutes.abastecimento(_id),
      );
    });

    test('a care flag does not change the maintenance route', () {
      expect(
        routeForTimelineEntry(
          _entry(kind: TimelineEntryKind.manutencao, care: true),
        ),
        AppRoutes.maintenanceRecord(_id),
      );
    });
  });

  group('groupTimelineByMonth', () {
    // A month is the unit people remember a service by ("foi em agosto"); a
    // card per day turned a month of fills into a column of boxes.
    test('closes a group wherever the month changes', () {
      final groups = groupTimelineByMonth([
        _entry(occurredOn: const CivilDate(2026, 8, 12)),
        _entry(occurredOn: const CivilDate(2026, 8, 12), id: 'same-day'),
        _entry(occurredOn: const CivilDate(2026, 8, 3)),
        _entry(occurredOn: const CivilDate(2026, 7, 15)),
      ]);

      expect(groups, hasLength(2));
      expect(groups[0].label, 'Agosto de 2026');
      expect(groups[0].items, hasLength(3));
      expect(groups[1].label, 'Julho de 2026');
    });
  });

  group('TimelineContent', () {
    testWidgets('uses the server title and does not rebuild it', (
      tester,
    ) async {
      await _pump(tester, [
        _entry(
          kind: TimelineEntryKind.manutencao,
          title: 'Troca de óleo do motor, Filtro de óleo',
          subtitle: 'Oficina do João',
          amountCents: const Money.fromCents(42000),
          mileageKm: 98200,
        ),
      ]);

      expect(
        find.text('Troca de óleo do motor, Filtro de óleo'),
        findsOneWidget,
      );
      expect(find.text('R\$\u00A0420,00'), findsOneWidget);
      // One line under the name: when, and where on the odometer. The
      // workshop is on the record's own screen.
      expect(find.text('10\u00A0ago\u00A0· 98.200\u00A0km'), findsOneWidget);
      expect(find.text('Agosto de 2026'), findsOneWidget);
    });

    testWidgets('labels a null title from kind', (tester) async {
      await _pump(tester, [
        _entry(kind: TimelineEntryKind.odometro, mileageKm: 48320),
        _entry(
          kind: TimelineEntryKind.ipva,
          occurredOn: const CivilDate(2026, 3, 15),
          subtitle: '2026',
          amountCents: const Money.fromCents(185000),
        ),
      ]);

      expect(find.text('Quilometragem registrada'), findsOneWidget);
      expect(find.text('IPVA'), findsOneWidget);
      expect(find.text('10\u00A0ago\u00A0· 48.320\u00A0km'), findsOneWidget);
      // A tax has no mileage, so the reference year takes its place.
      expect(find.text('15\u00A0mar\u00A0· 2026'), findsOneWidget);
      expect(find.text('Março de 2026'), findsOneWidget);
    });

    testWidgets('an abastecimento row shows the mileage and the amount', (
      tester,
    ) async {
      await _pump(tester, [
        _entry(
          kind: TimelineEntryKind.abastecimento,
          subtitle: 'gasolina',
          amountCents: const Money.fromCents(24130),
          mileageKm: 96420,
        ),
      ]);

      expect(find.text('Abastecimento'), findsOneWidget);
      expect(find.text('R\$\u00A0241,30'), findsOneWidget);
      expect(find.text('10\u00A0ago\u00A0· 96.420\u00A0km'), findsOneWidget);
    });

    testWidgets('a care record is labelled Cuidado, not Manutenção', (
      tester,
    ) async {
      await _pump(tester, [
        _entry(kind: TimelineEntryKind.manutencao, care: true),
      ]);

      expect(find.text('Cuidado'), findsOneWidget);
      expect(find.text('Manutenção'), findsNothing);
    });

    testWidgets('a row without amount or km does not reserve empty columns', (
      tester,
    ) async {
      await _pump(tester, [
        _entry(
          kind: TimelineEntryKind.manutencao,
          care: true,
          title: 'Pneus calibrados',
        ),
      ]);

      expect(find.text('Pneus calibrados'), findsOneWidget);
      expect(find.textContaining('R\$'), findsNothing);
      expect(find.textContaining('km'), findsNothing);

      // Nothing on the right: no value is laid out, so the name keeps the
      // whole width.
      final row = tester.widget<AppListRow>(find.byType(AppListRow));
      expect(row.value, isNull);
    });

    testWidgets('an unknown kind does not navigate', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TimelineContent(
              state: PagedState(
                items: [
                  _entry(
                    kind: TimelineEntryKind.desconhecido,
                    title: 'Algo novo',
                  ),
                ],
                hasMore: false,
              ),
              onOpen: (_) => opened = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Algo novo'));
      await tester.pump();

      expect(opened, isFalse);
    });

    testWidgets('the empty history invites the first records', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TimelineContent(
              state: const PagedState(items: [], hasMore: false),
              onAddRecord: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nenhum registro ainda'), findsOneWidget);
      expect(find.text('Adicionar registro'), findsOneWidget);
    });

    testWidgets('a later page error keeps the list and offers retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: TimelineContent(
              state: PagedState(
                items: [_entry(title: 'Troca de óleo do motor')],
                hasMore: true,
                lastPageError: Exception('offline'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Troca de óleo do motor'), findsOneWidget);
      expect(find.text('Não foi possível carregar mais.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('each month is its own titled group, in the dark theme too', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: TimelineContent(
              state: PagedState(
                items: [
                  _entry(occurredOn: const CivilDate(2026, 8, 28)),
                  _entry(id: 'older', occurredOn: const CivilDate(2026, 2, 27)),
                ],
                hasMore: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Agosto de 2026'), findsOneWidget);
      expect(find.text('Fevereiro de 2026'), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsNothing);
    });
  });
}

Future<void> _pump(WidgetTester tester, List<TimelineEntry> items) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TimelineContent(state: PagedState(items: items, hasMore: false)),
      ),
    ),
  );
  await tester.pump();
}

const _id = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';

TimelineEntry _entry({
  TimelineEntryKind kind = TimelineEntryKind.manutencao,
  String id = _id,
  CivilDate occurredOn = const CivilDate(2026, 8, 10),
  String? title,
  String? subtitle,
  Money? amountCents,
  int? mileageKm,
  bool? care,
}) {
  return TimelineEntry(
    kind: kind,
    id: id,
    occurredOn: occurredOn,
    title: title,
    subtitle: subtitle,
    amountCents: amountCents,
    mileageKm: mileageKm,
    care: care,
  );
}
