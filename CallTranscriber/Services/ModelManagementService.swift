import Foundation

/// Manages bundled ML models — resolves paths for WhisperKit and FluidAudio models.
final class ModelManagementService {
    static let shared = ModelManagementService()

    private init() {}

    /// Returns the path to the bundled Whisper model directory.
    var whisperModelPath: String? {
        Bundle.module.path(forResource: "openai_whisper-small", ofType: nil, inDirectory: "Models")
    }

    /// Returns the path to bundled diarization models.
    var diarizationModelsPath: String? {
        Bundle.module.path(forResource: "diarization", ofType: nil, inDirectory: "Models")
    }

    var whisperModelURL: URL? {
        whisperModelPath.map { URL(fileURLWithPath: $0) }
    }

    var diarizationModelsURL: URL? {
        diarizationModelsPath.map { URL(fileURLWithPath: $0) }
    }

    /// Check whether bundled models exist (downloaded at build time by download-models.sh).
    var areModelsAvailable: Bool {
        whisperModelURL != nil && (try? FileManager.default.contentsOfDirectory(atPath: whisperModelURL!.path))?.isEmpty == false
    }
}
