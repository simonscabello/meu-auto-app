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
  static String? bannerOf(ApiFailure failure) {
    if (failure.code == ApiErrorCode.validationFailed) {
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
