import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SelectedVehicleStore {
  Future<String?> read();
  Future<void> write(String? id);
}

final class SharedPreferencesSelectedVehicleStore
    implements SelectedVehicleStore {
  SharedPreferencesSelectedVehicleStore({this.prefs});

  static const key = 'selected_vehicle_id';

  final SharedPreferences? prefs;

  Future<SharedPreferences> _prefs() async {
    final injected = prefs;
    if (injected != null) {
      return injected;
    }
    return SharedPreferences.getInstance();
  }

  @override
  Future<String?> read() async {
    final stored = await _prefs();
    return stored.getString(key);
  }

  @override
  Future<void> write(String? id) async {
    final stored = await _prefs();
    if (id == null) {
      await stored.remove(key);
      return;
    }
    await stored.setString(key, id);
  }
}
