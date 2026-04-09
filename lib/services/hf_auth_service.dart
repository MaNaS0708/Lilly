import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

class HfAuthResult {
  final bool success;
  final String? accessToken;
  final String? error;

  const HfAuthResult({
    required this.success,
    this.accessToken,
    this.error,
  });
}

class HfAuthService {
  static const String callbackScheme = 'com.example.lilly';
  static const String authUrl =
      'https://huggingface.co/oauth/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=com.example.lilly://oauthredirect&scope=openid%20profile%20read-repos';

  Future<HfAuthResult> authenticate() async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: callbackScheme,
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code == null || code.isEmpty) {
        return const HfAuthResult(
          success: false,
          error: 'No authorization code received.',
        );
      }

      return HfAuthResult(
        success: true,
        accessToken: code,
      );
    } catch (e) {
      return HfAuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }
}

