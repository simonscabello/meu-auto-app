import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

enum SeguroStatus {
  futuro,
  vigente,
  venceEmBreve,
  vencido,
  desconhecido;

  static SeguroStatus fromWire(String? raw) =>
      parseEnum(raw, SeguroStatus.values, fallback: desconhecido);

  String get wire => switch (this) {
    SeguroStatus.futuro => 'futuro',
    SeguroStatus.vigente => 'vigente',
    SeguroStatus.venceEmBreve => 'vence_em_breve',
    SeguroStatus.vencido => 'vencido',
    SeguroStatus.desconhecido => '',
  };
}

final class Seguro {
  const Seguro({
    required this.id,
    required this.vehicleId,
    required this.insurerName,
    this.policyNumber,
    required this.startsOn,
    required this.endsOn,
    this.premiumCents,
    this.emergencyPhone,
    this.brokerName,
    this.brokerPhone,
    this.notes,
    required this.status,
    required this.remainingDays,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vehicleId;
  final String insurerName;
  final String? policyNumber;
  final CivilDate startsOn;
  final CivilDate endsOn;
  final Money? premiumCents;
  final String? emergencyPhone;
  final String? brokerName;
  final String? brokerPhone;
  final String? notes;
  final SeguroStatus status;
  final int remainingDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Seguro.fromJson(Map<String, dynamic> json) {
    final premium = json['premium_cents'] as int?;
    return Seguro(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      insurerName: json['insurer_name'] as String,
      policyNumber: json['policy_number'] as String?,
      startsOn: CivilDate.parse(json['starts_on'] as String),
      endsOn: CivilDate.parse(json['ends_on'] as String),
      premiumCents: premium == null ? null : Money.fromCents(premium),
      emergencyPhone: json['emergency_phone'] as String?,
      brokerName: json['broker_name'] as String?,
      brokerPhone: json['broker_phone'] as String?,
      notes: json['notes'] as String?,
      status: SeguroStatus.fromWire(json['status'] as String?),
      remainingDays: json['remaining_days'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
