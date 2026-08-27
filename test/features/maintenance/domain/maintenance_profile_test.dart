import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/features/maintenance/domain/maintenance_profile.dart';

/// The profile is the only place the app reads "what does this car have?", and
/// every field on it is a count or a question the server wrote. Nothing here
/// decides applicability, so the tests are about parsing and about never
/// throwing on a value a newer server might send.
void main() {
  final complete = <String, dynamic>{
    'status': 'incomplete',
    'powertrain_known': true,
    'plan_count': 14,
    'not_applicable_count': 3,
    'missing_history_count': 6,
    'questions': [
      {
        'id': 'timing_drive',
        'prompt': 'Seu carro usa correia dentada ou corrente?',
        'help': 'Está no manual do carro.',
        'options': [
          {'value': 'belt', 'label': 'Correia dentada'},
          {'value': 'chain', 'label': 'Corrente de comando'},
          {'value': 'unknown', 'label': 'Não sei'},
        ],
      },
    ],
    'answers': {'fuel_kind': 'unknown'},
  };

  test('parses a complete profile', () {
    final profile = MaintenanceProfile.fromJson(complete);

    expect(profile.status, MaintenanceProfileStatus.incomplete);
    expect(profile.powertrainKnown, isTrue);
    expect(profile.planCount, 14);
    expect(profile.notApplicableCount, 3);
    expect(profile.missingHistoryCount, 6);
    expect(profile.hasOpenQuestions, isTrue);
    expect(profile.questions.single.id, 'timing_drive');
    expect(profile.questions.single.options.map((option) => option.value), [
      'belt',
      'chain',
      'unknown',
    ]);
    expect(profile.answers['fuel_kind'], 'unknown');
  });

  // "Não sei" has to survive the round trip: it is the value that tells the app
  // a question was answered and must not be asked again.
  test('keeps an unknown answer as an answer', () {
    final profile = MaintenanceProfile.fromJson({
      ...complete,
      'questions': const [],
      'answers': const {'timing_drive': 'unknown'},
    });

    expect(profile.hasOpenQuestions, isFalse);
    expect(profile.answers['timing_drive'], 'unknown');
  });

  test('a vehicle with no plan reads as unknown, not as empty', () {
    final profile = MaintenanceProfile.fromJson({
      ...complete,
      'status': 'unknown',
      'plan_count': 0,
    });

    expect(profile.status, MaintenanceProfileStatus.unknown);
    expect(profile.planCount, 0);
  });

  test('a status this build does not know falls back without throwing', () {
    final profile = MaintenanceProfile.fromJson({
      ...complete,
      'status': 'aguardando_fabricante',
    });
    expect(profile.status, MaintenanceProfileStatus.desconhecido);
  });

  test('missing collections parse as empty, never as null', () {
    final profile = MaintenanceProfile.fromJson(const {
      'status': 'ready',
      'powertrain_known': true,
    });

    expect(profile.questions, isEmpty);
    expect(profile.answers, isEmpty);
    expect(profile.planCount, 0);
  });

  test('a question with no options still parses', () {
    final profile = MaintenanceProfile.fromJson({
      ...complete,
      'questions': [
        {'id': 'nova_pergunta', 'prompt': 'Alguma coisa?'},
      ],
    });

    expect(profile.questions.single.id, 'nova_pergunta');
    expect(profile.questions.single.help, '');
    expect(profile.questions.single.options, isEmpty);
  });
}
