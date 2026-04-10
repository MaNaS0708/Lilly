class ModelSetupConstants {
  static const String hfClientId = 'PASTE_YOUR_REAL_HF_CLIENT_ID_HERE';
  static const String hfRedirectUri = 'com.example.lilly://oauthredirect';
  static const String hfCallbackScheme = 'com.example.lilly';

  static const String authEndpoint = 'https://huggingface.co/oauth/authorize';
  static const String tokenEndpoint = 'https://huggingface.co/oauth/token';

  static const String modelFileName = 'gemma-4-E4B-it-web.task';

  static const String modelUrl =
      'https://huggingface.co/huggingworld/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it-web.task?download=true';

  static const String modelCardUrl =
      'https://huggingface.co/huggingworld/gemma-4-E4B-it-litert-lm';

  static const String oauthScope = 'openid profile gated-repos';
}
