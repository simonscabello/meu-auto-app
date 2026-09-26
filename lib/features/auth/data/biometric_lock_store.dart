import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final biometricLockStoreProvider = Provider<BiometricLockStore>((ref) {
  return SecureBiometricLockStore();
});

/// Who turned biometric sign-in on, on this phone, and who has already been
/// invited to.
///
/// It keeps the account's id, not a yes/no: the lock belongs to the person
/// who turned it on, and another account signing in on the same phone must
/// not inherit it. No password is ever kept here or anywhere else.
abstract interface class BiometricLockStore {
  Future<String?> enrolledUserId();
  Future<void> enroll(String userId);
  Future<void> clearEnrollment();

  /// The last account shown the invitation, so it is not repeated at every
  /// sign-in.
  Future<String?> offeredUserId();
  Future<void> markOffered(String userId);
}

/// Next to the session tokens, in the phone's secure storage: switching the
/// lock off should take as much as reading the tokens does.
final class SecureBiometricLockStore implements BiometricLockStore {
  SecureBiometricLockStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const enrolledKey = 'biometric_user_id';
  static const offeredKey = 'biometric_offered_user_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> enrolledUserId() => _storage.read(key: enrolledKey);

  @override
  Future<void> enroll(String userId) {
    return _storage.write(key: enrolledKey, value: userId);
  }

  @override
  Future<void> clearEnrollment() => _storage.delete(key: enrolledKey);

  @override
  Future<String?> offeredUserId() => _storage.read(key: offeredKey);

  @override
  Future<void> markOffered(String userId) {
    return _storage.write(key: offeredKey, value: userId);
  }
}

/// Keeps it in memory. For tests.
final class MemoryBiometricLockStore implements BiometricLockStore {
  MemoryBiometricLockStore({this._enrolled, this._offered});

  String? _enrolled;
  String? _offered;

  @override
  Future<String?> enrolledUserId() async => _enrolled;

  @override
  Future<void> enroll(String userId) async => _enrolled = userId;

  @override
  Future<void> clearEnrollment() async => _enrolled = null;

  @override
  Future<String?> offeredUserId() async => _offered;

  @override
  Future<void> markOffered(String userId) async => _offered = userId;
}
