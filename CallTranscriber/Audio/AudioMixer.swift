import Foundation
import AVFoundation
import CoreMedia

/// Converts CMSampleBuffers from ScreenCaptureKit into 16kHz mono Float32 arrays.
final class AudioMixer {
    static let targetSampleRate: Double = 16000
    static let targetChannels: AVAudioChannelCount = 1

    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?

    /// Convert a CMSampleBuffer to 16kHz mono Float32 PCM frames.
    /// Returns nil if conversion fails.
    func convert(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        let inputAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.pointee.mSampleRate,
            channels: asbd.pointee.mChannelsPerFrame,
            interleaved: false
        )

        guard let inputAudioFormat else { return nil }

        // Rebuild converter if format changed
        if inputFormat != inputAudioFormat || converter == nil {
            inputFormat = inputAudioFormat
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: AudioMixer.targetSampleRate,
                channels: AudioMixer.targetChannels,
                interleaved: false
            )!
            converter = AVAudioConverter(from: inputAudioFormat, to: outputFormat)
        }

        guard let converter else { return nil }

        // Wrap CMSampleBuffer into AVAudioPCMBuffer
        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputAudioFormat, frameCapacity: frameCount) else {
            return nil
        }
        inputBuffer.frameLength = frameCount

        // Copy audio data
        let ablPointer = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        for (i, buffer) in ablPointer.enumerated() {
            guard i < Int(inputAudioFormat.channelCount),
                  let dst = inputBuffer.floatChannelData?[i],
                  let src = buffer.mData else { continue }
            memcpy(dst, src, Int(buffer.mDataByteSize))
        }

        // Calculate output frame count
        let outputFrameCapacity = AVAudioFrameCount(
            ceil(Double(frameCount) * AudioMixer.targetSampleRate / inputAudioFormat.sampleRate)
        )
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return nil }

        var error: NSError?
        var inputProvided = false

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputProvided {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputProvided = true
            return inputBuffer
        }

        if error != nil { return nil }

        guard let channelData = outputBuffer.floatChannelData else { return nil }
        let count = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
}
