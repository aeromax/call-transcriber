import Foundation

/// Coordinates real-time audio → transcription → diarization → UI.
@MainActor
final class RealTimePipeline: ObservableObject {
    private let engine: any TranscriptionEngine
    private let diarizationManager: DiarizationManager
    private let chunkScheduler: ChunkScheduler

    var onNewSegment: ((LiveSegment) -> Void)?

    private var recordingStartTime: Date = Date()
    private var activeTasks: [Task<Void, Never>] = []

    init(engine: any TranscriptionEngine, diarizationManager: DiarizationManager) {
        self.engine = engine
        self.diarizationManager = diarizationManager
        self.chunkScheduler = ChunkScheduler()
    }

    func start(startTime: Date) async throws {
        recordingStartTime = startTime
        try await diarizationManager.startStreaming()

        chunkScheduler.onChunkReady = { [weak self] samples, chunkStart in
            Task { @MainActor [weak self] in
                await self?.processChunk(samples: samples, chunkStart: chunkStart)
            }
        }
    }

    func feed(samples: [Float]) {
        Task { @MainActor in
            chunkScheduler.append(samples: samples)
        }
    }

    func stop() async {
        chunkScheduler.flush()
        await diarizationManager.stopStreaming()
        // Cancel all in-flight tasks
        for task in activeTasks { task.cancel() }
        activeTasks = []
    }

    // MARK: - Private

    private func processChunk(samples: [Float], chunkStart: TimeInterval) async {
        // Diarize in parallel with transcription
        async let diarizationResult = diarizationManager.processSamplesForStreaming(
            samples: samples, timestamp: chunkStart
        )
        async let transcriptionStream = tryTranscribe(samples: samples, chunkStart: chunkStart)

        let speakerLabel: String
        let diarSegments = await diarizationResult
        speakerLabel = diarSegments.first?.speakerId ?? "Speaker"

        do {
            for try await chunk in await transcriptionStream {
                let segment = LiveSegment(
                    speakerLabel: speakerLabel,
                    text: chunk.text,
                    startTime: chunk.startTime,
                    endTime: chunk.endTime,
                    isProvisional: true
                )
                onNewSegment?(segment)
            }
        } catch {
            // Transcription errors during streaming are non-fatal
            print("Chunk transcription error: \(error)")
        }
    }

    private func tryTranscribe(samples: [Float], chunkStart: TimeInterval) async -> AsyncThrowingStream<StreamingTranscriptionChunk, Error> {
        do {
            return try await engine.transcribeStream(samples: samples, startTime: chunkStart)
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
    }
}
