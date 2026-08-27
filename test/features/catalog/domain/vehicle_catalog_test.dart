import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/catalog/domain/vehicle_catalog.dart';
import 'package:meu_auto/features/vehicle/domain/vehicle.dart';

/// The payloads here are the shapes the server actually sends — the same ones
/// its golden files record. The catalogue is the one place the app parses data
/// that originated outside Meu Auto, so what matters is that a surprise from
/// the source degrades a field rather than the screen.
void main() {
  group('VehicleModelYear.fromJson', () {
    test('reads a normal year and translates the fuel', () {
      final year = VehicleModelYear.fromJson({
        'id': 'year-1',
        'model_id': 'model-1',
        'name': '2017 Híbrido',
        'year': 2017,
        'fuel_label': 'Híbrido',
        'fuel_type': 'hibrido',
      });

      expect(year.year, 2017);
      expect(year.fuelLabel, 'Híbrido');
      // The value the form sends straight back. If this were the source's own
      // word the server would reject the write.
      expect(year.fuelType, FuelType.hibrido);
      expect(year.displayLabel, '2017 · Híbrido');
    });

    test('a null year is the zero-kilometre entry, not a missing field', () {
      final year = VehicleModelYear.fromJson({
        'id': 'year-2',
        'model_id': 'model-1',
        'name': '32000 Híbrido',
        'year': null,
        'fuel_label': 'Híbrido',
        'fuel_type': 'hibrido',
      });

      expect(year.year, isNull);
      // The source's `name` starts with the pseudo-year 32000, which would be
      // nonsense on screen.
      expect(year.displayLabel, 'Zero km · Híbrido');
    });

    test('a fuel with no equivalent leaves the field empty, not wrong', () {
      final year = VehicleModelYear.fromJson({
        'id': 'year-3',
        'model_id': 'model-1',
        'name': '2019 Vapor',
        'year': 2019,
        'fuel_label': 'Vapor',
        'fuel_type': null,
      });

      // Null, not `desconhecido`: the server said nothing, so the form shows an
      // empty fuel and the owner picks it.
      expect(year.fuelType, isNull);
      expect(year.displayLabel, '2019 · Vapor');
    });

    test('a fuel this build does not know falls back instead of throwing', () {
      final year = VehicleModelYear.fromJson({
        'id': 'year-4',
        'model_id': 'model-1',
        'name': '2030 Hidrogênio',
        'year': 2030,
        'fuel_label': 'Hidrogênio',
        'fuel_type': 'hidrogenio',
      });

      expect(year.fuelType, FuelType.desconhecido);
    });

    test('no fuel at all still renders', () {
      final year = VehicleModelYear.fromJson({
        'id': 'year-5',
        'model_id': 'model-1',
        'name': '2020',
        'year': 2020,
        'fuel_label': null,
        'fuel_type': null,
      });

      expect(year.displayLabel, '2020');
    });
  });

  group('VehicleModelYearDetail.fromJson', () {
    Map<String, dynamic> detailJson({Object? fipePrice, String? fipeCode}) {
      return {
        'id': 'year-1',
        'model_id': 'model-1',
        'name': '2017 Híbrido',
        'year': 2017,
        'fuel_label': 'Híbrido',
        'fuel_type': 'hibrido',
        'fipe_code': fipeCode,
        'brand': {'id': 'brand-1', 'vehicle_type': 'car', 'name': 'Toyota'},
        'model': {
          'id': 'model-1',
          'brand_id': 'brand-1',
          'name': 'PRIUS 1.8 16V 5p Aut. (Híbrido)',
        },
        'fipe_price': fipePrice,
      };
    }

    test('reads the whole chain and the valuation', () {
      final detail = VehicleModelYearDetail.fromJson(
        detailJson(
          fipeCode: '002129-6',
          fipePrice: {
            'price_cents': 8005500,
            'reference_month': '2026-08-01',
            'collected_at': '2026-08-26T19:48:17.872531Z',
          },
        ),
      );

      expect(detail.brand.name, 'Toyota');
      expect(detail.model.name, 'PRIUS 1.8 16V 5p Aut. (Híbrido)');
      expect(detail.fipeCode, '002129-6');
      expect(detail.fipePrice!.price.cents, 8005500);
      expect(detail.fipePrice!.referenceMonth, const CivilDate(2026, 8, 1));
      expect(detail.fipePrice!.referenceLabel, 'agosto de 2026');
    });

    test('a null valuation parses — it is the documented degraded case', () {
      // The source being unreachable answers 200 with fipe_price null, so that
      // the registration form still works. Treating it as a parse failure here
      // would turn a working screen into a broken one.
      final detail = VehicleModelYearDetail.fromJson(
        detailJson(fipePrice: null),
      );

      expect(detail.fipePrice, isNull);
      expect(detail.fipeCode, isNull);
      expect(detail.brand.name, 'Toyota');
    });

    test('a malformed valuation is dropped, not fatal', () {
      final detail = VehicleModelYearDetail.fromJson(
        detailJson(fipePrice: {'price_cents': 'muito caro'}),
      );

      expect(detail.fipePrice, isNull);
      expect(detail.model.name, 'PRIUS 1.8 16V 5p Aut. (Híbrido)');
    });
  });

  group('VehicleCatalogSelection.fromDetail', () {
    test('carries the snapshot and exactly one id', () {
      final detail = VehicleModelYearDetail.fromJson({
        'id': 'year-1',
        'model_id': 'model-1',
        'name': '2017 Híbrido',
        'year': 2017,
        'fuel_label': 'Híbrido',
        'fuel_type': 'hibrido',
        'fipe_code': '002129-6',
        'brand': {'id': 'brand-1', 'vehicle_type': 'car', 'name': 'Toyota'},
        'model': {
          'id': 'model-1',
          'brand_id': 'brand-1',
          'name': 'PRIUS 1.8 16V 5p Aut. (Híbrido)',
        },
        'fipe_price': null,
      });

      final selection = VehicleCatalogSelection.fromDetail(detail);

      expect(selection.modelYearId, 'year-1');
      expect(selection.brandName, 'Toyota');
      expect(selection.modelName, 'PRIUS 1.8 16V 5p Aut. (Híbrido)');
      expect(selection.modelYear, 2017);
      expect(selection.fuelType, FuelType.hibrido);
      expect(selection.fipeCode, '002129-6');
    });
  });

  group('FipePrice.referenceLabel', () {
    test('names every month in pt-BR', () {
      for (var month = 1; month <= 12; month++) {
        final price = FipePrice(
          price: const Money.fromCents(100),
          referenceMonth: CivilDate(2026, month, 1),
          collectedAt: DateTime(2026, month, 2),
        );
        expect(price.referenceLabel, endsWith('de 2026'));
        expect(price.referenceLabel, isNot(contains('null')));
      }
    });
  });
}
