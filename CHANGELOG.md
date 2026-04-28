# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-04-28

### Added
- Initial public Android release of Lilly.
- On-device Gemma 4 E4B inference through LiteRT-LM.
- Voice conversation flow with speech-to-text and spoken replies.
- Image-aware chat using camera and gallery input.
- OCR fallback using ML Kit text recognition.
- Wake-word trigger support powered by Sherpa ONNX.
- Hugging Face authentication and gated model download flow.
- Local model lifecycle controls in the app settings.
- Android-native inference bridge for runtime model initialization and response generation.

### Changed
- Refined the app structure around controllers, services, and Android-native integration.
- Standardized the visible app version to `v1.0.0`.
- Improved in-app camera behavior to better preserve the assistant session during image capture.
- Expanded project documentation for release readiness.

### Fixed
- Release build failures caused by optional ML Kit OCR recognizer references during R8 shrinking.
- Voice reply interruptions during in-app image capture flow.
- Camera-related restarts caused by leaving the app for photo capture on memory-constrained devices.
- Setup and model-download edge cases affecting first-run stability.
