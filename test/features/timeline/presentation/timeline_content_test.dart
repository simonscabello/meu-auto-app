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
  });

  group('groupTimelineByMonth', () {
    test('inserts a header wherever the month changes', () {
      final groups = groupTimelineByMonth([
        _entry(occurredOn: const CivilDate(2026, 8, 20)),
        _entry(occurredOn: const CivilDate(2026, 8, 10)),
        _entry(occurredOn: const CivilDate(2026, 7, 1)),
      ]);

      expect(groups, hasLength(2));
      expect(groups[0].label, 'Agosto de 2026');
      expect(groups[0].entries, hasLength(2));
      expect(groups[1].label, 'Julho de 2026');
      expect(groups[1].entries, hasLength(1));
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
      expect(find.text('Oficina do João'), findsOneWidget);
      expect(find.text(r'R$ 420,00'), findsOneWidget);
      expect(find.text('98.200 km'), findsOneWidget);
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
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Agosto de 2026'), findsOneWidget);
      expect(find.text('Março de 2026'), findsOneWidget);
    });

    testWidgets('the empty history invites the first records', (tester) async {
      await _pump(tester, const []);

      expect(find.text('O histórico do seu carro começa aqui'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsOneWidget);
      expect(find.text('Registrar quilometragem'), findsOneWidget);
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
}) {
  return TimelineEntry(
    kind: kind,
    id: id,
    occurredOn: occurredOn,
    title: title,
    subtitle: subtitle,
    amountCents: amountCents,
    mileageKm: mileageKm,
  );
}
