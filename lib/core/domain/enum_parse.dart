/// Parses a wire enum value, with a required fallback.
///
/// Matching is by [Enum.name] first, then by the same name written in
/// `snake_case` — the API sends `vence_em_breve` and `maintenance_plan`, Dart
/// spells them `venceEmBreve` and `maintenancePlan`. Doing the conversion here
/// means no feature has to carry its own copy of it.
///
/// Every domain enum in the app ends with `desconhecido` and exposes a static
/// `fromWire` built on this. That is not politeness: the contract says a value
/// the server adds later must not crash an app that is already published, so
/// falling back has to be the easy path and throwing has to be impossible.
T parseEnum<T extends Enum>(
  String? raw,
  List<T> values, {
  required T fallback,
}) {
  if (raw == null || raw.isEmpty) return fallback;

  for (final value in values) {
    if (value.name == raw) return value;
  }

  final camel = _snakeToCamel(raw);
  if (camel != raw) {
    for (final value in values) {
      if (value.name == camel) return value;
    }
  }

  return fallback;
}

String _snakeToCamel(String raw) {
  final parts = raw.split('_');
  if (parts.length == 1) return raw;

  final buffer = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    if (part.isEmpty) continue;
    buffer
      ..write(part[0].toUpperCase())
      ..write(part.substring(1));
  }
  return buffer.toString();
}
