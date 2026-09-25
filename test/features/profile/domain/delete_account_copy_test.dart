import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/profile/domain/delete_account_copy.dart';

void main() {
  test('says what deletion erases, and that it cannot be undone', () {
    const sentence = DeleteAccountCopy.consequence;
    expect(sentence, contains('conta'));
    expect(sentence, contains('veículos'));
    expect(sentence, contains('sem como recuperar'));
  });
}
