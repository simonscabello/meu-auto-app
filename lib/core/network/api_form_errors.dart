import 'package:meu_auto/core/network/api_error_code.dart';
import 'package:meu_auto/core/network/api_failure.dart';

/// Turns an [ApiFailure] into the two things a form needs: errors attached to
/// fields, and a message for everything else.
///
/// One decision, made once. Login, register, the vehicle form and the odometer
/// sheet had each written their own version of it, and four more forms are
/// coming — the point of a stable `code` in the contract is that this branch
/// exists in exactly one place.
abstract final class ApiFormErrors {
  /// Deliberately not the server's message for 429.
  ///
  /// The API says only that the limit was hit; what a person needs to know is
  /// that waiting fixes it.
  static const rateLimitedBanner =
      'Houve muitas tentativas. Aguarde alguns minutos e tente novamente.';

  /// Field-level errors, keyed exactly as the request body was.
  ///
  /// Empty for anything that is not a validation failure: a 401 belongs to the
  /// form as a whole, not to one of its inputs.
  static Map<String, String> fieldsOf(ApiFailure failure) {
    if (failure.code != ApiErrorCode.validationFailed) {
      return const {};
    }
    return failure.fields;
  }

  /// The message to show above the form, or null when the failure was already
  /// spent on the fields.
  ///
  /// A validation failure is only "spent" if the form can show it. Pass
  /// [shownFields] — the keys the form renders an error under — and any other
  /// field's message comes back here instead; a failure with no field at all
  /// (a body the server could not read) always does. Returning null for every
  /// 422 used to leave some forms saying nothing: the save button stopped
  /// spinning and the reason was nowhere on screen.
  static String? bannerOf(ApiFailure failure, {Iterable<String>? shownFields}) {
    if (failure.code == ApiErrorCode.validationFailed) {
      final fields = failure.fields;
      if (fields.isEmpty) return failure.message;
      if (shownFields == null) return null;
      final shown = shownFields.toSet();
      for (final entry in fields.entries) {
        if (!shown.contains(entry.key)) return entry.value;
      }
      return null;
    }
    if (failure.code == ApiErrorCode.rateLimited) {
      return rateLimitedBanner;
    }
    return failure.message;
  }

  /// Whether the submit button should offer to try again rather than repeat
  /// the original verb: nothing was wrong with what the person typed.
  static bool isOffline(ApiFailure failure) {
    return failure.code == ApiErrorCode.semConexao ||
        failure.code == ApiErrorCode.tempoEsgotado;
  }
}
