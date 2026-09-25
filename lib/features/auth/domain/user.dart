import 'package:meu_auto/core/domain/civil_date.dart';
import 'package:meu_auto/core/domain/enum_parse.dart';

/// The driving licence categories a CNH prints. `desconhecido` is a category
/// a newer server may send that this build does not know.
enum CnhCategory {
  a,
  b,
  ab,
  c,
  d,
  e,
  ac,
  ad,
  ae,
  desconhecido;

  static CnhCategory fromWire(String? raw) =>
      parseEnum(raw?.toLowerCase(), CnhCategory.values, fallback: desconhecido);

  /// "AB", as the licence prints it and the server takes it.
  String get wire => name.toUpperCase();

  /// The categories someone can choose, in the order the licence lists them.
  static const choosable = [a, b, ab, c, d, e, ac, ad, ae];
}

final class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.birthDate,
    this.phone,
    this.cnhCategory,
    this.cnhExpiresOn,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  final CivilDate? birthDate;

  /// Digits only, with the DDD: "11912345678". The mask is the screen's.
  final String? phone;

  final CnhCategory? cnhCategory;
  final CivilDate? cnhExpiresOn;

  /// A signed URL that expires in a day and changes on every response. Never
  /// stored; read `/me` again for a fresh one.
  final String? photoUrl;

  /// Every personal field is optional, and a server from before they existed
  /// sends none of them: the app still opens.
  factory User.fromJson(Map<String, dynamic> json) {
    final category = json['cnh_category'] as String?;
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      birthDate: CivilDate.tryParse(json['birth_date'] as String?),
      phone: json['phone'] as String?,
      cnhCategory: category == null ? null : CnhCategory.fromWire(category),
      cnhExpiresOn: CivilDate.tryParse(json['cnh_expires_on'] as String?),
      photoUrl: json['photo_url'] as String?,
    );
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
