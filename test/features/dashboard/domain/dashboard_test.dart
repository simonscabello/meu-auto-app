import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

void main() {
  group('Dashboard.fromJson', () {
    test('reads empty alert items and null km fields on an alert', () {
      final dashboard = Dashboard.fromJson(_emptyItemsJson);

      expect(dashboard.alerts.items, isEmpty);
      expect(dashboard.alerts.overdue, 0);
      expect(dashboard.alerts.dueSoon, 0);
      expect(dashboard.alerts.needsBaseline, 18);
      expect(dashboard.odometer.currentKm, 12000);
      expect(dashboard.odometer.recordedOn, const CivilDate(2026, 8, 10));
      expect(dashboard.costs.trackedCents, const Money.fromCents(0));
      expect(dashboard.costs.trackedCategories, [
        'manutencao',
        'ipva',
        'licenciamento',
        'seguro',
      ]);
    });

    test(
      'keeps due_at_km and remaining_km as null when the API sends null',
      () {
        final dashboard = Dashboard.fromJson(_alertWithNullKmJson);
        expect(dashboard.alerts.items, hasLength(1));

        final alert = dashboard.alerts.items.single;
        expect(alert.dueAtKm, isNull);
        expect(alert.remainingKm, isNull);
        expect(alert.dueOn, const CivilDate(2026, 9, 1));
        expect(alert.remainingDays, 6);
        expect(alert.subtitle, isNull);
        expect(alert.kind, AlertKind.ipva);
        expect(alert.severity, AlertSeverity.venceEmBreve);
        expect(alert.referenceType, AlertReferenceType.obligation);
      },
    );

    test('unknown enums fall back to desconhecido', () {
      final dashboard = Dashboard.fromJson(_unknownEnumsJson);
      final alert = dashboard.alerts.items.single;

      expect(alert.kind, AlertKind.desconhecido);
      expect(alert.severity, AlertSeverity.desconhecido);
      expect(alert.referenceType, AlertReferenceType.desconhecido);
    });
  });
}

const _emptyItemsJson = {
  'vehicle': {
    'id': '11111111-1111-7111-8111-111111111111',
    'brand': 'Fiat',
    'model': 'Argo',
    'version': null,
    'nickname': null,
    'plate': null,
  },
  'odometer': {'current_km': 12000, 'recorded_on': '2026-08-10'},
  'alerts': {
    'overdue': 0,
    'due_soon': 0,
    'needs_baseline': 18,
    'items': <Map<String, dynamic>>[],
  },
  'costs': {
    'period_months': 12,
    'since': '2025-08-26',
    'maintenance_cents': 0,
    'obligations_cents': 0,
    'seguro_cents': 0,
    'tracked_cents': 0,
    'tracked_categories': ['manutencao', 'ipva', 'licenciamento', 'seguro'],
  },
};

const _alertWithNullKmJson = {
  'vehicle': {
    'id': '11111111-1111-7111-8111-111111111111',
    'brand': 'Fiat',
    'model': 'Argo',
    'nickname': 'Argolino',
    'plate': 'ABC1D23',
    'version': '1.0',
  },
  'odometer': {'current_km': 12000, 'recorded_on': '2026-08-10'},
  'alerts': {
    'overdue': 0,
    'due_soon': 1,
    'needs_baseline': 0,
    'items': [
      {
        'kind': 'ipva',
        'severity': 'vence_em_breve',
        'title': 'IPVA 2026',
        'subtitle': null,
        'due_on': '2026-09-01',
        'due_at_km': null,
        'remaining_days': 6,
        'remaining_km': null,
        'reference_type': 'obligation',
        'reference_id': 'aaaaaaaa-aaaa-7aaa-8aaa-aaaaaaaaaaaa',
      },
    ],
  },
  'costs': {
    'period_months': 12,
    'since': '2025-08-26',
    'maintenance_cents': 150000,
    'obligations_cents': 0,
    'seguro_cents': 0,
    'tracked_cents': 150000,
    'tracked_categories': ['manutencao', 'ipva', 'licenciamento', 'seguro'],
  },
};

const _unknownEnumsJson = {
  'vehicle': {
    'id': '11111111-1111-7111-8111-111111111111',
    'brand': 'Fiat',
    'model': 'Argo',
  },
  'odometer': {'current_km': 0, 'recorded_on': null},
  'alerts': {
    'overdue': 0,
    'due_soon': 1,
    'needs_baseline': 0,
    'items': [
      {
        'kind': 'recall',
        'severity': 'critico',
        'title': 'Novo tipo',
        'reference_type': 'something_else',
        'reference_id': 'bbbbbbbb-bbbb-7bbb-8bbb-bbbbbbbbbbbb',
      },
    ],
  },
  'costs': {
    'period_months': 1,
    'since': '2026-07-27',
    'maintenance_cents': 0,
    'obligations_cents': 0,
    'seguro_cents': 0,
    'tracked_cents': 0,
    'tracked_categories': <String>[],
  },
};
