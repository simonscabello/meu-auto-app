import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';

void main() {
  test(
    'changePassword sends both credentials and parses the new session',
    () async {
      final adapter = _RecordingAdapter();
      final api = ApiClient(adapter: adapter, logPrint: (_) {});
      addTearDown(api.close);
      final repository = AuthRepository(api: api);

      final session = await repository.changePassword(
        currentPassword: 'senha-atual',
        newPassword: 'senha-nova-123',
      );

      expect(adapter.method, 'POST');
      expect(adapter.path, ApiPaths.changePassword);
      expect(adapter.body, {
        'current_password': 'senha-atual',
        'new_password': 'senha-nova-123',
      });
      expect(session.user.email, 'ana@example.com');
      expect(session.tokens.refreshToken, 'refresh-novo');
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  String? method;
  String? path;
  Map<String, dynamic> body = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.path;
    body = Map<String, dynamic>.from(options.data as Map);
    if (requestStream != null) await requestStream.drain<void>();

    return ResponseBody.fromString(
      jsonEncode({
        'user': {
          'id': '11111111-1111-7111-8111-111111111111',
          'name': 'Ana',
          'email': 'ana@example.com',
          'created_at': '2026-01-15T12:00:00Z',
        },
        'token_type': 'Bearer',
        'access_token': 'access-novo',
        'expires_at': '2026-08-28T12:15:00Z',
        'refresh_token': 'refresh-novo',
        'refresh_expires_at': '2026-09-27T12:00:00Z',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
