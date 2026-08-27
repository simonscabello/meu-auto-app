import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'appearance starts as system and round-trips through preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPreferencesThemeModeStore();

      expect(await store.read(), ThemeMode.system);

      await store.write(ThemeMode.dark);
      expect(await store.read(), ThemeMode.dark);

      await store.write(ThemeMode.light);
      expect(await store.read(), ThemeMode.light);

      await store.write(ThemeMode.system);
      expect(await store.read(), ThemeMode.system);
    },
  );
}
