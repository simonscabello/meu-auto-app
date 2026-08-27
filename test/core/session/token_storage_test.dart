import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/session_tokens.dart';
import 'package:meu_auto/core/session/token_storage.dart';

void main() {
  final tokens = SessionTokens(
    accessToken: 'access-1',
    expiresAt: DateTime.utc(2026, 8, 26, 16, 30),
    refreshToken: 'refresh-1',
    refreshExpiresAt: DateTime.utc(2026, 9, 25, 16, 15),
  );

  test(
    'save then read returns the tokens from cache without a second backend read',
    () async {
      final backend = _RecordingBackend();
      final storage = TokenStorage.withBackend(backend);

      await storage.save(tokens);
      final first = await storage.read();
      final second = await storage.read();

      expect(first!.accessToken, 'access-1');
      expect(second!.refreshToken, 'refresh-1');
      expect(backend.reads, 0);
      expect(backend.writes, 1);
    },
  );

  test(
    'concurrent reads before the first load share the same backend Future',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final backend = _RecordingBackend(
        onRead: () async {
          if (!started.isCompleted) {
            started.complete();
          }
          await release.future;
        },
      );
      backend.values[TokenStorage.storageKey] = jsonEncode(tokens.toJson());
      final storage = TokenStorage.withBackend(backend);

      final futures = <Future<SessionTokens?>>[
        storage.read(),
        storage.read(),
        storage.read(),
      ];
      await started.future;
      expect(backend.reads, 1);
      release.complete();

      final results = await Future.wait(futures);
      expect(backend.reads, 1);
      expect(results.map((each) => each!.accessToken).toSet(), {'access-1'});
    },
  );

  test('clear wipes cache and backend', () async {
    final backend = _RecordingBackend();
    final storage = TokenStorage.withBackend(backend);
    await storage.save(tokens);
    await storage.clear();

    expect(await storage.read(), isNull);
    expect(backend.values, isEmpty);
  });
}

final class _RecordingBackend implements TokenStorageBackend {
  _RecordingBackend({this.onRead});

  final Future<void> Function()? onRead;
  final Map<String, String> values = {};
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    await onRead?.call();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
