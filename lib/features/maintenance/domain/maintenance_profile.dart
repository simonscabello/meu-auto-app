import 'package:meu_auto/core/domain/enum_parse.dart';

/// What the vehicle needs, and what we still do not know about it.
///
/// There is no profile table behind this — a plan already joins one vehicle to
/// one catalogue item. What this adds is the part a plan cannot hold: the
/// questions nobody has answered yet.
///
/// The app never decides applicability. It asks a question the server wrote,
/// posts back an answer the server offered, and re-reads the plans. Which
/// catalogue items an answer turns on and off stays on the server, so the two
/// halves cannot disagree.
enum MaintenanceProfileStatus {
  /// No plan at all. Say so plainly and offer to add one — never invent a
  /// schedule for a car we know nothing about.
  unknown,

  /// There are plans and something is still open.
  incomplete,

  /// Nothing left to ask.
  ready,

  desconhecido;

  static MaintenanceProfileStatus fromWire(String? raw) =>
      parseEnum(raw, MaintenanceProfileStatus.values, fallback: desconhecido);
}

/// One answer, as the server offers it. The value travels back untouched.
final class MaintenanceProfileOption {
  const MaintenanceProfileOption({required this.value, required this.label});

  final String value;
  final String label;

  factory MaintenanceProfileOption.fromJson(Map<String, dynamic> json) {
    return MaintenanceProfileOption(
      value: json['value'] as String,
      label: json['label'] as String,
    );
  }
}

/// Something about the car that cannot be derived and has to be asked.
///
/// Both the wording and the options come from the server. A question this build
/// has never heard of still renders correctly, which is what lets a new one ship
/// without an app release.
final class MaintenanceProfileQuestion {
  const MaintenanceProfileQuestion({
    required this.id,
    required this.prompt,
    required this.help,
    required this.options,
  });

  final String id;
  final String prompt;
  final String help;
  final List<MaintenanceProfileOption> options;

  factory MaintenanceProfileQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return MaintenanceProfileQuestion(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      help: json['help'] as String? ?? '',
      options: [
        if (rawOptions is List)
          for (final option in rawOptions)
            if (option is Map)
              MaintenanceProfileOption.fromJson(
                Map<String, dynamic>.from(option),
              ),
      ],
    );
  }
}

final class MaintenanceProfile {
  const MaintenanceProfile({
    required this.status,
    required this.powertrainKnown,
    required this.planCount,
    required this.notApplicableCount,
    required this.missingHistoryCount,
    required this.questions,
    required this.answers,
  });

  final MaintenanceProfileStatus status;

  /// False when the vehicle has no fuel type — the one gap that blocks knowing
  /// anything about the engine. The app asks for the fuel instead of guessing.
  final bool powertrainKnown;

  final int planCount;
  final int notApplicableCount;

  /// Items with no record that nobody has been asked about. A "não sei" already
  /// given does not count, which is what makes the prompt go away.
  final int missingHistoryCount;

  final List<MaintenanceProfileQuestion> questions;

  /// What has already been answered, question id to answer value.
  final Map<String, String> answers;

  /// Whether anything is worth interrupting the owner for.
  bool get hasOpenQuestions => questions.isNotEmpty;

  factory MaintenanceProfile.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'];
    final rawAnswers = json['answers'];
    return MaintenanceProfile(
      status: MaintenanceProfileStatus.fromWire(json['status'] as String?),
      powertrainKnown: json['powertrain_known'] as bool? ?? false,
      planCount: json['plan_count'] as int? ?? 0,
      notApplicableCount: json['not_applicable_count'] as int? ?? 0,
      missingHistoryCount: json['missing_history_count'] as int? ?? 0,
      questions: [
        if (rawQuestions is List)
          for (final question in rawQuestions)
            if (question is Map)
              MaintenanceProfileQuestion.fromJson(
                Map<String, dynamic>.from(question),
              ),
      ],
      answers: {
        if (rawAnswers is Map)
          for (final entry in rawAnswers.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      },
    );
  }
}
