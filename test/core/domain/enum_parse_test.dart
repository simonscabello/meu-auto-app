import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';

enum _Swatch { red, blue, desconhecido }

enum _Status { venceEmBreve, semBaseline, desconhecido }

void main() {
  test('unknown wire value returns desconhecido without throwing', () {
    expect(
      parseEnum('amarelo', _Swatch.values, fallback: _Swatch.desconhecido),
      _Swatch.desconhecido,
    );
  });

  test('known wire value matches the enum name', () {
    expect(
      parseEnum('blue', _Swatch.values, fallback: _Swatch.desconhecido),
      _Swatch.blue,
    );
  });

  test('null or empty raw value uses the fallback', () {
    expect(
      parseEnum(null, _Swatch.values, fallback: _Swatch.desconhecido),
      _Swatch.desconhecido,
    );
    expect(
      parseEnum('', _Swatch.values, fallback: _Swatch.desconhecido),
      _Swatch.desconhecido,
    );
  });

  group('snake_case on the wire', () {
    test('matches the camelCase name the enum uses', () {
      expect(
        parseEnum(
          'vence_em_breve',
          _Status.values,
          fallback: _Status.desconhecido,
        ),
        _Status.venceEmBreve,
      );
      expect(
        parseEnum(
          'sem_baseline',
          _Status.values,
          fallback: _Status.desconhecido,
        ),
        _Status.semBaseline,
      );
    });

    test('an exact name still wins', () {
      expect(
        parseEnum(
          'venceEmBreve',
          _Status.values,
          fallback: _Status.desconhecido,
        ),
        _Status.venceEmBreve,
      );
    });

    test('a snake_case value with no match still falls back', () {
      expect(
        parseEnum(
          'algo_novo_do_servidor',
          _Status.values,
          fallback: _Status.desconhecido,
        ),
        _Status.desconhecido,
      );
    });

    test('stray underscores do not throw', () {
      for (final raw in ['_', '__', 'a__b', '_leading', 'trailing_']) {
        expect(
          parseEnum(raw, _Status.values, fallback: _Status.desconhecido),
          _Status.desconhecido,
          reason: raw,
        );
      }
    });
  });
}
