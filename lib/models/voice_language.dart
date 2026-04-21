class VoiceLanguage {
  const VoiceLanguage({
    required this.code,
    required this.label,
    required this.speechLocaleId,
  });

  final String code;
  final String label;
  final String speechLocaleId;

  static const english = VoiceLanguage(
    code: 'en',
    label: 'English',
    speechLocaleId: 'en_US',
  );

  static const hindi = VoiceLanguage(
    code: 'hi',
    label: 'Hindi',
    speechLocaleId: 'hi_IN',
  );

  static const spanish = VoiceLanguage(
    code: 'es',
    label: 'Spanish',
    speechLocaleId: 'es_ES',
  );

  static const french = VoiceLanguage(
    code: 'fr',
    label: 'French',
    speechLocaleId: 'fr_FR',
  );

  static const german = VoiceLanguage(
    code: 'de',
    label: 'German',
    speechLocaleId: 'de_DE',
  );

  static const portuguese = VoiceLanguage(
    code: 'pt',
    label: 'Portuguese',
    speechLocaleId: 'pt_PT',
  );

  static const russian = VoiceLanguage(
    code: 'ru',
    label: 'Russian',
    speechLocaleId: 'ru_RU',
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
