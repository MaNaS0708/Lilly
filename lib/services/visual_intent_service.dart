class VisualIntentService {
  static final RegExp _deicticPattern = RegExp(
    r"\b(this|that|these|those|here|there|it|this one|that one)\b",
  );

  static final RegExp _visualVerbPattern = RegExp(
    r"\b(see|seeing|look|looking|identify|describe|read|scan|show|recognize|detect|check|visible|watch|notice)\b",
  );

  static final RegExp _visualNounPattern = RegExp(
    r"\b(image|picture|photo|camera|scene|view|surroundings|sign|label|text|menu|board|screen|document|paper|note|book|receipt|package|packet|object|thing|item|bottle|box|can|refill|product|brand|room|place)\b",
  );

  static final RegExp _nearMePattern = RegExp(
    r"\b(in front of me|around me|near me|ahead of me|beside me|next to me|on my screen|on this page|in my hand|i am holding)\b",
  );

  static final List<RegExp> _readPatterns = [
    RegExp(r"\bwhat does (this|that|it|the label|the sign|the text) say\b"),
    RegExp(r"\bwhat is written\b"),
    RegExp(
      r"\b(read|scan|ocr|transcribe|extract) (this|that|it|the text|the label|the sign|the document|the screen)?\b",
    ),
    RegExp(
      r"\b(read|scan|tell me) .* (text|label|sign|menu|receipt|document|expiry|price|ingredients)\b",
    ),
    RegExp(
      r"\b(expiry|price|ingredients|address|phone number|date|menu|instructions)\b",
    ),
  ];

  static final List<RegExp> _identifyPatterns = [
    RegExp(r"\bwhat('?s| is) (this|that|it|this one|that one)\b"),
    RegExp(r"\btell me what (this|that|it|this one|that one) is\b"),
    RegExp(
      r"\bidentify (this|that|it|this one|that one|the object|the product)\b",
    ),
    RegExp(r"\bwhat am i (looking at|holding)\b"),
    RegExp(r"\bwhat product is this\b"),
    RegExp(r"\bwhich brand is this\b"),
    RegExp(r"\bcan you identify\b"),
    RegExp(r"\bye kya hai\b"),
    RegExp(r"\bkya hai ye\b"),
  ];

  static final List<RegExp> _scenePatterns = [
    RegExp(r"\bwhat can you see\b"),
    RegExp(r"\bwhat do you see\b"),
    RegExp(r"\bwhat are you seeing\b"),
    RegExp(r"\btell me what you see\b"),
    RegExp(r"\bwhat is visible\b"),
    RegExp(r"\bwhat('?s| is) visible\b"),
    RegExp(
      r"\bwhat('?s| is) in (this|the) (image|picture|photo|camera|scene|view)\b",
    ),
    RegExp(r"\bwhat('?s| is) in front of me\b"),
    RegExp(
      r"\bdescribe (this|that|it|the image|the picture|the photo|the scene|what you see)\b",
    ),
    RegExp(r"\blook at (this|that|it|the image|the camera)\b"),
    RegExp(
      r"\b(in front of me|around me|near me|ahead of me|beside me|next to me)\b",
    ),
    RegExp(r"\bkya dikh raha\b"),
    RegExp(r"\bkya dikh rha\b"),
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

    return (hasVisualVerb && hasVisualNoun) ||
        (hasDeictic && (hasVisualVerb || hasVisualNoun)) ||
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
