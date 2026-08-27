import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/onboarding/data/calibrar_skip_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('skip is remembered per vehicle and starts unset', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesCalibrarSkipStore();

    expect(await store.wasSkipped('v1'), isFalse);
    await store.markSkipped('v1');
    expect(await store.wasSkipped('v1'), isTrue);
    expect(await store.wasSkipped('v2'), isFalse);
  });
}
