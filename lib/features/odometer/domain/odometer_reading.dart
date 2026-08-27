import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';

/// Where a reading came from.
///
/// The app may only ever SEND `manual` or `correction`. `maintenance` and
/// `abastecimento` are written by those modules on the server, and accepting
/// them from a client would let anyone forge a reading that claims to have come
/// from a service record. Reading all four still matters: a service record
/// produces a reading, and it shows up in this history.
enum OdometerSource {
  manual,
  correction,
  maintenance,
  abastecimento,
  desconhecido;

  static OdometerSource fromWire(String? raw) {
    return parseEnum(raw, OdometerSource.values, fallback: desconhecido);
  }

  /// Whether the owner typed this reading themselves.
  ///
  /// A reading the app did not create belongs to the event that did — deleting
  /// it on its own would strip a maintenance record of its mileage and leave
  /// the history unable to explain itself.
  bool get isOwnEntry =>
      this == OdometerSource.manual || this == OdometerSource.correction;

  /// Short pt-BR label for a reading the app did not create. Null when the
  /// owner entered it, because "manual" is not worth a line on screen.
  String? get originLabel {
    return switch (this) {
      OdometerSource.manual => null,
      OdometerSource.correction => 'Correção de leitura',
      OdometerSource.maintenance => 'Registrado junto com uma manutenção',
      OdometerSource.abastecimento => 'Registrado junto com um abastecimento',
      OdometerSource.desconhecido => null,
    };
  }
}

final class OdometerReading {
  const OdometerReading({
    required this.id,
    required this.vehicleId,
    required this.mileageKm,
    required this.occurredOn,
    required this.source,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String vehicleId;
  final int mileageKm;

  /// A civil date. Never an instant — see [CivilDate].
  final CivilDate occurredOn;
  final OdometerSource source;
  final String? notes;

  /// An audit timestamp, and genuinely an instant, unlike [occurredOn].
  final DateTime createdAt;

  factory OdometerReading.fromJson(Map<String, dynamic> json) {
    return OdometerReading(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      mileageKm: json['mileage_km'] as int,
      occurredOn: CivilDate.parse(json['occurred_on'] as String),
      source: OdometerSource.fromWire(json['source'] as String?),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
