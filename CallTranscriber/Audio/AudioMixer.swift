import Foundation
import AVFoundation
import CoreMedia

/// Converts CMSampleBuffers from ScreenCaptureKit into 16kHz mono Float32 arrays.
actor AudioMixer {
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

        let sampleRate = asbd.pointee.mSampleRate
        let channelCount = asbd.pointee.mChannelsPerFrame
        guard sampleRate > 0, channelCount > 0, channelCount <= 64 else { return nil }

        let inputAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )

        guard let inputAudioFormat else { return nil }

        // Rebuild converter if format changed
        if inputFormat != inputAudioFormat || converter == nil {
            inputFormat = inputAudioFormat
            guard let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: AudioMixer.targetSampleRate,
                channels: AudioMixer.targetChannels,
                interleaved: false
            ) else { return nil }
            converter = AVAudioConverter(from: inputAudioFormat, to: outputFormat)
        }

        guard let converter else { return nil }

        // Wrap CMSampleBuffer into AVAudioPCMBuffer
        // AudioBufferList is variable-length; query the required size first.
        var blockBuffer: CMBlockBuffer?
        var bufferListSizeNeeded: Int = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &bufferListSizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: nil
        )
        guard bufferListSizeNeeded > 0 else { return nil }
        let ablData = UnsafeMutableRawPointer.allocate(byteCount: bufferListSizeNeeded, alignment: 16)
        defer { ablData.deallocate() }
        let audioBufferListPtr = ablData.bindMemory(to: AudioBufferList.self, capacity: 1)
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferListPtr,
            bufferListSize: bufferListSizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0 else { return nil }
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputAudioFormat, frameCapacity: frameCount) else {
            return nil
        }
        inputBuffer.frameLength = frameCount

        // Copy audio data
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferListPtr)
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
        guard outputFrameCapacity > 0 else { return nil }
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
        guard count > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
}
