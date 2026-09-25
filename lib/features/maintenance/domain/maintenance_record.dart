import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';
import 'package:meu_auto/core/domain/money.dart';

/// How much the record can be relied on.
///
/// `performed` is a service that happened and can be proven. `declared` is the
/// owner saying so from memory — the used car bought with "last oil change at
/// 95.000 km" and no receipt. The difference is load-bearing at resale, so the
/// interface has to show it rather than flatten the two together.
enum MaintenanceRecordKind {
  performed,
  declared,
  desconhecido;

  static MaintenanceRecordKind fromWire(String? raw) =>
      parseEnum(raw, MaintenanceRecordKind.values, fallback: desconhecido);
}

/// One line of a service: what was done, to which catalogue item.
final class MaintenanceRecordItem {
  const MaintenanceRecordItem({
    required this.id,
    required this.maintenanceItemId,
    required this.itemSlug,
    required this.itemName,
    this.description,
    this.partBrand,
    this.costCents,
    this.warrantyMonths,
    this.warrantyKm,
    this.warrantyUntil,
    this.warrantyUntilKm,
  });

  final String id;
  final String maintenanceItemId;
  final String itemSlug;
  final String itemName;
  final String? description;
  final String? partBrand;
  final Money? costCents;

  /// What was agreed: a warranty of N months and/or N km.
  final int? warrantyMonths;
  final int? warrantyKm;

  /// What that works out to. **Derived by the server on every read**, never
  /// stored and never computed here — the record's own date plus the agreed
  /// months, and its mileage plus the agreed distance.
  final CivilDate? warrantyUntil;
  final int? warrantyUntilKm;

  bool get hasWarranty => warrantyUntil != null || warrantyUntilKm != null;

  factory MaintenanceRecordItem.fromJson(Map<String, dynamic> json) {
    final cost = json['cost_cents'] as int?;
    return MaintenanceRecordItem(
      id: json['id'] as String,
      maintenanceItemId: json['maintenance_item_id'] as String,
      itemSlug: json['item_slug'] as String,
      itemName: json['item_name'] as String,
      description: json['description'] as String?,
      partBrand: json['part_brand'] as String?,
      costCents: cost == null ? null : Money.fromCents(cost),
      warrantyMonths: json['warranty_months'] as int?,
      warrantyKm: json['warranty_km'] as int?,
      warrantyUntil: CivilDate.tryParse(json['warranty_until'] as String?),
      warrantyUntilKm: json['warranty_until_km'] as int?,
    );
  }
}

/// A service that happened: the event, plus one or more item lines.
///
/// The shape is what makes a "100.000 km service" work — one event, one
/// invoice, and each item resetting its own clock.
final class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.occurredOn,
    required this.mileageKm,
    required this.kind,
    this.workshopName,
    required this.totalCostCents,
    this.notes,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String vehicleId;
  final CivilDate occurredOn;
  final int? mileageKm;
  final MaintenanceRecordKind kind;
  final String? workshopName;
  final Money totalCostCents;
  final String? notes;
  final List<MaintenanceRecordItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The item names, comma separated — how the list identifies a record.
  ///
  /// Built from what the server named the items, never from the slug.
  String get itemsSummary => items.map((item) => item.itemName).join(', ');

  /// What the record is, in the few words a title holds: the one item, the
  /// two, or the first and how many more. A revisão names the visit by
  /// itself.
  ///
  /// The same words head the record's own screen and its line in a list.
  /// The list used to print the whole comma list, which cut a service of
  /// four items at "Balanceamento, Calib…", mid-word, beside the cost;
  /// [itemsSummary] still says every item to a screen reader.
  String get title {
    if (items.isEmpty) return 'Manutenção';
    for (final item in items) {
      if (item.itemSlug == 'revisao') {
        final others = items.length - 1;
        if (others == 0) return item.itemName;
        return others == 1
            ? '${item.itemName} e mais 1 item'
            : '${item.itemName} e mais $others itens';
      }
    }
    if (items.length == 1) return items.first.itemName;
    if (items.length == 2) {
      return '${items[0].itemName} e ${items[1].itemName}';
    }
    return '${items.first.itemName} e mais ${items.length - 1} itens';
  }

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return MaintenanceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      occurredOn: CivilDate.parse(json['occurred_on'] as String),
      mileageKm: json['mileage_km'] as int?,
      kind: MaintenanceRecordKind.fromWire(json['kind'] as String?),
      workshopName: json['workshop_name'] as String?,
      totalCostCents: Money.fromCents(json['total_cost_cents'] as int),
      notes: json['notes'] as String?,
      items: [
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map)
              MaintenanceRecordItem.fromJson(Map<String, dynamic>.from(item)),
      ],
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
