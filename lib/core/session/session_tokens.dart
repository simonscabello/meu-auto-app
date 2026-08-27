final class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;

  factory SessionTokens.fromJson(Map<String, dynamic> json) {
    return SessionTokens(
      accessToken: json['access_token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      refreshToken: json['refresh_token'] as String,
      refreshExpiresAt: DateTime.parse(
        json['refresh_expires_at'] as String,
      ).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'refresh_token': refreshToken,
      'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
    };
  }

  bool isAccessExpiringWithin(Duration window, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    return expiresAt.difference(clock) < window;
  }

  @override
  String toString() {
    return 'SessionTokens(expiresAt: $expiresAt, refreshExpiresAt: $refreshExpiresAt)';
  }
}
