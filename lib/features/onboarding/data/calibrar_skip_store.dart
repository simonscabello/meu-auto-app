import 'package:shared_preferences/shared_preferences.dart';

abstract interface class CalibrarSkipStore {
  Future<bool> wasSkipped(String vehicleId);
  Future<void> markSkipped(String vehicleId);
}

final class SharedPreferencesCalibrarSkipStore implements CalibrarSkipStore {
  SharedPreferencesCalibrarSkipStore({this.prefs});

  final SharedPreferences? prefs;

  static String keyFor(String vehicleId) => 'calibrar_skipped_$vehicleId';

  Future<SharedPreferences> _prefs() async {
    final injected = prefs;
    if (injected != null) return injected;
    return SharedPreferences.getInstance();
  }

  @override
  Future<bool> wasSkipped(String vehicleId) async {
    final stored = await _prefs();
    return stored.getBool(keyFor(vehicleId)) ?? false;
  }

  @override
  Future<void> markSkipped(String vehicleId) async {
    final stored = await _prefs();
    await stored.setBool(keyFor(vehicleId), true);
  }
}

final class MemoryCalibrarSkipStore implements CalibrarSkipStore {
  MemoryCalibrarSkipStore([Set<String>? skipped]) : _skipped = {...?skipped};

  final Set<String> _skipped;

  @override
  Future<bool> wasSkipped(String vehicleId) async =>
      _skipped.contains(vehicleId);

  @override
  Future<void> markSkipped(String vehicleId) async {
    _skipped.add(vehicleId);
  }
}
