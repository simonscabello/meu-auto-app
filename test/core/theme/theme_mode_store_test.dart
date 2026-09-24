import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Dark is the identity — a night cluster — so a fresh install starts there
  // rather than following the phone. The other two stay one tap away.
  test('appearance starts dark and round-trips through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesThemeModeStore();

    expect(await store.read(), ThemeMode.dark);

    await store.write(ThemeMode.light);
    expect(await store.read(), ThemeMode.light);

    await store.write(ThemeMode.system);
    expect(await store.read(), ThemeMode.system);

    await store.write(ThemeMode.dark);
    expect(await store.read(), ThemeMode.dark);
  });

  test('a value this build does not know falls back to dark', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
    final store = SharedPreferencesThemeModeStore();
    expect(await store.read(), ThemeMode.dark);
  });
}
