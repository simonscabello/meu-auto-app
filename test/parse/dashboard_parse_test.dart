import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/dashboard/domain/dashboard.dart';

import '../support/fixtures.dart';
import '../support/parse.dart';

void main() {
  final complete = loadFixture('dashboard.json');
  final nulls = loadFixture('dashboard_nulls.json');

  group('Dashboard.fromJson', () {
    test('parses a complete dashboard', () {
      final dashboard = Dashboard.fromJson(complete);

      expect(dashboard.vehicle.id, '22222222-2222-7222-8222-222222222222');
      expect(dashboard.vehicle.nickname, 'Argolino');
      expect(dashboard.odometer.currentKm, 106650);
      expect(dashboard.odometer.recordedOn, const CivilDate(2026, 8, 10));
      expect(dashboard.alerts.dueSoon, 1);
      expect(dashboard.alerts.items, hasLength(1));
      expect(dashboard.costs.trackedCents, const Money.fromCents(575000));
      expect(dashboard.costs.since, const CivilDate(2025, 8, 26));
    });

    test('parses when every optional is null', () {
      final dashboard = Dashboard.fromJson(nulls);
      final alert = dashboard.alerts.items.single;

      expect(dashboard.vehicle.nickname, isNull);
      expect(dashboard.vehicle.plate, isNull);
      expect(dashboard.vehicle.version, isNull);
      expect(dashboard.odometer.recordedOn, isNull);
      expect(alert.dueAtKm, isNull);
      expect(alert.dueOn, isNull);
      expect(alert.remainingDays, isNull);
      expect(alert.remainingKm, isNull);
      expect(alert.subtitle, isNull);
    });

    test('unknown alert enums fall back without throwing', () {
      final dashboard = Dashboard.fromJson({
        ...complete,
        'alerts': {
          ...asMap(complete['alerts']),
          'items': [
            {
              ...asMap(asObjectList(asMap(complete['alerts'])['items']).first),
              'kind': 'recall',
              'severity': 'critico',
              'reference_type': 'something_else',
            },
          ],
        },
      });
      final alert = dashboard.alerts.items.single;

      expect(alert.kind, AlertKind.desconhecido);
      expect(alert.severity, AlertSeverity.desconhecido);
      expect(alert.referenceType, AlertReferenceType.desconhecido);
    });

    test('fails clearly when a required object is missing', () {
      expect(
        () => Dashboard.fromJson(withoutKey(complete, 'vehicle')),
        throwsMissingRequired,
      );
      expect(
        () => Dashboard.fromJson(withoutKey(complete, 'costs')),
        throwsMissingRequired,
      );
    });
  });

  group('Alert.fromJson', () {
    final alertJson = asObjectList(asMap(complete['alerts'])['items']).first;

    test('parses a complete alert from the alerts list', () {
      final standalone = asObjectList(loadFixture('alerts.json')['data']).first;
      final alert = Alert.fromJson(standalone);

      expect(alert.kind, AlertKind.manutencao);
      expect(alert.severity, AlertSeverity.venceEmBreve);
      expect(alert.referenceType, AlertReferenceType.maintenancePlan);
      expect(alert.title, 'Troca de óleo do motor');
      expect(alert.dueOn, const CivilDate(2026, 9, 1));
    });

    test('fails clearly when title is missing', () {
      expect(
        () => Alert.fromJson(withoutKey(alertJson, 'title')),
        throwsMissingRequired,
      );
    });
  });

  group('DashboardCosts.fromJson', () {
    test('fails clearly when a required amount is missing', () {
      expect(
        () => DashboardCosts.fromJson(
          withoutKey(asMap(complete['costs']), 'tracked_cents'),
        ),
        throwsMissingRequired,
      );
    });
  });
}
