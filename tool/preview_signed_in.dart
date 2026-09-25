// Development-only entrypoint: boots the app already signed in, so a local
// build can be inspected in a browser without typing credentials.
//
//   flutter build web -t tool/preview_signed_in.dart -o <dir> \
//     --dart-define=API_BASE_URL=http://localhost:8080
//
// then put the Session JSON returned by `POST /v1/auth/login` next to the
// build as `preview_session.json` and serve the folder. Without that file it
// is exactly `lib/main.dart`, and no release build uses it: `flutter build`
// targets `lib/main.dart` unless told otherwise.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/main.dart' as app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await _seedSession();
  }
  app.main();
}

Future<void> _seedSession() async {
  const storage = FlutterSecureStorage();
  // Only into an empty store: the app rotates the refresh token as it runs,
  // and writing the original back on every reload would present a revoked
  // token — which the server reads as theft and answers by ending every
  // session of the account.
  final stored = await storage.read(key: TokenStorage.storageKey);
  if (stored != null && stored.isNotEmpty) {
    return;
  }
  try {
    final response = await Dio(
      BaseOptions(receiveTimeout: const Duration(seconds: 3)),
    ).get<String>(Uri.base.resolve('preview_session.json').toString());
    final json = jsonDecode(response.data ?? '{}') as Map<String, dynamic>;
    await storage.write(
      key: TokenStorage.storageKey,
      value: jsonEncode({
        'access_token': json['access_token'],
        'expires_at': json['expires_at'],
        'refresh_token': json['refresh_token'],
        'refresh_expires_at': json['refresh_expires_at'],
      }),
    );
  } on Object {
    // No file next to the build: start signed out, like the real app.
  }
}
