import Foundation

enum AppError: LocalizedError {
    // Permissions
    case microphonePermissionDenied
    case screenRecordingPermissionDenied

    // Audio capture
    case noAudioSources
    case captureStreamFailed(String)
    case audioConversionFailed

    // Transcription
    case modelNotFound
    case modelLoadFailed(String)
    case transcriptionFailed(String)
    case engineNotAvailable(String)

    // Diarization
    case diarizationFailed(String)

    // Network
    case missingAPIKey(String)
    case networkError(String)

    // Storage
    case fileWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Please grant permission in System Settings."
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission is required to capture system audio. Please grant permission in System Settings."
        case .noAudioSources:
            return "No audio sources found. Please ensure audio is playing on this Mac."
        case .captureStreamFailed(let msg):
            return "Audio capture failed: \(msg)"
        case .audioConversionFailed:
            return "Failed to convert audio to the required format."
        case .modelNotFound:
            return "Whisper model not found. Please run the download-models.sh script."
        case .modelLoadFailed(let msg):
            return "Failed to load transcription model: \(msg)"
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .engineNotAvailable(let name):
            return "\(name) transcription engine is not available."
        case .diarizationFailed(let msg):
            return "Speaker identification failed: \(msg)"
        case .missingAPIKey(let service):
            return "Missing API key for \(service). Please add it in Settings."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .fileWriteFailed(let msg):
            return "Failed to save file: \(msg)"
        }
    }
}
