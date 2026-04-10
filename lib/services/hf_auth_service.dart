import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../config/model_setup_constants.dart';
import '../models/hf_token_data.dart';
import 'hf_token_storage_service.dart';

class HfAuthResult {
  final bool success;
  final HfTokenData? tokenData;
  final String? error;

  const HfAuthResult({
    required this.success,
    this.tokenData,
    this.error,
  });
}

class HfAuthService {
  HfAuthService({
    HfTokenStorageService? tokenStorageService,
  }) : _tokenStorageService =
           tokenStorageService ?? HfTokenStorageService();

  final HfTokenStorageService _tokenStorageService;

  Future<HfTokenData?> getStoredToken() async {
    return _tokenStorageService.loadToken();
  }

  Future<void> clearStoredToken() async {
    await _tokenStorageService.clearToken();
  }

  Future<HfAuthResult> authenticate() async {
    try {
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUri = _buildAuthUri(codeChallenge);

      final result = await FlutterWebAuth2.authenticate(
        url: authUri.toString(),
        callbackUrlScheme: ModelSetupConstants.hfCallbackScheme,
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null || code.isEmpty) {
        return const HfAuthResult(
          success: false,
          error: 'No authorization code received.',
        );
      }

      final tokenData = await _exchangeCodeForToken(
        code: code,
        codeVerifier: codeVerifier,
      );

      if (tokenData == null) {
        return const HfAuthResult(
          success: false,
          error: 'Failed to exchange authorization code for token.',
        );
      }

      await _tokenStorageService.saveToken(tokenData);

      return HfAuthResult(
        success: true,
        tokenData: tokenData,
      );
    } catch (e) {
      return HfAuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Uri _buildAuthUri(String codeChallenge) {
    return Uri.parse(ModelSetupConstants.authEndpoint).replace(
      queryParameters: {
        'client_id': ModelSetupConstants.hfClientId,
        'response_type': 'code',
        'redirect_uri': ModelSetupConstants.hfRedirectUri,
        'scope': ModelSetupConstants.oauthScope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );
  }

  Future<HfTokenData?> _exchangeCodeForToken({
    required String code,
    required String codeVerifier,
  }) async {
    final response = await http.post(
      Uri.parse(ModelSetupConstants.tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': ModelSetupConstants.hfClientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': ModelSetupConstants.hfRedirectUri,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;

    final map = Map<String, dynamic>.from(decoded);
    final accessToken = map['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) return null;

    return HfTokenData(
      accessToken: accessToken,
      refreshToken: map['refresh_token'] as String?,
      tokenType: map['token_type'] as String?,
      expiresIn: map['expires_in'] as int?,
    );
  }

  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = ascii.encode(codeVerifier);
    final digest = sha256.convert(bytes).bytes;
    return base64UrlEncode(digest).replaceAll('=', '');
  }
}
