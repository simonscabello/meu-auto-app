import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_tokens.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Disk backend for [TokenStorage]. Production uses [FlutterSecureStorage];
/// tests inject a fake so they can delay reads and count them.
abstract interface class TokenStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _backend = _FlutterSecureBackend(storage ?? const FlutterSecureStorage());

  @visibleForTesting
  TokenStorage.withBackend(this._backend);

  factory TokenStorage.memory() => TokenStorage.withBackend(_MemoryBackend());

  static const storageKey = 'session_tokens';

  final TokenStorageBackend _backend;

  SessionTokens? _cache;
  bool _hasLoaded = false;
  Future<SessionTokens?>? _inFlightRead;

  Future<SessionTokens?> read() {
    if (_hasLoaded) {
      return Future<SessionTokens?>.value(_cache);
    }
    final inFlight = _inFlightRead;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _readFromBackend().whenComplete(() {
      _inFlightRead = null;
    });
    _inFlightRead = future;
    return future;
  }

  Future<SessionTokens?> _readFromBackend() async {
    final raw = await _backend.read(storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = null;
      _hasLoaded = true;
      return null;
    }
    final decoded = jsonDecode(raw);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    _cache = SessionTokens.fromJson(map);
    _hasLoaded = true;
    return _cache;
  }

  Future<void> save(SessionTokens tokens) async {
    _cache = tokens;
    _hasLoaded = true;
    await _backend.write(storageKey, jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _cache = null;
    _hasLoaded = true;
    await _backend.delete(storageKey);
  }
}

final class _FlutterSecureBackend implements TokenStorageBackend {
  _FlutterSecureBackend(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class _MemoryBackend implements TokenStorageBackend {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
