import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

enum TimelineEntryKind {
  manutencao,
  odometro,
  ipva,
  licenciamento,
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
  });

  final TimelineEntryKind kind;
  final String id;
  final CivilDate occurredOn;
  final String? title;
  final String? subtitle;
  final Money? amountCents;
  final int? mileageKm;

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
    );
  }
}

/// The title the row should show: the server's text when it sent one, otherwise
/// a label from [kind]. Never rebuilds a maintenance title from its items —
/// if the server changes the wording, the screen follows.
String titleOf(TimelineEntry entry) {
  final title = entry.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  return switch (entry.kind) {
    TimelineEntryKind.manutencao => 'Manutenção',
    TimelineEntryKind.odometro => 'Quilometragem registrada',
    TimelineEntryKind.ipva => 'IPVA',
    TimelineEntryKind.licenciamento => 'Licenciamento',
    TimelineEntryKind.desconhecido => 'Registro',
  };
}
