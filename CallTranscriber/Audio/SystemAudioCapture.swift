import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

protocol AudioCaptureDelegate: AnyObject, Sendable {
    func audioCapture(didReceiveSamples samples: [Float], timestamp: TimeInterval)
    func audioCapture(didUpdateSystemLevel level: Float)
    func audioCapture(didUpdateMicLevel level: Float)
    func audioCapture(didFailWithError error: Error)
}

/// Captures system audio (and optionally microphone) via ScreenCaptureKit.
/// Acts as an actor for thread-safe state management.
actor SystemAudioCapture: NSObject {
    private var stream: SCStream?
    private var filter: SCContentFilter?
    private let mixer = AudioMixer()
    private weak var delegate: (any AudioCaptureDelegate)?

    // Microphone via AVCaptureSession (separate from SCStream)
    private var micCaptureSession: AVCaptureSession?
    private var micAudioOutput: AVCaptureAudioDataOutput?
    private let micMixer = AudioMixer()

    private var isCapturing = false

    func setDelegate(_ delegate: any AudioCaptureDelegate) {
        self.delegate = delegate
    }

    // MARK: - Start

    func startCapture() async throws {
        guard !isCapturing else { return }

        // Get shareable content — we want system audio from the entire display
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

        guard let display = content.displays.first else {
            throw AppError.noAudioSources
        }

        // Filter: capture the entire display (system audio) - no window exclusions needed for audio-only
        filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = Int(AudioMixer.targetSampleRate)
        config.channelCount = Int(AudioMixer.targetChannels)
        // Minimize video overhead - we only want audio
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 fps minimum
        config.width = 2
        config.height = 2

        let captureFilter = filter!
        stream = SCStream(filter: captureFilter, configuration: config, delegate: self)

        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
        try await stream?.startCapture()

        // Also start microphone capture
        try startMicrophoneCapture()

        isCapturing = true
    }

    func stopCapture() async {
        guard isCapturing else { return }
        try? await stream?.stopCapture()
        stream = nil
        stopMicrophoneCapture()
        isCapturing = false
    }

    // MARK: - Microphone

    private func startMicrophoneCapture() throws {
        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let micDevice = AVCaptureDevice.default(for: .audio),
              let micInput = try? AVCaptureDeviceInput(device: micDevice) else {
            // Microphone unavailable — non-fatal, continue with system audio only
            return
        }

        if session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        let output = AVCaptureAudioDataOutput()
        let queue = DispatchQueue(label: "com.callTranscriber.mic", qos: .userInteractive)
        output.setSampleBufferDelegate(self, queue: queue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
        session.startRunning()

        micCaptureSession = session
        micAudioOutput = output
    }

    private func stopMicrophoneCapture() {
        micCaptureSession?.stopRunning()
        micCaptureSession = nil
        micAudioOutput = nil
    }
}

// MARK: - SCStreamDelegate

extension SystemAudioCapture: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { await self.handleError(error) }
    }

    private func handleError(_ error: Error) {
        delegate?.audioCapture(didFailWithError: error)
    }
}

// MARK: - SCStreamOutput (system audio)

extension SystemAudioCapture: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard CMSampleBufferIsValid(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        Task {
            if let samples = await self.mixer.convert(sampleBuffer) {
                let level = computeRMSLevel(samples)
                await self.delegate?.audioCapture(didReceiveSamples: samples, timestamp: timestamp)
                await self.delegate?.audioCapture(didUpdateSystemLevel: level)
            }
        }
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate (microphone)

extension SystemAudioCapture: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        Task {
            if let samples = await self.micMixer.convert(sampleBuffer) {
                let level = computeRMSLevel(samples)
                await self.delegate?.audioCapture(didUpdateMicLevel: level)
                // Note: We don't mix mic into the main stream here.
                // Mic audio is useful for level meters; for transcription we rely on system audio
                // which includes the mic via loopback when using conference apps.
            }
        }
    }
}

// MARK: - Helpers

private func computeRMSLevel(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
    let rms = sqrt(sumOfSquares / Float(samples.count))
    // Convert to dB and normalize to 0-1 range (-60dB to 0dB)
    let db = 20 * log10(max(rms, 1e-6))
    return max(0, min(1, (db + 60) / 60))
}
