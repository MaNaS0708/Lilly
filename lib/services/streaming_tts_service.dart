import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class _Segment {
  _Segment(this.text, this.start);

  final String text;
  final int start;
}

class StreamingTtsService {
  StreamingTtsService(this._tts) {
    _configure();
  }

  final FlutterTts _tts;
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  final List<_Segment> _pendingSegments = [];
  String _buffer = '';
  String _previousSegment = '';
  bool _isProcessing = false;
  bool _messageComplete = false;
  int _lastSpokenLength = 0;
  int _lastProgressEnd = 0;
  int _currentSegmentStart = 0;

  int _resumeAttempts = 0;
  bool _resumeScheduled = false;
  bool _suppressResumeOnCancel = false;

  static const int _maxResumeAttempts = 5;
  static const Duration _resumeDelay = Duration(seconds: 2);

  void _configure() {
    _tts.setStartHandler(() {
      _resumeScheduled = false;
      isSpeaking.value = true;
    });

    _tts.setProgressHandler((String text, int start, int end, String word) {
      _lastProgressEnd = _currentSegmentStart + end;
    });

    _tts.setCompletionHandler(() {
      _resumeAttempts = 0;
      if (_pendingSegments.isEmpty && _messageComplete) {
        isSpeaking.value = false;
      }
    });

    _tts.setCancelHandler(() {
      if (!_suppressResumeOnCancel) {
        _scheduleResume();
      }
    });

    _tts.setPauseHandler(() {
      if (!_suppressResumeOnCancel) {
        _scheduleResume();
      }
    });
  }

  void startMessage() {
    stop();
    _buffer = '';
    _messageComplete = false;
  }

  void addText(String fullText) {
    _buffer = fullText;
    unawaited(_processBuffer());
  }

  Future<void> completeMessage() async {
    _messageComplete = true;
    await _forceCompleteReading();
  }

  Future<void> stop() async {
    _pendingSegments.clear();
    _buffer = '';
    _previousSegment = '';
    _isProcessing = false;
    _messageComplete = false;
    _lastSpokenLength = 0;
    _lastProgressEnd = 0;
    _currentSegmentStart = 0;
    _resumeAttempts = 0;
    _resumeScheduled = false;
    _suppressResumeOnCancel = true;
    try {
      await _tts.stop();
    } catch (_) {
    } finally {
      _suppressResumeOnCancel = false;
      isSpeaking.value = false;
    }
  }

  Future<void> dispose() async {
    await stop();
    isSpeaking.dispose();
  }

  void _scheduleResume() {
    if (_resumeScheduled || _resumeAttempts >= _maxResumeAttempts) return;

    _resumeAttempts++;
    _resumeScheduled = true;

    final cleanBuffer = _cleanText(_buffer);
    var resumeFrom = _lastProgressEnd;
    if (resumeFrom <= 0 || resumeFrom < _lastSpokenLength - 5) {
      resumeFrom = _lastSpokenLength;
    }
    resumeFrom = resumeFrom.clamp(0, cleanBuffer.length);

    Future<void>.delayed(_resumeDelay, () async {
      _resumeScheduled = false;
      await _speak(from: resumeFrom);
    });
  }

  Future<void> _speak({int from = 0}) async {
    final cleanBuffer = _cleanText(_buffer);
    final text = from < cleanBuffer.length ? cleanBuffer.substring(from) : '';

    final shouldForceStop = from < _lastProgressEnd - 10;
    if (shouldForceStop) {
      _suppressResumeOnCancel = true;
      try {
        await _tts.stop();
      } catch (_) {}
      _suppressResumeOnCancel = false;
    }

    if (text.trim().isEmpty) return;

    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _processBuffer() async {
    final cleanText = _cleanText(_buffer);
    if (cleanText.isEmpty || _isProcessing) return;
    if (cleanText.length <= _lastSpokenLength) return;

    final newContent = cleanText.substring(_lastSpokenLength);
    final sentences = _findCompleteSentences(newContent);
    if (sentences.isEmpty) return;

    var offset = _lastSpokenLength;
    for (final sentence in sentences) {
      _pendingSegments.add(_Segment(sentence.trim(), offset));
      offset += sentence.length;
    }
    _lastSpokenLength = offset;

    if (!_isProcessing) {
      await _processNextSegment();
    }
  }

  Future<void> _processNextSegment() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_pendingSegments.isNotEmpty) {
      final segmentObj = _pendingSegments.removeAt(0);
      final segment = segmentObj.text.trim();
      _currentSegmentStart = segmentObj.start;

      if (segment.isEmpty || segment == _previousSegment) {
        continue;
      }

      try {
        isSpeaking.value = true;
        await _tts.speak(segment);
        _previousSegment = segment;
      } catch (_) {
        break;
      }
    }

    _isProcessing = false;

    if (_pendingSegments.isEmpty && _messageComplete) {
      await _forceCompleteReading();
    }
  }

  Future<void> _forceCompleteReading() async {
    final cleanBuffer = _cleanText(_buffer);
    if (cleanBuffer.trim().isEmpty) {
      isSpeaking.value = false;
      return;
    }

    final unspoken = cleanBuffer.length > _lastSpokenLength
        ? cleanBuffer.substring(_lastSpokenLength).trim()
        : '';

    if (unspoken.isNotEmpty) {
      _pendingSegments.add(_Segment(unspoken, _lastSpokenLength));
      _lastSpokenLength = cleanBuffer.length;
      if (!_isProcessing) {
        await _processNextSegment();
      }
    } else if (_pendingSegments.isEmpty) {
      isSpeaking.value = false;
    }
  }

  List<String> _findCompleteSentences(String text) {
    final out = <String>[];
    final matches = RegExp(r'[^.!?]+[.!?]+(?:\s+|$)').allMatches(text);

    var lastEnd = 0;
    for (final match in matches) {
      final sentence = match.group(0);
      if (sentence != null && sentence.trim().isNotEmpty) {
        out.add(sentence);
        lastEnd = match.end;
      }
    }

    if (_messageComplete && lastEnd < text.length) {
      final trailing = text.substring(lastEnd);
      if (trailing.trim().isNotEmpty) {
        out.add(trailing);
      }
    }

    return out;
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[_*`#>-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
