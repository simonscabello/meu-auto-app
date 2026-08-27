import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/core/theme/theme_mode_store.dart';

final themeModeStoreProvider = Provider<ThemeModeStore>((ref) {
  return SharedPreferencesThemeModeStore();
});

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() {
    return ref.watch(themeModeStoreProvider).read();
  }

  Future<void> setMode(ThemeMode mode) async {
    await ref.read(themeModeStoreProvider).write(mode);
    state = AsyncData(mode);
  }
}
