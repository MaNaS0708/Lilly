# Lilly

[![Version](https://img.shields.io/badge/version-v1.0.0-C88298)](https://github.com/MaNaS0708/Lilly/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![Model](https://img.shields.io/badge/model-Gemma%204%20E4B-F97316)](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm)
[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

**Lilly** is an Android-first, on-device voice assistant built with Flutter. It combines local **Gemma 4** inference through **LiteRT-LM**, wake-word detection with **Sherpa ONNX**, speech recognition, spoken replies, OCR-assisted vision, and image-aware chat into a private assistant experience that runs directly on the phone.

Lilly is designed around a simple idea: the assistant should feel local, responsive, and personal, without depending on cloud inference for core interaction.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Screenshots](#screenshots)
- [Architecture](#architecture)
- [Model Download](#model-download)
- [Supported Voice Languages](#supported-voice-languages)
- [How to Build APK](#how-to-build-apk)
- [Permissions Required](#permissions-required)
- [Platform Support](#platform-support)
- [Limitations](#limitations)
- [Roadmap](#roadmap)
- [Project Structure](#project-structure)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Lilly provides a local assistant workflow with these core capabilities:

- On-device Gemma 4 chat
- Voice conversation with speech-to-text and text-to-speech
- Image-aware prompting through camera and gallery input
- OCR fallback for visible text in images
- Wake-word support for hands-free launch
- Local model storage, validation, and lifecycle management

The current release is focused on **Android** and targets a reliable, privacy-oriented experience on supported devices with enough storage and memory for local model execution.

---

## Features

### On-device inference
Lilly runs **Gemma 4 E4B** locally through **LiteRT-LM**. Core assistant responses stay on the device.

### Voice-first interaction
Lilly can listen to speech, convert it to text, generate a local response, and speak the result back using the system TTS stack.

### Image-aware assistant flow
Users can attach an image from the gallery or capture one directly in-app and ask questions naturally.

### OCR fallback
When direct multimodal understanding is limited, Lilly uses **ML Kit OCR** to extract readable text from images and use it as context.

### Wake-word support
The Android trigger flow uses **Sherpa ONNX** for wake-word detection and integrates with Lilly’s voice-chat flow.

### Private local setup
The model is downloaded once, stored in app-private storage, and reused locally after validation.

### Local model controls
The app includes settings for checking model status, validating model presence, reloading the model, and deleting local model artifacts.

---

## Screenshots

| Home | Voice Chat |
|---|---|
| ![Lilly home screen](docs/screenshots/HomeScreen.jpg) | ![Lilly voice chat screen](docs/screenshots/VoiceChat.jpg) |

| Voice Mode Active | Processing |
|---|---|
| ![Lilly voice mode active](docs/screenshots/VoiceChatEnabled.jpg) | ![Lilly processing a request](docs/screenshots/QuestionProcessing.jpg) |

| Response | Settings |
|---|---|
| ![Lilly response example](docs/screenshots/ResponseQuestion2.jpg) | ![Lilly settings screen](docs/screenshots/Settings-1.jpg) |

---

## Architecture

### Core runtime
- **Flutter** for app UI and orchestration
- **LiteRT-LM** for Android-native Gemma 4 inference
- **Sherpa ONNX** for wake-word detection
- **speech_to_text** for speech recognition
- **flutter_tts** for spoken replies
- **camera** for in-app photo capture
- **google_mlkit_text_recognition** for OCR fallback

### High-level flow
1. Lilly checks whether a valid local model exists.
2. If not, the user completes setup and downloads the model.
3. The app initializes the native LiteRT-LM runtime.
4. User input reaches Lilly by text, voice, or image.
5. Lilly runs local inference and returns a response.
6. For voice mode, Lilly can speak the response back.

### Wake-word behavior
Lilly uses an Android foreground service for wake-word listening. When the wake phrase is detected, the app routes the user into the assistant flow using Android-safe notification behavior rather than unsupported background UI launches.

---

## Model Download

Lilly uses a gated Gemma 4 LiteRT-LM model hosted on Hugging Face.

### Current model
- **Model:** `gemma-4-E4B-it.litertlm`
- **Expected size:** `3,654,467,584` bytes
- **Minimum accepted size:** `3,600,000,000` bytes
- **Source:** [Gemma 4 E4B LiteRT-LM](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm)

### First-run setup
On a clean install, Lilly does the following:

1. Ask the user to choose a primary voice language
2. Check whether the local model is already present and valid
3. Authenticate with Hugging Face if model access requires it
4. Ask the user to accept the model license if needed
5. Download the model into app-private storage
6. Validate the downloaded file
7. Initialize the local runtime and enter the main chat flow

### Important notes
- The model is large, so first-time setup can take time
- A stable connection is recommended for first-run download
- The model stays on the device after download
- Deleting the model from Settings requires a fresh download later

---

## Supported Voice Languages

Lilly currently supports one active voice language at a time:

- English
- Hindi
- Spanish
- French
- German
- Portuguese
- Russian

---

## OCR Coverage

Lilly does not enable every OCR script by default.

### Currently prioritized
- Latin
- Devanagari

### Why this is intentional
OCR support is scoped to Lilly’s current product priorities so the app stays lighter and more focused. Additional script support can be added later when there is a clear use case.

---

## How to Build APK

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Generate launcher icons
```bash
dart run flutter_launcher_icons
```

### 3. Clean previous build artifacts
```bash
flutter clean
```

### 4. Build the release APK
```bash
flutter build apk --release
```

### 5. Optional: rename the generated APK
Flutter usually outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
```

If you want a cleaner release filename:

```bash
cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/lilly.apk
```

---

## Permissions Required

| Permission | Purpose |
|---|---|
| `CAMERA` | Capture photos for image-aware prompts |
| `READ_MEDIA_IMAGES` | Select images from the gallery |
| `READ_EXTERNAL_STORAGE` | Backward compatibility for older Android versions |
| `RECORD_AUDIO` | Voice chat and wake-word detection |
| `INTERNET` | Hugging Face authentication and model download |
| `FOREGROUND_SERVICE` | Keep the wake-word service active |
| `FOREGROUND_SERVICE_MICROPHONE` | Microphone use inside the foreground trigger service |
| `POST_NOTIFICATIONS` | Trigger notifications and foreground service visibility |
| `WAKE_LOCK` | Help maintain stability for long-running trigger behavior |
| `RECEIVE_BOOT_COMPLETED` | Restore trigger-related behavior after reboot |
| `USE_FULL_SCREEN_INTENT` | Important notification behavior for the trigger flow |

---

## Platform Support

### Android
Fully supported and actively implemented.

### iOS
Not wired yet.

This is not because Gemma 4 is impossible on iOS in theory. Lilly’s current native inference and trigger architecture is built specifically around Android:

- Android-native LiteRT-LM integration
- Android foreground services
- Android wake-word architecture
- Android-specific permission and runtime flows

---

## Limitations

Lilly is functional, but the current release has clear boundaries:

- Android is the primary supported platform
- Local model initialization can be slow on weaker devices
- Performance depends heavily on available RAM and backend compatibility
- The first-run model download is large and not lightweight
- OCR coverage is intentionally limited to selected scripts
- Wake-word reliability may vary across device vendors and Android behaviors
- iOS local inference is not implemented in this repository yet
- Multimodal quality and responsiveness depend strongly on device capability

---

## Roadmap

Planned directions for Lilly include:

- Faster warm-start model behavior
- Better streamed responses
- Cleaner release automation
- Broader OCR support where it makes product sense
- Improved wake-word reliability and diagnostics
- Stronger image reasoning flow
- Further Android stability work around long sessions and heavy memory use
- Investigation of an eventual iOS path once the native runtime story matures

---

## Project Structure

```text
lib/
├── config/
├── controllers/
├── models/
├── screens/
├── services/
├── widgets/
└── main.dart

android/app/src/main/kotlin/com/example/lilly/
├── MainActivity.kt
├── LillyTriggerService.kt
├── WakeWordDetector.kt
├── WakeWordModelManager.kt
├── WakeWordConstants.kt
└── TriggerRestartReceiver.kt
```

---

## Development

### Run locally
```bash
flutter run
```

### Analyze the project
```bash
flutter analyze
```

### Kotlin compile check on macOS
```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew app:compileDebugKotlin
```

---

## Contributing

Contributions, bug reports, device-test feedback, documentation improvements, and UX ideas are welcome.

Useful ways to contribute:

- Report bugs with clear reproduction steps
- Improve documentation and setup guidance
- Test Lilly on more Android devices
- Suggest UX improvements for voice, camera, and model lifecycle flows
- Help improve wake-word reliability and local-model stability

For larger changes, opening an issue first is recommended so the direction can be discussed before implementation.

---

## License

Lilly is released under the [MIT License](LICENSE).

---

## Repository

- **Homepage:** [github.com/MaNaS0708/Lilly](https://github.com/MaNaS0708/Lilly)
- **Repository:** [github.com/MaNaS0708/Lilly](https://github.com/MaNaS0708/Lilly)
- **Releases:** [github.com/MaNaS0708/Lilly/releases](https://github.com/MaNaS0708/Lilly/releases)
