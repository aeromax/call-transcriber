import Foundation

/// Buffers audio samples and emits fixed-size chunks with configurable overlap.
final class ChunkScheduler: @unchecked Sendable {
    let chunkDuration: TimeInterval    // e.g. 10 seconds
    let overlapDuration: TimeInterval  // e.g. 2 seconds
    let sampleRate: Double

    private var buffer: [Float] = []
    private let lock = NSLock()

    var onChunkReady: ((_ samples: [Float], _ startTime: TimeInterval) -> Void)?

    private var totalSamplesReceived: Int = 0
    private let chunkSamples: Int
    private let overlapSamples: Int

    init(chunkDuration: TimeInterval = 10, overlapDuration: TimeInterval = 2, sampleRate: Double = AudioMixer.targetSampleRate) {
        self.chunkDuration = chunkDuration
        self.overlapDuration = overlapDuration
        self.sampleRate = sampleRate
        self.chunkSamples = Int(chunkDuration * sampleRate)
        self.overlapSamples = Int(overlapDuration * sampleRate)
    }

    func append(samples: [Float]) {
        lock.lock()
        buffer.append(contentsOf: samples)
        totalSamplesReceived += samples.count

        while buffer.count >= chunkSamples {
            let chunk = Array(buffer.prefix(chunkSamples))
            let startTime = TimeInterval(max(0, totalSamplesReceived - buffer.count)) / sampleRate

            // Advance buffer by (chunk - overlap)
            let advance = chunkSamples - overlapSamples
            buffer.removeFirst(min(advance, buffer.count))

            lock.unlock()
            onChunkReady?(chunk, startTime)
            lock.lock()
        }
        lock.unlock()
    }

    func flush() {
        lock.lock()
        guard buffer.count > 0 else {
            lock.unlock()
            return
        }
        let remaining = buffer
        let startTime = TimeInterval(max(0, totalSamplesReceived - buffer.count)) / sampleRate
        buffer = []
        lock.unlock()

        if remaining.count > 100 { // Minimum meaningful chunk
            onChunkReady?(remaining, startTime)
        }
    }

    func reset() {
        lock.lock()
        buffer = []
        totalSamplesReceived = 0
        lock.unlock()
    }
}
