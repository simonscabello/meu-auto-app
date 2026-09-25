import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/network/api_client.dart';
import 'package:meu_auto/core/network/api_paths.dart';
import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/auth/data/auth_repository.dart';
import 'package:meu_auto/features/auth/domain/profile_update.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

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

  test('updateProfile sends only what it names, and clear', () async {
    final adapter = _UserAdapter();
    final api = ApiClient(adapter: adapter, logPrint: (_) {});
    addTearDown(api.close);
    final repository = AuthRepository(api: api);

    await repository.updateProfile(
      const ProfileUpdate(
        birthDate: CivilDate(1990, 4, 12),
        cnhCategory: CnhCategory.ab,
        clear: {ProfileField.phone},
      ),
    );

    expect(adapter.method, 'PATCH');
    expect(adapter.path, ApiPaths.me);
    expect(adapter.json, {
      'birth_date': '1990-04-12',
      'cnh_category': 'AB',
      'clear': ['phone'],
    });
  });

  test(
    'uploadPhoto sends the bytes as the photo part of a multipart body',
    () async {
      final adapter = _UserAdapter();
      final api = ApiClient(adapter: adapter, logPrint: (_) {});
      addTearDown(api.close);
      final repository = AuthRepository(api: api);

      final user = await repository.uploadPhoto(
        bytes: [0xFF, 0xD8, 0xFF],
        filename: 'foto.jpg',
        contentType: 'image/jpeg',
      );

      expect(adapter.method, 'PUT');
      expect(adapter.path, ApiPaths.mePhoto);
      expect(adapter.form?.files.single.key, 'photo');
      expect(adapter.form?.files.single.value.filename, 'foto.jpg');
      expect(adapter.form?.files.single.value.length, 3);
      expect(user.photoUrl, 'https://bucket.test/foto.jpg');
    },
  );
}

/// Answers every request with a user and records what was sent.
class _UserAdapter implements HttpClientAdapter {
  String? method;
  String? path;
  Map<String, dynamic>? json;
  FormData? form;

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
    final data = options.data;
    if (data is FormData) form = data;
    if (data is Map) json = Map<String, dynamic>.from(data);
    if (requestStream != null) await requestStream.drain<void>();

    return ResponseBody.fromString(
      jsonEncode({
        'id': '11111111-1111-7111-8111-111111111111',
        'name': 'Ana',
        'email': 'ana@example.com',
        'created_at': '2026-01-15T12:00:00Z',
        'photo_url': 'https://bucket.test/foto.jpg',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
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
