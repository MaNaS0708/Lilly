class HfTokenData {
  final String accessToken;
  final String? refreshToken;
  final String? tokenType;
  final int? expiresIn;

  const HfTokenData({
    required this.accessToken,
    this.refreshToken,
    this.tokenType,
    this.expiresIn,
  });

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
    };
  }

  factory HfTokenData.fromMap(Map<String, dynamic> map) {
    return HfTokenData(
      accessToken: (map['accessToken'] as String?) ?? '',
      refreshToken: map['refreshToken'] as String?,
      tokenType: map['tokenType'] as String?,
      expiresIn: map['expiresIn'] as int?,
    );
  }
}
