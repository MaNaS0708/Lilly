class VisualIntentService {
  static final RegExp _deicticPattern = RegExp(
    r"\b(this|that|these|those|here|there|it)\b",
  );

  static final RegExp _visualVerbPattern = RegExp(
    r"\b(see|look|identify|describe|read|scan|show|recognize|detect|check)\b",
  );

  static final RegExp _visualNounPattern = RegExp(
    r"\b(image|picture|photo|camera|sign|label|text|menu|board|screen|document|paper|note|book|receipt|package|object|thing|item|bottle|box)\b",
  );

  static final RegExp _nearMePattern = RegExp(
    r"\b(in front of me|around me|near me|ahead of me|on my screen|on this page)\b",
  );

  static final List<RegExp> _readPatterns = [
    RegExp(r"\bwhat does (this|that|it) say\b"),
    RegExp(r"\bwhat is written\b"),
    RegExp(r"\b(read|scan|ocr|transcribe|extract)\b"),
    RegExp(
      r"\b(text|label|sign|menu|board|screen|document|paper|note|book|receipt|package)\b",
    ),
  ];

  static final List<RegExp> _identifyPatterns = [
    RegExp(r"\bwhat('?s| is) (this|that|it)\b"),
    RegExp(r"\btell me what (this|that|it) is\b"),
    RegExp(r"\bidentify (this|that|it)\b"),
    RegExp(r"\bwhat am i (looking at|holding)\b"),
    RegExp(r"\bcan you see (this|that|it)\b"),
    RegExp(r"\bwhat do you see\b"),
  ];

  static final List<RegExp> _scenePatterns = [
    RegExp(r"\bwhat('?s| is) in front of me\b"),
    RegExp(r"\bwhat do you see in front of me\b"),
    RegExp(r"\bdescribe (this|that|it|the scene|what you see)\b"),
    RegExp(r"\blook at (this|that|it)\b"),
    RegExp(r"\b(in front of me|around me|near me|ahead of me)\b"),
  ];

  static bool shouldAutoCaptureForPrompt(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return false;

    if (asksToReadText(normalized) ||
        asksToIdentifyObject(normalized) ||
        asksToDescribeScene(normalized)) {
      return true;
    }

    final hasDeictic = _deicticPattern.hasMatch(normalized);
    final hasVisualVerb = _visualVerbPattern.hasMatch(normalized);
    final hasVisualNoun = _visualNounPattern.hasMatch(normalized);
    final hasNearMeCue = _nearMePattern.hasMatch(normalized);

    return (hasDeictic && (hasVisualVerb || hasVisualNoun)) ||
        (hasNearMeCue && (hasVisualVerb || hasVisualNoun));
  }

  static bool asksToReadText(String text) {
    final normalized = _normalize(text);
    return _readPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  static bool asksToIdentifyObject(String text) {
    final normalized = _normalize(text);
    return _identifyPatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  static bool asksToDescribeScene(String text) {
    final normalized = _normalize(text);
    return _scenePatterns.any((pattern) => pattern.hasMatch(normalized));
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']+"), ' ')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();
  }
}
