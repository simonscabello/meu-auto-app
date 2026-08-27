import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/features/timeline/domain/timeline_entry.dart';

void main() {
  group('TimelineEntry.fromJson', () {
    test(
      'a maintenance entry keeps the title and subtitle the server sent',
      () {
        final entry = TimelineEntry.fromJson(_manutencao);

        expect(entry.kind, TimelineEntryKind.manutencao);
        expect(entry.id, _id);
        expect(entry.occurredOn, const CivilDate(2026, 8, 10));
        expect(entry.title, 'Troca de óleo do motor, Filtro de óleo');
        expect(entry.subtitle, 'Oficina do João');
        expect(entry.amountCents, const Money.fromCents(42000));
        expect(entry.mileageKm, 98200);
      },
    );

    test('an odometer entry has no amount and a null title', () {
      final entry = TimelineEntry.fromJson(_odometro);

      expect(entry.kind, TimelineEntryKind.odometro);
      expect(entry.title, isNull);
      expect(entry.subtitle, 'manual');
      expect(entry.amountCents, isNull);
      expect(entry.mileageKm, 48320);
    });

    test('an IPVA payment has no mileage and a null title', () {
      final entry = TimelineEntry.fromJson(_ipva);

      expect(entry.kind, TimelineEntryKind.ipva);
      expect(entry.title, isNull);
      expect(entry.subtitle, '2026');
      expect(entry.amountCents, const Money.fromCents(185000));
      expect(entry.mileageKm, isNull);
    });

    test('a licenciamento payment has no mileage and a null title', () {
      final entry = TimelineEntry.fromJson(_licenciamento);

      expect(entry.kind, TimelineEntryKind.licenciamento);
      expect(entry.title, isNull);
      expect(entry.subtitle, '2026');
      expect(entry.amountCents, const Money.fromCents(18590));
      expect(entry.mileageKm, isNull);
    });

    test('an unknown kind falls back instead of throwing', () {
      final entry = TimelineEntry.fromJson({
        ..._odometro,
        'kind': 'abastecimento',
      });
      expect(entry.kind, TimelineEntryKind.desconhecido);
    });

    test('occurred_on is a civil date and does not shift a day', () {
      final entry = TimelineEntry.fromJson({
        ..._odometro,
        'occurred_on': '2026-01-01',
      });
      expect(entry.occurredOn, const CivilDate(2026, 1, 1));
    });
  });

  group('titleOf', () {
    test('uses the server title when it sent one', () {
      expect(
        titleOf(TimelineEntry.fromJson(_manutencao)),
        'Troca de óleo do motor, Filtro de óleo',
      );
    });

    test('labels an odometer reading from kind when title is null', () {
      expect(
        titleOf(TimelineEntry.fromJson(_odometro)),
        'Quilometragem registrada',
      );
    });

    test('labels IPVA and licenciamento from kind', () {
      expect(titleOf(TimelineEntry.fromJson(_ipva)), 'IPVA');
      expect(titleOf(TimelineEntry.fromJson(_licenciamento)), 'Licenciamento');
    });
  });

  group('pageOf', () {
    test('a null next_cursor is the last page', () {
      final page = pageOf({
        'data': [_manutencao, _odometro],
        'next_cursor': null,
      }, TimelineEntry.fromJson);

      expect(page.items, hasLength(2));
      expect(page.nextCursor, isNull);
    });

    test('a cursor is passed through untouched', () {
      final page = pageOf({
        'data': [_ipva],
        'next_cursor': 'opaque-token',
      }, TimelineEntry.fromJson);

      expect(page.items.single.kind, TimelineEntryKind.ipva);
      expect(page.nextCursor, 'opaque-token');
    });
  });
}

const _id = 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa';

const _manutencao = {
  'kind': 'manutencao',
  'id': _id,
  'occurred_on': '2026-08-10',
  'title': 'Troca de óleo do motor, Filtro de óleo',
  'subtitle': 'Oficina do João',
  'amount_cents': 42000,
  'mileage_km': 98200,
};

const _odometro = {
  'kind': 'odometro',
  'id': 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
  'occurred_on': '2026-08-10',
  'title': null,
  'subtitle': 'manual',
  'amount_cents': null,
  'mileage_km': 48320,
};

const _ipva = {
  'kind': 'ipva',
  'id': 'cccccccc-cccc-7ccc-8ccc-cccccccccccc',
  'occurred_on': '2026-03-15',
  'title': null,
  'subtitle': '2026',
  'amount_cents': 185000,
  'mileage_km': null,
};

const _licenciamento = {
  'kind': 'licenciamento',
  'id': 'dddddddd-dddd-7ddd-8ddd-dddddddddddd',
  'occurred_on': '2026-04-02',
  'title': null,
  'subtitle': '2026',
  'amount_cents': 18590,
  'mileage_km': null,
};
