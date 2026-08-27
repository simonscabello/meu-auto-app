import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meu_auto/features/onboarding/data/calibrar_skip_store.dart';

final calibrarSkipStoreProvider = Provider<CalibrarSkipStore>((ref) {
  return SharedPreferencesCalibrarSkipStore();
});
