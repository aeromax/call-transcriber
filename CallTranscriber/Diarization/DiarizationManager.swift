import Foundation
import FluidAudio

struct DiarizationSegment {
    let speakerId: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

/// Coordinates streaming (real-time) and offline (post-processing) diarization via FluidAudio.
actor DiarizationManager {
    private var streamingDiarizer: DiarizerManager?
    private var isStreamingActive = false
    private let modelsDirectory: URL?

    init(modelsDirectory: URL? = nil) {
        self.modelsDirectory = modelsDirectory ?? ModelManagementService.shared.diarizationModelsURL
    }

    // MARK: - Streaming Diarization

    func startStreaming() async {
        guard !isStreamingActive else { return }
        do {
            let config = DiarizerConfig()
            let diarizer = DiarizerManager(config: config)
            let models = try await DiarizerModels.load(from: modelsDirectory, configuration: nil)
            diarizer.initialize(models: models)
            streamingDiarizer = diarizer
            isStreamingActive = true
        } catch {
            // Diarization is optional — log but don't propagate
            print("Streaming diarization unavailable: \(error). Speaker labels will be generic.")
        }
    }

    /// Returns speaker segments for the given audio chunk, or empty if unavailable.
    func processSamplesForStreaming(samples: [Float], timestamp: TimeInterval) async -> [DiarizationSegment] {
        guard let diarizer = streamingDiarizer, isStreamingActive else { return [] }
        do {
            let result = try diarizer.performCompleteDiarization(samples, sampleRate: 16000, atTime: timestamp)
            return result.segments.map { segment in
                DiarizationSegment(
                    speakerId: segment.speakerId,
                    startTime: TimeInterval(segment.startTimeSeconds),
                    endTime: TimeInterval(segment.endTimeSeconds)
                )
            }
        } catch {
            return []
        }
    }

    func stopStreaming() async {
        streamingDiarizer = nil
        isStreamingActive = false
    }

    // MARK: - Offline Diarization

    /// Runs full offline diarization on a WAV file. Returns globally-consistent speaker segments.
    func diarizeOffline(audioURL: URL) async throws -> [DiarizationSegment] {
        let config = OfflineDiarizerConfig.default
        let diarizer = OfflineDiarizerManager(config: config)
        try await diarizer.prepareModels(directory: modelsDirectory, configuration: nil)
        let result = try await diarizer.process(audioURL)

        return result.segments.map { segment in
            DiarizationSegment(
                speakerId: segment.speakerId,
                startTime: TimeInterval(segment.startTimeSeconds),
                endTime: TimeInterval(segment.endTimeSeconds)
            )
        }
    }
}
