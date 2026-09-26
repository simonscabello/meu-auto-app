import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:meu_auto/core/push/push_device.dart';
import 'package:meu_auto/core/push/push_registration.dart';

/// The phone's push side, scripted.
final class FakePushDevice implements PushDevice {
  FakePushDevice({
    this.supported = true,
    this.firebase = true,
    this.token = 'token-1',
    this.permitted = false,
    this.grantOnRequest = true,
  });

  bool supported;

  /// False is a build without google-services.json: init "fails".
  bool firebase;
  String? token;
  bool permitted;
  bool grantOnRequest;

  int inits = 0;
  int permissionRequests = 0;
  int tokenDeletions = 0;
  Map<String, String>? initial;

  final taps = StreamController<Map<String, String>>.broadcast();
  final refreshes = StreamController<String>.broadcast();
  bool _initialized = false;

  @override
  bool get isSupported => supported;

  @override
  bool get isReady => _initialized && firebase;

  @override
  Future<void> init() async {
    inits++;
    _initialized = true;
  }

  @override
  Stream<Map<String, String>> get onTap => taps.stream;

  @override
  Future<Map<String, String>?> initialTap() async {
    final tap = initial;
    initial = null;
    return tap;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantOnRequest) permitted = true;
    return permitted;
  }

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<String?> currentToken() async => isReady ? token : null;

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  Future<void> deleteToken() async => tokenDeletions++;
}

final class MemoryPushOptOut implements PushOptOutStore {
  final optedOut = <String>{};

  @override
  Future<bool> isOptedOut(String userId) async => optedOut.contains(userId);

  @override
  Future<void> setOptedOut(String userId, {required bool optedOut}) async {
    optedOut ? this.optedOut.add(userId) : this.optedOut.remove(userId);
  }
}

/// One request to /me/devices.
typedef DeviceRequest = ({String method, Map<String, dynamic> body});

/// The /me/devices endpoints, recording what they were asked. [fail] makes
/// every call a dropped connection.
final class DeviceApi implements HttpClientAdapter {
  final requests = <DeviceRequest>[];
  bool fail = false;

  List<DeviceRequest> get registrations => [
    for (final r in requests)
      if (r.method == 'POST') r,
  ];

  List<DeviceRequest> get forgets => [
    for (final r in requests)
      if (r.method == 'DELETE') r,
  ];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (fail) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final data = options.data;
    requests.add((
      method: options.method,
      body: data is Map ? Map<String, dynamic>.from(data) : const {},
    ));
    return ResponseBody.fromString('', 204);
  }
}
