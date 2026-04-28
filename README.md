# Lilly

> An Android voice assistant powered entirely on-device — no cloud, no accounts, no data leaving your phone.

Lilly combines local **Gemma 4 E4B** inference via **LiteRT-LM**, speech recognition, image understanding, and a background wake-word service into a single, privacy-first assistant experience.

---

## Features

### Voice Chat
Lilly listens through the microphone, sends recognized speech into the local Gemma model, and speaks replies back using TTS — keeping a continuous voice conversation loop without any network dependency.

### Image-Aware Chat
Attach an image from the camera or gallery and ask about it naturally. Lilly routes the image through the multimodal model path and falls back to on-device OCR when native image inference isn't sufficient. Prompts like *"what is this"*, *"read this"*, or *"what's in front of me"* automatically trigger camera capture.

### Wake-Word Trigger
A persistent Android foreground service listens for a wake phrase in the background. When detected, Lilly posts a notification — tapping it opens Lilly directly into voice chat. While voice chat is active, wake-word listening pauses automatically and resumes once the session ends.

> **Why a notification instead of opening the app directly?**
> Android 10+ (API 29+) restricts all third-party apps from launching UI from the background. The notification tap is the only Android-approved path.

### On-Device Model
The Gemma 4 E4B model runs entirely on the device via the LiteRT-LM Kotlin SDK. No inference leaves the phone. The model is downloaded once on first launch over Wi-Fi and stored in private app storage.

---

## Platform

> **Lilly is Android-only.**

The app uses the LiteRT-LM Kotlin native SDK, Android foreground services, `AudioRecord`, and Android-specific permission APIs — none of which have a working Flutter bridge on iOS.

> The Gemma 4 E4B `.litertlm` model format is cross-platform, but Lilly's native integration layer targets Android only.
> → Model page: [litert-community/gemma-4-E4B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm)

---

## iOS Support

Lilly does not currently run on iOS. This is not because Gemma 4 is inherently
incompatible with Apple hardware — the official LiteRT-LM model cards list iOS
as a supported target — but because Lilly's native inference layer has only been
built for Android so far.

Concretely, three things are missing on the iOS side:

**No Swift / iOS LiteRT-LM bridge.**
`android/app/build.gradle.kts` pulls in the Android LiteRT-LM Kotlin dependency
and `MainActivity.kt` handles all model initialization and inference through it.
The iOS equivalent — a Swift method-channel implementation backed by the
LiteRT-LM iOS runtime — does not exist in this repo yet. The current
`ios/Runner/AppDelegate.swift` returns an explicit "Android-first / iOS not
wired" error for any model channel call.

**The iOS LiteRT-LM integration path is still maturing.**
The public LiteRT-LM repository describes Swift support as in development, and
community reports indicate that the Gemma 4 iOS runtime is meaningfully less
tested and documented than the Android path. `ios/Podfile` contains no
LiteRT-LM pod entry because there is no stable, documented pod to reference yet.

**Wake-word and background trigger are Android-specific.**
The foreground service, `AudioRecord`-based keyword detector, and boot receiver
that power Lilly's background wake-word feature rely on Android APIs with no
direct iOS equivalent. Replicating this on iOS would require a separate
approach — likely involving a different background audio strategy — and has not
been scoped or started.

iOS will become viable for the core chat features once the LiteRT-LM Swift
integration stabilises and a matching method-channel bridge is added to this
repo. The background trigger feature may remain Android-only longer given the
platform differences.

---

## Tech Stack

**Flutter / Dart**
| Package | Purpose |
|---|---|
| `speech_to_text` | On-device speech recognition |
| `flutter_tts` | Text-to-speech replies |
| `camera` + `image_picker` | Image capture flows |
| `google_mlkit_text_recognition` | OCR fallback |
| `flutter_web_auth_2` | Hugging Face OAuth |
| `http` + `path_provider` + `permission_handler` + `shared_preferences` + `url_launcher` | Core utilities |

**Android Native (Kotlin)**
| Component | Purpose |
|---|---|
| LiteRT-LM Android runtime | Local Gemma 4 inference |
| Android Foreground Service APIs | Persistent wake-word listener |
| Sherpa ONNX components | Keyword spotting |
| `AudioRecord` | Raw microphone input for wake-word detection |

---

## How It Works

### First-Run Setup

```
1. Choose a primary voice language
2. Check whether the Gemma model is already present and valid
3. Authenticate with Hugging Face (if needed)
4. Accept the Gemma model license on the model page (if not yet done)
5. Download the model directly into app storage (streamed, with progress)
6. Validate the downloaded file against the expected size
7. Enter the main chat screen and initialize the LiteRT-LM runtime
```

> Partial downloads are stored with a `.partial` suffix and cleaned up on cancellation.

---

### Runtime Model Flow

```
ChatScreen → ModelController → NativeModelService
    → Android method channel (lilly/model)
        → MainActivity.kt → LiteRT-LM engine
            → response returned to Flutter
```

---

### Wake-Word Flow

```
User enables trigger in Settings
    → Foreground service starts (persistent notification shown)
        → Wake-word model downloaded if missing
            → WakeWordDetector listens via AudioRecord
                → Keyword detected → notification posted
                    → User taps notification → Lilly opens into voice chat
                        → Wake-word listener pauses
                            → Voice chat ends → listener resumes
```

---

### Voice Chat Flow

```
User enters voice mode
    → Speech recognition starts
        → Recognized text written to input
            → Visual intent detected?
                YES → camera capture triggered
                NO  → text sent to local model → Lilly speaks response
                        → Voice loop resumes
```

---

### Image Understanding Flow

```
Image attached or captured
    → Native multimodal inference attempted
        → Success → response returned
        → Failure → ML Kit OCR fallback
            → OCR text used as context for model prompt
```

---

## Model

| Property | Value |
|---|---|
| Model | `gemma-4-E4B-it.litertlm` |
| Source | [litert-community/gemma-4-E4B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm) |
| Expected size | `3,654,467,584` bytes (~3.4 GB) |
| Minimum accepted size | `3,600,000,000` bytes |
| Runtime | LiteRT-LM Kotlin SDK |

Model constants → `lib/config/model_setup_constants.dart`

> **Note:** The model is **gated** — a Hugging Face account with license acceptance is required before download.

---

## Supported Voice Languages

> One language active at a time

`English` · `Hindi` · `Spanish` · `French` · `German` · `Portuguese` · `Russian`

Language definitions → `lib/models/voice_language.dart`

---

## Permissions

| Permission | Purpose |
|---|---|
| `CAMERA` | Image capture flows |
| `RECORD_AUDIO` | Voice chat and wake-word detection |
| `INTERNET` | Model download, Hugging Face auth |
| `READ_MEDIA_IMAGES` | Gallery image selection |
| `FOREGROUND_SERVICE` | Persistent wake-word service |
| `FOREGROUND_SERVICE_MICROPHONE` | Microphone use inside foreground service |
| `POST_NOTIFICATIONS` | Wake-word detection notification |
| `WAKE_LOCK` | Keep service alive during detection |
| `RECEIVE_BOOT_COMPLETED` | Restart trigger service after reboot |
| `USE_FULL_SCREEN_INTENT` | Wake notification full-screen intent |

---

## Project Structure

```
lib/
├── main.dart                            # Entry point, theme, routes
├── config/
│   └── model_setup_constants.dart       # Model filename, size thresholds
├── models/
│   └── voice_language.dart              # Supported language definitions
├── screens/
│   ├── splash_screen.dart               # First-run setup UI
│   ├── chat_screen.dart                 # Main conversation screen
│   ├── settings_screen.dart             # Model controls, voice settings, debug info
│   └── auto_capture_camera_screen.dart  # Auto-capture flow for image prompts
├── controllers/
│   ├── model_setup_controller.dart      # First-run setup state machine
│   ├── model_controller.dart            # Runtime model lifecycle
│   ├── chat_controller.dart             # Message handling, image routing, OCR fallback
│   └── conversation_list_controller.dart# Local conversation management
└── services/
    ├── native_model_service.dart        # Flutter → Android method channel bridge
    ├── model_download_manager.dart      # Streaming HTTP download manager
    ├── model_file_service.dart          # Model storage, validation, cleanup
    ├── model_download_service.dart      # Hugging Face URL access check
    ├── hf_auth_service.dart             # Hugging Face OAuth flow
    ├── voice_service.dart               # STT + TTS orchestration
    ├── trigger_service.dart             # Flutter-side wake-word trigger API
    ├── text_recognition_service.dart    # ML Kit OCR
    └── visual_intent_service.dart       # Detects prompts that imply camera capture

android/app/src/main/kotlin/com/example/lilly/
├── MainActivity.kt                      # LiteRT-LM init, backend selection, inference
├── LillyTriggerService.kt               # Foreground wake-word service
├── WakeWordDetector.kt                  # Keyword spotting loop
├── WakeWordModelManager.kt              # Wake-word model download + extraction
└── TriggerRestartReceiver.kt            # Restart trigger on boot / package replace
```

> **Note:** A few older files (`local_ai_service.dart`, `local_model_service.dart`, `streaming_tts_service.dart`, `chat_storage_service.dart`, `ai_response.dart`) remain in the repo as historical references and are not part of the active flow.

---

## Development Setup

### Requirements

- Flutter SDK (`^3.11.4`)
- Android Studio with Android SDK
- Physical Android device (emulators cannot run the Gemma model reliably)
- ~3.5 GB free device storage for model download
- Hugging Face account with Gemma model license accepted

### Install dependencies
```bash
flutter pub get
```

### Run the app
```bash
flutter run
```

### Static analysis
```bash
flutter analyze
```

### Kotlin compile check
If Gradle or Kotlin gives Java version errors on macOS, use Android Studio's bundled JBR:
```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew app:compileDebugKotlin
```

---

## Device Notes

- Newer Android devices with more RAM initialize the model significantly faster
- Tensor (Pixel) devices may use a different LiteRT-LM backend path than generic Android phones
- Free RAM and backend compatibility directly affect model initialization time
- The model performs best when it stays warm — avoid force-stopping the app between sessions

---

## Troubleshooting

<details>
<summary><b>Model missing or invalid</b></summary>

1. Open Settings → delete the local model
2. Restart the app and re-run setup
3. Verify the downloaded file reaches the expected size

</details>

<details>
<summary><b>Model downloads but does not initialize</b></summary>

- Check available device RAM
- Reopen the app and try again
- Verify the model file is complete (check Settings for file size)
- Review the native backend error shown in the Settings screen

</details>

<details>
<summary><b>Wake word is unreliable</b></summary>

- Confirm microphone permission is granted
- Confirm trigger autostart is enabled in Settings
- Disable battery optimization for Lilly in Android system settings — aggressive doze can kill the service
- Verify Lilly is not already in a paused voice-chat state
- Check trigger status in Settings

</details>

<details>
<summary><b>Camera / image prompts not working</b></summary>

- Confirm camera permission is granted
- Enable image input in Settings if disabled
- Use a clear, well-lit image
- If the model cannot answer visually, Lilly falls back to OCR-only reasoning

</details>

<details>
<summary><b>Voice replies not playing</b></summary>

- Confirm TTS is working on the device (test in Android TTS settings)
- Confirm Lilly is still in voice conversation mode
- Check whether the camera flow interrupted the voice loop — reopen voice chat if needed

</details>

---

## Known Limitations

- The local model is large and can be slow to initialize on lower-end devices
- Backend behavior varies by device — Tensor devices may behave differently
- Wake-word reliability depends on Android battery policy, background microphone availability, and model sensitivity
- Only one voice language is active at a time
- Image understanding may fall back to OCR when native multimodal inference is insufficient

---

## Roadmap

- [ ] Streamed token-by-token visible replies
- [ ] More aggressive warm-start model strategy
- [ ] Stronger multimodal prompt routing
- [ ] Richer voice behavior settings
- [ ] Cleanup of unused legacy service files

---

## Model Access

Lilly ships without the model — it is downloaded on first launch over Wi-Fi.

**Requirements:**
- A Hugging Face account
- Gemma model license accepted → [model page](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm)