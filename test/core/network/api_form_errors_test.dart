import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';
import 'package:meu_auto/core/network/api_form_errors.dart';

void main() {
  test('422 maps details.fields onto each submitted key', () {
    const failure = ApiFailure(
      code: ApiErrorCode.validationFailed,
      message: 'Não foi possível criar a conta.',
      fields: {
        'email': 'Informe um e-mail válido.',
        'password': 'A senha deve ter pelo menos 8 caracteres.',
        'name': 'Informe seu nome.',
      },
    );

    expect(ApiFormErrors.fieldsOf(failure), {
      'email': 'Informe um e-mail válido.',
      'password': 'A senha deve ter pelo menos 8 caracteres.',
      'name': 'Informe seu nome.',
    });
    expect(ApiFormErrors.bannerOf(failure), isNull);
  });

  test('401 login error is a banner without pointing at a field', () {
    const failure = ApiFailure(
      code: ApiErrorCode.unauthorized,
      message: 'E-mail ou senha incorretos.',
    );

    expect(ApiFormErrors.fieldsOf(failure), isEmpty);
    expect(ApiFormErrors.bannerOf(failure), 'E-mail ou senha incorretos.');
  });

  test('429 uses a dedicated message about too many attempts', () {
    const failure = ApiFailure(
      code: ApiErrorCode.rateLimited,
      message:
          'Muitas tentativas de login. Aguarde alguns minutos e tente novamente.',
    );

    expect(ApiFormErrors.fieldsOf(failure), isEmpty);
    final banner = ApiFormErrors.bannerOf(failure);
    expect(banner, isNotNull);
    expect(banner!.toLowerCase(), contains('tentativas'));
    expect(banner.toLowerCase(), contains('minutos'));
    expect(banner, isNot(contains('rate_limited')));
    expect(banner, isNot(contains('429')));
  });

  test('offline uses the local ApiFailure message', () {
    const failure = ApiFailure.semConexao();

    expect(ApiFormErrors.fieldsOf(failure), isEmpty);
    expect(
      ApiFormErrors.bannerOf(failure),
      'O Meu Auto precisa de internet para funcionar. Conecte-se e tente de novo.',
    );
    expect(ApiFormErrors.isOffline(failure), isTrue);
  });

  test('a timeout also reads as offline, so the button offers a retry', () {
    const failure = ApiFailure.tempoEsgotado();

    expect(ApiFormErrors.isOffline(failure), isTrue);
    expect(
      ApiFormErrors.bannerOf(failure),
      'O servidor demorou a responder. Tente de novo.',
    );
  });

  test('a 409 shows the server message, unchanged', () {
    const failure = ApiFailure(
      code: ApiErrorCode.conflict,
      message: 'Já existe um IPVA para este ano.',
    );

    expect(ApiFormErrors.fieldsOf(failure), isEmpty);
    expect(ApiFormErrors.bannerOf(failure), 'Já existe um IPVA para este ano.');
    expect(ApiFormErrors.isOffline(failure), isFalse);
  });

  test('a 422 the form cannot show on a field becomes the banner', () {
    const failure = ApiFailure(
      code: ApiErrorCode.validationFailed,
      message: 'Não foi possível atualizar a manutenção.',
      fields: {
        'mileage_km': 'Informe a quilometragem.',
        'total_cost_cents': 'Valor acima do permitido.',
      },
    );

    // The edit sheet renders only the mileage error; the cost one would vanish.
    expect(
      ApiFormErrors.bannerOf(failure, shownFields: const ['mileage_km']),
      'Valor acima do permitido.',
    );
    expect(
      ApiFormErrors.bannerOf(
        failure,
        shownFields: const ['mileage_km', 'total_cost_cents'],
      ),
      isNull,
    );
  });

  test('a 422 with no field at all is always shown', () {
    const failure = ApiFailure(
      code: ApiErrorCode.validationFailed,
      message: 'Corpo da requisição inválido.',
    );
    expect(ApiFormErrors.bannerOf(failure), 'Corpo da requisição inválido.');
  });
}
