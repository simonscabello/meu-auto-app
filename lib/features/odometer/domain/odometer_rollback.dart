import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/formatters.dart';
import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';

/// Which neighbour the reading collided with.
///
/// The server validates a reading against the entries either side of it in
/// time, so a rejection comes in two shapes: below the entry before it, or
/// above the entry after it. The contract only documents the first; both are
/// real (`internal/vehicle/service.go`, `CheckOdometerConsistency`).
enum OdometerConflictSide { anterior, posterior }

/// The `odometer_rollback` failure, unpacked.
///
/// Every field is optional on purpose: this is built from `details`, and a
/// dialog that throws because a key moved would replace a solvable problem
/// with a crash. When a field is missing the copy falls back to the server's
/// own message, which is already pt-BR and displayable.
final class OdometerRollback {
  const OdometerRollback({
    required this.side,
    this.neighbourMileageKm,
    this.neighbourOccurredOn,
    this.submittedMileageKm,
  });

  final OdometerConflictSide side;
  final int? neighbourMileageKm;
  final CivilDate? neighbourOccurredOn;
  final int? submittedMileageKm;

  /// Null when [failure] is not a rollback, so callers can branch on one check.
  static OdometerRollback? fromFailure(ApiFailure failure) {
    if (failure.code != ApiErrorCode.odometerRollback) {
      return null;
    }
    final details = failure.details;
    final isNext =
        details.containsKey('next_mileage_km') ||
        details.containsKey('next_occurred_on');
    final prefix = isNext ? 'next' : 'previous';

    return OdometerRollback(
      side: isNext
          ? OdometerConflictSide.posterior
          : OdometerConflictSide.anterior,
      neighbourMileageKm: _asInt(details['${prefix}_mileage_km']),
      neighbourOccurredOn: CivilDate.tryParse(
        details['${prefix}_occurred_on'] as String?,
      ),
      submittedMileageKm: _asInt(details['submitted_mileage_km']),
    );
  }

  /// The conflict in one sentence, using the real figures.
  ///
  /// Deliberately does NOT surface the server's `hint`: it tells the client to
  /// resend with source "correction", which is an instruction for the app, not
  /// something to show a person. The dialog offers that as a button instead.
  String explain(String serverMessage) {
    final neighbourKm = neighbourMileageKm;
    final neighbourDate = neighbourOccurredOn;
    final submitted = submittedMileageKm;
    if (neighbourKm == null || neighbourDate == null || submitted == null) {
      return serverMessage;
    }

    final date = formatCivilDate(neighbourDate);
    return switch (side) {
      OdometerConflictSide.anterior =>
        'Em $date o carro já estava com ${formatKm(neighbourKm)}. '
            'Você informou ${formatKm(submitted)}, que é menos.',
      OdometerConflictSide.posterior =>
        'Existe um registro de $date com ${formatKm(neighbourKm)}. '
            'Você informou ${formatKm(submitted)}, que ficaria acima dele.',
    };
  }

  /// What the override button promises.
  static const overrideLabel = 'O valor está certo, registrar assim';

  /// Why someone would legitimately override. Panels really do get replaced,
  /// and an earlier entry really can have been typed wrong.
  String get overrideHelp {
    return switch (side) {
      OdometerConflictSide.anterior =>
        'Use se o painel foi trocado ou se o registro anterior estava errado.',
      OdometerConflictSide.posterior =>
        'Use se o painel foi trocado ou se o registro posterior estava errado.',
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
