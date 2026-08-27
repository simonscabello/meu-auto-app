import 'package:meu_auto/core/domain/enum_parse.dart';

/// The stable error identifiers from the contract, plus the two the app coins
/// for failures that never reached the server.
enum ApiErrorCode {
  validationFailed,
  unauthorized,
  forbidden,
  notFound,
  methodNotAllowed,
  conflict,
  odometerRollback,
  rateLimited,

  /// A third party the server depends on did not answer — today, only the
  /// source behind the vehicle catalogue.
  ///
  /// Distinct from [rateLimited] and it matters: `rate_limited` means *this
  /// caller* is going too fast, while this one is somebody else's outage and
  /// nothing the person did. Nothing is broken and trying again shortly is the
  /// right advice.
  upstreamUnavailable,

  internal,
  desconhecido,

  // Local only. A network that never answered is not a code the API can send,
  // and it must not be reachable from the wire — see the explicit list below.
  semConexao,
  tempoEsgotado;

  /// Parses against the contract's codes only.
  ///
  /// The list is written out rather than using [values] on purpose: it keeps
  /// `semConexao` and `tempoEsgotado` unreachable from a response body, so a
  /// server that ever sent them could not make the app claim it was offline.
  static ApiErrorCode fromWire(String? raw) {
    return parseEnum(raw, const [
      validationFailed,
      unauthorized,
      forbidden,
      notFound,
      methodNotAllowed,
      conflict,
      odometerRollback,
      rateLimited,
      upstreamUnavailable,
      internal,
    ], fallback: desconhecido);
  }
}
