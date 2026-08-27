import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  final pageJson = loadFixture('timeline.json');
  final complete = asObjectList(pageJson['data']).first;
  final nulls = loadFixture('timeline_entry_nulls.json');

  group('TimelineEntry.fromJson', () {
    test('parses a complete maintenance entry', () {
      final entry = TimelineEntry.fromJson(complete);

      expect(entry.kind, TimelineEntryKind.manutencao);
      expect(entry.occurredOn, const CivilDate(2026, 8, 10));
      expect(entry.title, 'Troca de óleo do motor, Filtro de óleo');
      expect(entry.amountCents, const Money.fromCents(42000));
      expect(entry.mileageKm, 98200);
    });

    test('parses when every optional is null', () {
      final entry = TimelineEntry.fromJson(nulls);

      expect(entry.title, isNull);
      expect(entry.subtitle, isNull);
      expect(entry.amountCents, isNull);
      expect(entry.mileageKm, isNull);
      expect(entry.care, isNull);
      expect(entry.kind, TimelineEntryKind.odometro);
    });

    test('unknown kind falls back without throwing', () {
      final entry = TimelineEntry.fromJson({
        ...complete,
        'kind': 'multa',
      });
      expect(entry.kind, TimelineEntryKind.desconhecido);
    });

    test('abastecimento is a known kind', () {
      final entry = TimelineEntry.fromJson({
        ...complete,
        'kind': 'abastecimento',
      });
      expect(entry.kind, TimelineEntryKind.abastecimento);
    });

    test('care arrives as a flag, not as a kind', () {
      final entry = TimelineEntry.fromJson(complete);
      expect(entry.kind, TimelineEntryKind.manutencao);
      expect(entry.care, isTrue);
    });

    test('fails clearly when a required field is missing', () {
      expect(
        () => TimelineEntry.fromJson(withoutKey(complete, 'id')),
        throwsMissingRequired,
      );
      expect(
        () => TimelineEntry.fromJson(withoutKey(complete, 'occurred_on')),
        throwsMissingRequired,
      );
    });
  });

  test('timeline page envelope keeps a null cursor as last page', () {
    final page = pageOf(pageJson, TimelineEntry.fromJson);
    expect(page.items, hasLength(1));
    expect(page.nextCursor, isNull);
  });
}
