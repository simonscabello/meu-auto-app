import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

enum TimelineEntryKind {
  manutencao,
  odometro,
  ipva,
  licenciamento,
  abastecimento,
  desconhecido;

  static TimelineEntryKind fromWire(String? raw) =>
      parseEnum(raw, TimelineEntryKind.values, fallback: desconhecido);
}

final class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.id,
    required this.occurredOn,
    this.title,
    this.subtitle,
    this.amountCents,
    this.mileageKm,
    this.care,
  });

  final TimelineEntryKind kind;
  final String id;
  final CivilDate occurredOn;
  final String? title;
  final String? subtitle;
  final Money? amountCents;
  final int? mileageKm;

  /// `true` when every line of a maintenance record is a care item. `false`
  /// on a service. `null` on every other kind. [kind] stays `manutencao`.
  final bool? care;

  factory TimelineEntry.fromJson(Map<String, dynamic> json) {
    final amount = json['amount_cents'];
    return TimelineEntry(
      kind: TimelineEntryKind.fromWire(json['kind'] as String?),
      id: json['id'] as String,
      occurredOn: CivilDate.parse(json['occurred_on'] as String),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      amountCents: amount is int ? Money.fromCents(amount) : null,
      mileageKm: json['mileage_km'] as int?,
      care: json['care'] as bool?,
    );
  }
}

/// The title the row should show: the server's text when it sent one, otherwise
/// a label from [kind] — or "Cuidado" when [TimelineEntry.care] is true.
/// Never rebuilds a maintenance title from its items.
String titleOf(TimelineEntry entry) {
  final title = entry.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  if (entry.care == true) {
    return 'Cuidado';
  }
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => 'Manutenção',
    TimelineEntryKind.odometro => 'Quilometragem registrada',
    TimelineEntryKind.ipva => 'IPVA',
    TimelineEntryKind.licenciamento => 'Licenciamento',
    TimelineEntryKind.abastecimento => 'Abastecimento',
    TimelineEntryKind.desconhecido => 'Registro',
  };
}
