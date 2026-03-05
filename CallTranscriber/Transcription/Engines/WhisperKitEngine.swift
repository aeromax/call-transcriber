import Foundation
import WhisperKit

actor WhisperKitEngine: TranscriptionEngine {
    nonisolated let name = "WhisperKit (Local)"
    nonisolated let supportsStreaming = true

    private var whisper: WhisperKit?
    private var _isLoaded = false
    var isLoaded: Bool { _isLoaded }

    private var isCancelled = false
    private let modelFolder: String?

    init(modelFolder: String? = nil) {
        self.modelFolder = modelFolder ?? ModelManagementService.shared.whisperModelPath
    }

    func load() async throws {
        guard !_isLoaded else { return }

        let config: WhisperKitConfig
        if let folder = modelFolder {
            config = WhisperKitConfig(modelFolder: folder)
        } else {
            config = WhisperKitConfig(model: "openai_whisper-small")
        }

        do {
            whisper = try await WhisperKit(config)
            _isLoaded = true
        } catch {
            throw AppError.modelLoadFailed(error.localizedDescription)
        }
    }

    func unload() async {
        whisper = nil
        _isLoaded = false
    }

    func transcribe(samples: [Float], sampleRate: Double) async throws -> TranscriptionResult {
        guard let whisper, _isLoaded else {
            throw AppError.engineNotAvailable(name)
        }

        isCancelled = false

        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: nil,
                temperature: 0,
                sampleLength: 224,
                usePrefillPrompt: true,
                skipSpecialTokens: true
            )

            let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)

            let allText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            let segments = results.flatMap { $0.segments }.map { seg in
                TranscriptionSegment(
                    text: seg.text,
                    startTime: TimeInterval(seg.start),
                    endTime: TimeInterval(seg.end),
                    confidence: 1.0
                )
            }

            return TranscriptionResult(text: allText, segments: segments, language: results.first?.language)
        } catch {
            if isCancelled { throw CancellationError() }
            throw AppError.transcriptionFailed(error.localizedDescription)
        }
    }

    func transcribeStream(samples: [Float], startTime: TimeInterval) async throws -> AsyncThrowingStream<StreamingTranscriptionChunk, Error> {
        guard let whisper, _isLoaded else {
            throw AppError.engineNotAvailable(name)
        }

        isCancelled = false

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let options = DecodingOptions(
                        task: .transcribe,
                        language: nil,
                        temperature: 0,
                        sampleLength: 224,
                        usePrefillPrompt: true,
                        skipSpecialTokens: true
                    )

                    let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)

                    for result in results {
                        for segment in result.segments {
                            if await self.checkCancelled() {
                                continuation.finish(throwing: CancellationError())
                                return
                            }
                            continuation.yield(StreamingTranscriptionChunk(
                                text: segment.text,
                                startTime: startTime + TimeInterval(segment.start),
                                endTime: startTime + TimeInterval(segment.end),
                                isFinal: true
                            ))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    nonisolated func cancel() {
        Task { await self.setCancelled(true) }
    }

    private func checkCancelled() -> Bool { isCancelled }
    private func setCancelled(_ value: Bool) { isCancelled = value }
}
