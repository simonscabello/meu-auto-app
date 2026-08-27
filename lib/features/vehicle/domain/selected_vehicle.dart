/// Picks which vehicle is active given the persisted id and the current list.
String? resolveSelectedVehicleId({
  required Iterable<String> vehicleIds,
  required String? storedId,
}) {
  final ids = vehicleIds.toList();
  if (ids.isEmpty) {
    return null;
  }
  if (storedId != null) {
    for (final id in ids) {
      if (id == storedId) {
        return storedId;
      }
    }
  }
  return ids.first;
}
