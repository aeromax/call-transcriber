# Call Transcriber

A native macOS app that captures audio from conference apps (Teams, Zoom, Meet), transcribes it locally using WhisperKit + CoreML, and identifies speakers with FluidAudio diarization.

## Requirements

- macOS 14.0+
- Apple Silicon (M1 or later) recommended for real-time performance
- Xcode 15+ or Swift 5.10+

## Quick Start

```bash
# 1. Download ML models (~500MB)
./Scripts/download-models.sh

# 2. Build and run
swift run
# or open in Xcode:
open Package.swift
```

## First Launch

On first launch, you'll be prompted to grant two permissions:

1. **Microphone** — captures your voice
2. **Screen Recording** — required by macOS to capture system audio from conference apps (no screen content is recorded)

## Architecture

| Layer | Technology |
|-------|-----------|
| Audio capture | ScreenCaptureKit (system audio + mic) |
| Local transcription | WhisperKit (openai_whisper-small, CoreML) |
| Speaker diarization | FluidAudio (VAD + pyannote + WeSpeaker) |
| Persistence | SwiftData |
| API keys | Keychain |

### Dual Pipeline

- **Real-time** — 10s chunks with 2s overlap → WhisperKit + FluidAudio streaming → live transcript (provisional speaker labels)
- **Post-processing** — after recording stops, runs offline diarization for globally-consistent speaker IDs, then re-transcribes per segment

## Cloud Backends

In **Settings → API Keys**, add:
- **OpenAI API key** — for Whisper API transcription
- **Deepgram API key** — for Deepgram Nova-2 transcription

Switch the active engine in the recording controls or Settings → General.

## Export Formats

From a recording's detail view: **SRT**, **VTT**, **JSON**, **Plain Text**

## Distribution

```bash
# Build release
swift build -c release

# Notarize (requires Developer ID cert + notarytool profile configured)
./Scripts/notarize.sh \
  --app .build/release/CallTranscriber.app \
  --team-id YOUR_TEAM_ID

# Create DMG
./Scripts/create-dmg.sh \
  --app .build/release/CallTranscriber.app \
  --version 1.0.0
```

## Project Structure

```
CallTranscriber/
├── App/            # Entry point, AppState
├── Audio/          # ScreenCaptureKit, AudioMixer, ring buffer, WAV writer
├── Transcription/  # TranscriptionEngine protocol + WhisperKit/OpenAI/Deepgram engines
├── Diarization/    # FluidAudio streaming + offline diarization
├── Pipeline/       # RealTimePipeline, PostProcessingPipeline, RecordingSession, ChunkScheduler
├── Models/         # SwiftData models (Recording, Transcript, Speaker)
├── Persistence/    # ModelContainer setup
├── Export/         # SRT, VTT, JSON, plain text exporters
├── Views/          # SwiftUI views
└── Services/       # PermissionService, KeychainService, ModelManagement, AppError
Scripts/
├── download-models.sh   # Pre-download ML models
├── notarize.sh          # Code sign + notarize
└── create-dmg.sh        # Package DMG
```
