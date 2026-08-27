import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/config/app_config.dart';

void main() {
  test('apiUrl defaults to the emulator host under /v1', () {
    expect(AppConfig.apiUrl, 'http://10.0.2.2:8080/v1');
    expect(AppConfig.isProduction, isFalse);
  });
}
