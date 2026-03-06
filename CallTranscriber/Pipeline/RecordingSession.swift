import Foundation
import Combine
import SwiftData

/// Orchestrates the full recording lifecycle.
@MainActor
final class RecordingSession: NSObject, ObservableObject {
    // MARK: - State

    @Published private(set) var state: RecordingState = .idle
    @Published private(set) var liveSegments: [LiveSegment] = []
    @Published private(set) var systemAudioLevel: Float = 0
    @Published private(set) var microphoneLevel: Float = 0

    // MARK: - Dependencies

    private let audioCapture: SystemAudioCapture
    private let audioFileManager: AudioFileManager
    private let realTimePipeline: RealTimePipeline
    private let postProcessingPipeline: PostProcessingPipeline
    private let engine: any TranscriptionEngine

    private var audioFileURL: URL?
    private var startTime: Date = Date()
    private var allSamplesBuffer: [Float] = [] // also fed into file manager

    // MARK: - Factory

    static func create(engine engineType: TranscriptionEngineType) async throws -> RecordingSession {
        let engine: any TranscriptionEngine
        switch engineType {
        case .whisperKit:
            let whisperEngine = WhisperKitEngine()
            try await whisperEngine.load()
            engine = whisperEngine
        case .openAI:
            guard let key = KeychainService.shared.openAIAPIKey else {
                throw AppError.missingAPIKey("OpenAI")
            }
            engine = OpenAIWhisperEngine(apiKey: key)
        case .deepgram:
            guard let key = KeychainService.shared.deepgramAPIKey else {
                throw AppError.missingAPIKey("Deepgram")
            }
            engine = DeepgramEngine(apiKey: key)
        }

        return try RecordingSession(engine: engine)
    }

    private init(engine: any TranscriptionEngine) throws {
        self.engine = engine
        self.audioCapture = SystemAudioCapture()
        self.audioFileManager = try AudioFileManager()
        let diarizationManager = DiarizationManager()
        self.realTimePipeline = RealTimePipeline(engine: engine, diarizationManager: diarizationManager)
        self.postProcessingPipeline = PostProcessingPipeline(engine: engine, diarizationManager: diarizationManager)
        super.init()
    }

    // MARK: - Lifecycle

    func start() async throws {
        guard state == .idle else { return }
        state = .preparing

        // Start file
        audioFileURL = try audioFileManager.startNewFile()
        startTime = Date()

        // Wire up real-time pipeline callbacks
        realTimePipeline.onNewSegment = { [weak self] segment in
            self?.appendOrUpdateSegment(segment)
        }

        // Set up audio capture delegate
        await audioCapture.setDelegate(self)

        // Start real-time pipeline
        try await realTimePipeline.start(startTime: startTime)

        // Start audio capture
        try await audioCapture.startCapture()

        state = .recording
    }

    func stop() async {
        guard state == .recording else { return }
        state = .postProcessing

        // Stop capture
        await audioCapture.stopCapture()
        await realTimePipeline.stop()
        _ = audioFileManager.finalize()

        // Run post-processing if we have a file
        if let fileURL = audioFileURL {
            do {
                let processedSegments = try await postProcessingPipeline.process(audioURL: fileURL)
                // Replace provisional segments with post-processed ones
                liveSegments = processedSegments
            } catch {
                // Post-processing failed — keep real-time segments
                print("Post-processing failed: \(error)")
                // Mark all segments as final (not provisional) anyway
                liveSegments = liveSegments.map {
                    LiveSegment(id: $0.id, speakerLabel: $0.speakerLabel, text: $0.text,
                                startTime: $0.startTime, endTime: $0.endTime, isProvisional: false)
                }
            }
        }

        // Save to SwiftData
        await saveRecording()

        state = .completed
    }

    // MARK: - Private

    private func appendOrUpdateSegment(_ segment: LiveSegment) {
        // Merge with last segment if same speaker and overlapping/adjacent
        if var last = liveSegments.last,
           last.speakerLabel == segment.speakerLabel,
           segment.startTime <= last.endTime + 0.5,
           last.isProvisional {
            last.text = (last.text + " " + segment.text).trimmingCharacters(in: .whitespaces)
            last.endTime = max(last.endTime, segment.endTime)
            liveSegments[liveSegments.count - 1] = last
        } else {
            liveSegments.append(segment)
        }
    }

    private func saveRecording() async {
        guard let fileURL = audioFileURL else { return }
        let segments = liveSegments
        let duration = Date().timeIntervalSince(startTime)
        let engineName = engine.name

        let context = PersistenceController.shared.container.mainContext
        let recording = Recording(
            title: "Recording \(DateFormatter.displayFormatter.string(from: startTime))",
            audioFileURL: fileURL,
            duration: duration,
            createdAt: startTime,
            engineUsed: engineName
        )

        let transcript = Transcript(recording: recording)
        for (index, seg) in segments.enumerated() {
            let dbSeg = TranscriptSegment(
                index: index,
                text: seg.text,
                startTime: seg.startTime,
                endTime: seg.endTime,
                speakerLabel: seg.speakerLabel,
                transcript: transcript
            )
            transcript.segments.append(dbSeg)
        }

        recording.transcript = transcript
        context.insert(recording)

        do {
            try context.save()
        } catch {
            print("Failed to save recording: \(error)")
        }
    }
}

// MARK: - AudioCaptureDelegate

extension RecordingSession: AudioCaptureDelegate {
    nonisolated func audioCapture(didReceiveSamples samples: [Float], timestamp: TimeInterval) {
        Task { @MainActor in
            // Write to disk
            try? self.audioFileManager.append(samples: samples)
            // Feed into pipeline
            self.realTimePipeline.feed(samples: samples)
        }
    }

    nonisolated func audioCapture(didUpdateSystemLevel level: Float) {
        Task { @MainActor in self.systemAudioLevel = level }
    }

    nonisolated func audioCapture(didUpdateMicLevel level: Float) {
        Task { @MainActor in self.microphoneLevel = level }
    }

    nonisolated func audioCapture(didFailWithError error: Error) {
        Task { @MainActor in
            print("Audio capture error: \(error)")
            // Could show UI error here
        }
    }
}

extension DateFormatter {
    static let displayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}
