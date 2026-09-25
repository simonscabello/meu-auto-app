import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/features/auth/domain/user.dart';

/// The optional personal fields a PATCH can empty through `clear`.
enum ProfileField {
  birthDate('birth_date'),
  phone('phone'),
  cnhCategory('cnh_category'),
  cnhExpiresOn('cnh_expires_on');

  const ProfileField(this.wire);

  final String wire;
}

/// A PATCH of the account's personal data.
///
/// What is null is not sent and stays as it was on the server; what is in
/// [clear] is emptied. A `null` in the body would mean the same as leaving
/// the field out, which is why emptying needs its own list.
final class ProfileUpdate {
  const ProfileUpdate({
    this.birthDate,
    this.phone,
    this.cnhCategory,
    this.cnhExpiresOn,
    this.clear = const {},
  });

  final CivilDate? birthDate;

  /// Digits, or the masked text; the server keeps the digits.
  final String? phone;
  final CnhCategory? cnhCategory;
  final CivilDate? cnhExpiresOn;
  final Set<ProfileField> clear;

  Map<String, dynamic> toJson() => {
    if (birthDate != null) 'birth_date': birthDate!.toJson(),
    if (phone != null) 'phone': phone,
    if (cnhCategory != null) 'cnh_category': cnhCategory!.wire,
    if (cnhExpiresOn != null) 'cnh_expires_on': cnhExpiresOn!.toJson(),
    if (clear.isNotEmpty) 'clear': [for (final field in clear) field.wire],
  };
}
