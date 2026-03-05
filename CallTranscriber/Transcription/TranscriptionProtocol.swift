import Foundation

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

struct StreamingTranscriptionChunk {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFinal: Bool
}

/// Protocol implemented by all transcription backends.
/// Methods are async; conforming types may be actors or regular classes.
protocol TranscriptionEngine: AnyObject, Sendable {
    var name: String { get }
    var supportsStreaming: Bool { get }
    var isLoaded: Bool { get async }

    func load() async throws
    func unload() async

    /// Transcribe a full audio buffer (post-processing / cloud batch).
    func transcribe(samples: [Float], sampleRate: Double) async throws -> TranscriptionResult

    /// Stream transcription chunks as audio arrives. Default wraps batch transcription.
    func transcribeStream(samples: [Float], startTime: TimeInterval) async throws -> AsyncThrowingStream<StreamingTranscriptionChunk, Error>

    func cancel()
}

extension TranscriptionEngine {
    func transcribeStream(samples: [Float], startTime: TimeInterval) async throws -> AsyncThrowingStream<StreamingTranscriptionChunk, Error> {
        let result = try await transcribe(samples: samples, sampleRate: AudioMixer.targetSampleRate)
        return AsyncThrowingStream { continuation in
            for segment in result.segments {
                continuation.yield(StreamingTranscriptionChunk(
                    text: segment.text,
                    startTime: startTime + segment.startTime,
                    endTime: startTime + segment.endTime,
                    isFinal: true
                ))
            }
            continuation.finish()
        }
    }
}
