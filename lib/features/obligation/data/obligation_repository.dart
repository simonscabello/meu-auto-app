import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/client_id.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_envelope.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/obligation/domain/obligation.dart';
import 'package:meu_auto/features/obligation/domain/seguro.dart';

final class ObligationRepository {
  ObligationRepository({required this.api, String Function()? newId})
    : _newId = newId ?? newClientId;

  final ApiClient api;
  final String Function() _newId;

  Future<List<Obligation>> listObligations(
    String vehicleId, {
    ObligationKind? kind,
  }) async {
    final body = await api.get(
      ApiPaths.vehicleObligations(vehicleId),
      query: kind == null || kind.wire.isEmpty ? null : {'kind': kind.wire},
    );
    return listOf(body, Obligation.fromJson);
  }

  Future<Obligation> getObligation(String id) async {
    final body = await api.get(ApiPaths.obligation(id));
    return Obligation.fromJson(body);
  }

  Future<Obligation> createObligation({
    required String vehicleId,
    required ObligationKind kind,
    required int referenceYear,
    required CivilDate dueOn,
    int? amountCents,
    String? notes,
    String? id,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleObligations(vehicleId),
      body: {
        'id': id ?? _newId(),
        'kind': kind.wire,
        'reference_year': referenceYear,
        'due_on': dueOn.toJson(),
        'amount_cents': ?amountCents,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return Obligation.fromJson(body);
  }

  Future<Obligation> updateObligation(
    String id, {
    CivilDate? dueOn,
    int? amountCents,
    CivilDate? paidOn,
    int? paidAmountCents,
    String? notes,
    bool clearPayment = false,
  }) async {
    final Map<String, Object?> payload;
    if (clearPayment) {
      payload = const {'clear_payment': true};
    } else {
      payload = {
        if (dueOn != null) 'due_on': dueOn.toJson(),
        'amount_cents': ?amountCents,
        if (paidOn != null) 'paid_on': paidOn.toJson(),
        'paid_amount_cents': ?paidAmountCents,
        'notes': ?notes,
      };
    }
    final body = await api.patch(ApiPaths.obligation(id), body: payload);
    return Obligation.fromJson(body);
  }

  Future<void> deleteObligation(String id) async {
    await api.delete(ApiPaths.obligation(id));
  }

  Future<List<Seguro>> listSeguros(String vehicleId) async {
    final body = await api.get(ApiPaths.vehicleSeguros(vehicleId));
    return listOf(body, Seguro.fromJson);
  }

  Future<Seguro> getSeguro(String id) async {
    final body = await api.get(ApiPaths.seguro(id));
    return Seguro.fromJson(body);
  }

  Future<Seguro> createSeguro({
    required String vehicleId,
    required String insurerName,
    required CivilDate startsOn,
    required CivilDate endsOn,
    String? policyNumber,
    int? premiumCents,
    String? emergencyPhone,
    String? brokerName,
    String? brokerPhone,
    String? notes,
    String? id,
  }) async {
    final body = await api.post(
      ApiPaths.vehicleSeguros(vehicleId),
      body: {
        'id': id ?? _newId(),
        'insurer_name': insurerName,
        'starts_on': startsOn.toJson(),
        'ends_on': endsOn.toJson(),
        if (policyNumber != null && policyNumber.trim().isNotEmpty)
          'policy_number': policyNumber.trim(),
        'premium_cents': ?premiumCents,
        if (emergencyPhone != null && emergencyPhone.trim().isNotEmpty)
          'emergency_phone': emergencyPhone.trim(),
        if (brokerName != null && brokerName.trim().isNotEmpty)
          'broker_name': brokerName.trim(),
        if (brokerPhone != null && brokerPhone.trim().isNotEmpty)
          'broker_phone': brokerPhone.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return Seguro.fromJson(body);
  }

  Future<Seguro> updateSeguro(
    String id, {
    String? insurerName,
    String? policyNumber,
    CivilDate? startsOn,
    CivilDate? endsOn,
    int? premiumCents,
    String? emergencyPhone,
    String? brokerName,
    String? brokerPhone,
    String? notes,
  }) async {
    final body = await api.patch(
      ApiPaths.seguro(id),
      body: {
        'insurer_name': ?insurerName,
        'policy_number': ?policyNumber,
        if (startsOn != null) 'starts_on': startsOn.toJson(),
        if (endsOn != null) 'ends_on': endsOn.toJson(),
        'premium_cents': ?premiumCents,
        'emergency_phone': ?emergencyPhone,
        'broker_name': ?brokerName,
        'broker_phone': ?brokerPhone,
        'notes': ?notes,
      },
    );
    return Seguro.fromJson(body);
  }

  Future<void> deleteSeguro(String id) async {
    await api.delete(ApiPaths.seguro(id));
  }
}
