import Foundation
import AVFoundation

/// Runs offline diarization + per-segment re-transcription after a recording completes.
actor PostProcessingPipeline {
    private let engine: any TranscriptionEngine
    private let diarizationManager: DiarizationManager

    init(engine: any TranscriptionEngine, diarizationManager: DiarizationManager) {
        self.engine = engine
        self.diarizationManager = diarizationManager
    }

    /// Process a completed recording. Returns merged segments with globally-consistent speaker IDs.
    func process(audioURL: URL) async throws -> [LiveSegment] {
        // 1. Offline diarization — globally consistent speaker IDs
        let diarSegments = try await diarizationManager.diarizeOffline(audioURL: audioURL)

        // 2. Load the full audio file
        let allSamples = try loadWAVSamples(from: audioURL)
        let sampleRate = AudioMixer.targetSampleRate

        // 3. Transcribe each diarization segment independently
        var results: [LiveSegment] = []

        for diarSegment in diarSegments {
            let startSample = Int(diarSegment.startTime * sampleRate)
            let endSample = min(Int(diarSegment.endTime * sampleRate), allSamples.count)
            guard endSample > startSample else { continue }

            let segmentSamples = Array(allSamples[startSample..<endSample])

            do {
                let transcription = try await engine.transcribe(samples: segmentSamples, sampleRate: sampleRate)
                let segment = LiveSegment(
                    speakerLabel: diarSegment.speakerId,
                    text: transcription.text,
                    startTime: diarSegment.startTime,
                    endTime: diarSegment.endTime,
                    isProvisional: false
                )
                results.append(segment)
            } catch {
                // If a segment fails, include it with empty text rather than dropping
                results.append(LiveSegment(
                    speakerLabel: diarSegment.speakerId,
                    text: "[transcription failed]",
                    startTime: diarSegment.startTime,
                    endTime: diarSegment.endTime,
                    isProvisional: false
                ))
            }
        }

        return results.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Private

    private func loadWAVSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioMixer.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AppError.audioConversionFailed
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AppError.audioConversionFailed
        }

        // If the file format differs, we need a converter
        if file.fileFormat.sampleRate != AudioMixer.targetSampleRate || file.fileFormat.channelCount != 1 {
            guard let converter = AVAudioConverter(from: file.fileFormat, to: format) else {
                throw AppError.audioConversionFailed
            }

            var error: NSError?
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.fileFormat, frameCapacity: frameCount)!
            try file.read(into: inputBuffer)

            var inputConsumed = false
            converter.convert(to: buffer, error: &error) { _, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                outStatus.pointee = .haveData
                inputConsumed = true
                return inputBuffer
            }

            if let error { throw error }
        } else {
            try file.read(into: buffer)
        }

        guard let channelData = buffer.floatChannelData else { throw AppError.audioConversionFailed }
        return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
    }
}
