import Foundation

/// Thread-safe ring buffer for streaming Float32 audio samples.
final class AudioBufferRing: @unchecked Sendable {
    private let capacity: Int
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var count: Int = 0
    private let lock = NSLock()

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }

    /// Write samples into the ring buffer. Overwrites oldest data if full.
    func write(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }

        for sample in samples {
            buffer[writeIndex % capacity] = sample
            writeIndex = (writeIndex + 1) % capacity
            if count < capacity {
                count += 1
            } else {
                // Overwrite: advance read pointer too
                readIndex = (readIndex + 1) % capacity
            }
        }
    }

    /// Read up to `maxCount` samples. Returns fewer if not enough available.
    func read(maxCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let available = min(count, maxCount)
        guard available > 0 else { return [] }

        var result = [Float](repeating: 0, count: available)
        for i in 0..<available {
            result[i] = buffer[(readIndex + i) % capacity]
        }
        readIndex = (readIndex + available) % capacity
        count -= available
        return result
    }

    /// Peek at samples without consuming them.
    func peek(count peekCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }

        let available = min(count, peekCount)
        guard available > 0 else { return [] }

        var result = [Float](repeating: 0, count: available)
        for i in 0..<available {
            result[i] = buffer[(readIndex + i) % capacity]
        }
        return result
    }

    var availableCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        writeIndex = 0
        readIndex = 0
        count = 0
    }
}
