class VoiceLanguage {
  const VoiceLanguage({
    required this.code,
    required this.label,
    required this.voskDirectoryName,
    required this.voskArchiveFileName,
    required this.voskModelUrl,
    required this.minimumArchiveBytes,
  });

  final String code;
  final String label;
  final String voskDirectoryName;
  final String voskArchiveFileName;
  final String voskModelUrl;
  final int minimumArchiveBytes;

  static const english = VoiceLanguage(
    code: 'en',
    label: 'English',
    voskDirectoryName: 'vosk-model-small-en-us-0.15',
    voskArchiveFileName: 'vosk-model-small-en-us-0.15.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    minimumArchiveBytes: 20000000,
  );

  static const hindi = VoiceLanguage(
    code: 'hi',
    label: 'Hindi',
    voskDirectoryName: 'vosk-model-small-hi-0.22',
    voskArchiveFileName: 'vosk-model-small-hi-0.22.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip',
    minimumArchiveBytes: 20000000,
  );

  static const spanish = VoiceLanguage(
    code: 'es',
    label: 'Spanish',
    voskDirectoryName: 'vosk-model-small-es-0.42',
    voskArchiveFileName: 'vosk-model-small-es-0.42.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip',
    minimumArchiveBytes: 20000000,
  );

  static const french = VoiceLanguage(
    code: 'fr',
    label: 'French',
    voskDirectoryName: 'vosk-model-small-fr-0.22',
    voskArchiveFileName: 'vosk-model-small-fr-0.22.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
    minimumArchiveBytes: 20000000,
  );

  static const german = VoiceLanguage(
    code: 'de',
    label: 'German',
    voskDirectoryName: 'vosk-model-small-de-0.15',
    voskArchiveFileName: 'vosk-model-small-de-0.15.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip',
    minimumArchiveBytes: 20000000,
  );

  static const portuguese = VoiceLanguage(
    code: 'pt',
    label: 'Portuguese',
    voskDirectoryName: 'vosk-model-small-pt-0.3',
    voskArchiveFileName: 'vosk-model-small-pt-0.3.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip',
    minimumArchiveBytes: 15000000,
  );

  static const russian = VoiceLanguage(
    code: 'ru',
    label: 'Russian',
    voskDirectoryName: 'vosk-model-small-ru-0.22',
    voskArchiveFileName: 'vosk-model-small-ru-0.22.zip',
    voskModelUrl: 'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip',
    minimumArchiveBytes: 20000000,
  );

  static const List<VoiceLanguage> values = [
    english,
    hindi,
    spanish,
    french,
    german,
    portuguese,
    russian,
  ];

  static VoiceLanguage fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return english;
  }
}
