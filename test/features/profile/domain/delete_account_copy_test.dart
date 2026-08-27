import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/profile/domain/delete_account_copy.dart';

void main() {
  test('lists exactly what deletion erases, and that it cannot be undone', () {
    expect(DeleteAccountCopy.whatIsErased, [
      'A conta',
      'Os veículos',
      'Todo o histórico de manutenção',
      'A quilometragem',
      'Os prazos',
      'As apólices',
    ]);
    expect(
      DeleteAccountCopy.irreversible.toLowerCase(),
      contains('irreversível'),
    );
    expect(DeleteAccountCopy.irreversible.toLowerCase(), contains('recuperar'));
  });
}
