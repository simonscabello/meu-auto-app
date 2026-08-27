import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

enum ObligationKind {
  ipva,
  licenciamento,
  desconhecido;

  static ObligationKind fromWire(String? raw) =>
      parseEnum(raw, ObligationKind.values, fallback: desconhecido);

  String get wire => switch (this) {
    ObligationKind.ipva => 'ipva',
    ObligationKind.licenciamento => 'licenciamento',
    ObligationKind.desconhecido => '',
  };
}

enum ObligationStatus {
  pago,
  vencido,
  venceEmBreve,
  pendente,
  desconhecido;

  static ObligationStatus fromWire(String? raw) =>
      parseEnum(raw, ObligationStatus.values, fallback: desconhecido);

  String get wire => switch (this) {
    ObligationStatus.pago => 'pago',
    ObligationStatus.vencido => 'vencido',
    ObligationStatus.venceEmBreve => 'vence_em_breve',
    ObligationStatus.pendente => 'pendente',
    ObligationStatus.desconhecido => '',
  };
}

final class Obligation {
  const Obligation({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.referenceYear,
    required this.dueOn,
    this.amountCents,
    this.paidOn,
    this.paidAmountCents,
    this.notes,
    required this.status,
    required this.remainingDays,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vehicleId;
  final ObligationKind kind;
  final int referenceYear;
  final CivilDate dueOn;
  final Money? amountCents;
  final CivilDate? paidOn;
  final Money? paidAmountCents;
  final String? notes;
  final ObligationStatus status;
  final int remainingDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPaid => status == ObligationStatus.pago;

  factory Obligation.fromJson(Map<String, dynamic> json) {
    final amount = json['amount_cents'] as int?;
    final paidAmount = json['paid_amount_cents'] as int?;
    return Obligation(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      kind: ObligationKind.fromWire(json['kind'] as String?),
      referenceYear: json['reference_year'] as int,
      dueOn: CivilDate.parse(json['due_on'] as String),
      amountCents: amount == null ? null : Money.fromCents(amount),
      paidOn: CivilDate.tryParse(json['paid_on'] as String?),
      paidAmountCents: paidAmount == null ? null : Money.fromCents(paidAmount),
      notes: json['notes'] as String?,
      status: ObligationStatus.fromWire(json['status'] as String?),
      remainingDays: json['remaining_days'] as int,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
