class ModelSetupConstants {
  static const String hfClientId = '56b2ee2d-c912-400d-9d5b-a43c2bdc5add';
  static const String hfRedirectUri = 'com.example.lilly://oauthredirect';
  static const String hfCallbackScheme = 'com.example.lilly';

  static const String authEndpoint = 'https://huggingface.co/oauth/authorize';
  static const String tokenEndpoint = 'https://huggingface.co/oauth/token';

  static const String modelFileName = 'gemma-4-E4B-it.litertlm';

  static const String modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm?download=true';

  static const String modelCardUrl =
      'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm';

  static const String oauthScope = 'openid profile gated-repos';
}
