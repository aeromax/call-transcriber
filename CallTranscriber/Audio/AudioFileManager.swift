import Foundation
import AVFoundation

/// Writes 16kHz mono Float32 audio to a WAV file on disk.
final class AudioFileManager {
    private var audioFile: AVAudioFile?
    private let format: AVAudioFormat
    private(set) var fileURL: URL?

    init() throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioMixer.targetSampleRate,
            channels: AudioMixer.targetChannels,
            interleaved: false
        ) else {
            throw AppError.audioConversionFailed
        }
        self.format = format
    }

    func startNewFile() throws -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CallTranscriber", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let timestamp = DateFormatter.filenameFormatter.string(from: Date())
        let url = dir.appendingPathComponent("recording-\(timestamp).wav")

        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        fileURL = url
        return url
    }

    func append(samples: [Float]) throws {
        guard let audioFile else { return }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw AppError.audioConversionFailed
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)

        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { ptr in
                channelData[0].update(from: ptr.baseAddress!, count: samples.count)
            }
        }

        try audioFile.write(from: buffer)
    }

    func finalize() -> URL? {
        audioFile = nil
        return fileURL
    }
}

extension DateFormatter {
    static let filenameFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return df
    }()
}
