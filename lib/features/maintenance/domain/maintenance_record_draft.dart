import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/money.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_item.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_record.dart';

/// Field-level errors for a line of the record.
///
/// The contract keys errors as they were sent. An item error *should* arrive
/// indexed (`items.0.warranty_months`); today's server still lumped every
/// line under `items`. Both shapes are accepted so a later indexed payload
/// lights the right card instead of a banner at the top.
String? itemFieldError(Map<String, String> fields, int index, String name) {
  return fields['items.$index.$name'] ?? fields['items[$index].$name'];
}

/// One unsent line: the catalogue item plus the optional details of the job.
final class MaintenanceRecordLineDraft {
  const MaintenanceRecordLineDraft({
    required this.item,
    this.description,
    this.partBrand,
    this.costCents,
    this.warrantyMonths,
    this.warrantyKm,
  });

  final MaintenanceItem item;
  final String? description;
  final String? partBrand;
  final Money? costCents;
  final int? warrantyMonths;
  final int? warrantyKm;

  Map<String, dynamic> toJson() {
    final trimmedDescription = _text(description);
    final trimmedBrand = _text(partBrand);
    return {
      'maintenance_item_id': item.id,
      'description': ?trimmedDescription,
      'part_brand': ?trimmedBrand,
      'cost_cents': ?costCents?.cents,
      'warranty_months': ?warrantyMonths,
      'warranty_km': ?warrantyKm,
    };
  }

  MaintenanceRecordLineDraft copyWith({
    String? description,
    String? partBrand,
    Money? costCents,
    int? warrantyMonths,
    int? warrantyKm,
  }) {
    return MaintenanceRecordLineDraft(
      item: item,
      description: description ?? this.description,
      partBrand: partBrand ?? this.partBrand,
      costCents: costCents ?? this.costCents,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      warrantyKm: warrantyKm ?? this.warrantyKm,
    );
  }
}

/// The create-record payload, assembled on the client before the POST.
///
/// A record without an item resets no clock, so [canSave] is false until
/// there is at least one line. The same item cannot appear twice, and the
/// contract caps the list at 20.
final class MaintenanceRecordDraft {
  const MaintenanceRecordDraft({
    required this.id,
    required this.occurredOn,
    required this.kind,
    required this.items,
    this.mileageKm,
    this.workshopName,
    this.totalCostCents,
    this.notes,
  });

  static const maxItems = 20;

  static const noItemsReason = 'Adicione pelo menos um item para salvar.';

  final String id;
  final CivilDate occurredOn;
  final int? mileageKm;
  final MaintenanceRecordKind kind;
  final String? workshopName;
  final Money? totalCostCents;
  final String? notes;
  final List<MaintenanceRecordLineDraft> items;

  bool get canSave => items.isNotEmpty && items.length <= maxItems;

  String? get saveBlockedReason => canSave ? null : noItemsReason;

  bool canAdd(String itemId) {
    if (items.length >= maxItems) return false;
    for (final line in items) {
      if (line.item.id == itemId) return false;
    }
    return true;
  }

  MaintenanceRecordDraft add(MaintenanceItem item) {
    if (!canAdd(item.id)) return this;
    return _withItems([...items, MaintenanceRecordLineDraft(item: item)]);
  }

  MaintenanceRecordDraft remove(String itemId) {
    return _withItems([
      for (final line in items)
        if (line.item.id != itemId) line,
    ]);
  }

  MaintenanceRecordDraft replaceItems(List<MaintenanceItem> selected) {
    final kept = <String, MaintenanceRecordLineDraft>{
      for (final line in items) line.item.id: line,
    };
    return _withItems([
      for (final item in selected)
        kept[item.id] ?? MaintenanceRecordLineDraft(item: item),
    ]);
  }

  Map<String, dynamic> toJson() {
    final workshop = _text(workshopName);
    final note = _text(notes);
    final kindWire = kind == MaintenanceRecordKind.declared
        ? 'declared'
        : 'performed';
    return {
      'id': id,
      'occurred_on': occurredOn.toJson(),
      'mileage_km': ?mileageKm,
      'kind': kindWire,
      'workshop_name': ?workshop,
      'total_cost_cents': ?totalCostCents?.cents,
      'notes': ?note,
      'items': [for (final line in items) line.toJson()],
    };
  }

  MaintenanceRecordDraft _withItems(List<MaintenanceRecordLineDraft> next) {
    return MaintenanceRecordDraft(
      id: id,
      occurredOn: occurredOn,
      mileageKm: mileageKm,
      kind: kind,
      workshopName: workshopName,
      totalCostCents: totalCostCents,
      notes: notes,
      items: next,
    );
  }
}

String? _text(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
