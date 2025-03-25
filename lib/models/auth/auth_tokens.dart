// Business logic model for auth tokens
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String clientId;
  final String? email;

  // Calculate expiry time when created
  final DateTime createdAt;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.clientId,
    this.email,
  }) : createdAt = DateTime.now();

  // Convert from API response
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
      clientId: json['client_id'] as String,
      email: json['email'] as String?,
    );
  }

  // Convert to JSON for API requests or storage
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'client_id': clientId,
      if (email != null) 'email': email,
    };
  }

  // Check if token is expired or about to expire (with 30s buffer)
  bool get isExpired {
    var expiryTime = createdAt.add(Duration(seconds: expiresIn - 30));
    return DateTime.now().isAfter(expiryTime);
  }

  // Create a new instance with refreshed access token
  AuthTokens refreshedWith({
    required String accessToken,
    required int expiresIn,
  }) {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: this.refreshToken,
      expiresIn: expiresIn,
      clientId: this.clientId,
      email: this.email,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTokens &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          expiresIn == other.expiresIn &&
          clientId == other.clientId &&
          email == other.email;

  @override
  int get hashCode =>
      accessToken.hashCode ^
      refreshToken.hashCode ^
      expiresIn.hashCode ^
      clientId.hashCode ^
      (email?.hashCode ?? 0);
}
