import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // Recording state
    @Published var sessionState: RecordingState = .idle
    @Published var isRecording: Bool = false
    @Published var currentRecordingDuration: TimeInterval = 0

    // Audio levels (synced from RecordingSession)
    @Published var systemAudioLevel: Float = 0
    @Published var microphoneLevel: Float = 0

    // Live transcript (synced from RecordingSession)
    @Published var liveSegments: [LiveSegment] = []

    // Error state
    @Published var lastError: String?

    // Settings
    @Published var selectedEngine: TranscriptionEngineType = .whisperKit
    @Published var selectedMicrophoneDevice: String = "Default"

    private(set) var recordingSession: RecordingSession?
    private var sessionCancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?
    private var recordingStartTime: Date?

    func startRecording() async {
        guard sessionState == .idle else { return }
        sessionState = .preparing
        lastError = nil
        liveSegments = []

        do {
            let session = try await RecordingSession.create(engine: selectedEngine)
            self.recordingSession = session
            subscribeToSession(session)
            try await session.start()
            isRecording = true
            sessionState = .recording
            recordingStartTime = Date()
            startDurationTimer()
        } catch {
            sessionState = .idle
            lastError = error.localizedDescription
            recordingSession = nil
        }
    }

    func stopRecording() async {
        guard sessionState == .recording, let session = recordingSession else { return }
        stopDurationTimer()
        sessionState = .postProcessing
        isRecording = false
        await session.stop()
        // Sync final segments after post-processing
        liveSegments = session.liveSegments
        sessionState = .idle
        recordingSession = nil
        sessionCancellables.removeAll()
        currentRecordingDuration = 0
    }

    // MARK: - Private

    private func subscribeToSession(_ session: RecordingSession) {
        sessionCancellables.removeAll()

        session.$liveSegments
            .receive(on: RunLoop.main)
            .assign(to: &$liveSegments)

        session.$systemAudioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$systemAudioLevel)

        session.$microphoneLevel
            .receive(on: RunLoop.main)
            .assign(to: &$microphoneLevel)
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.currentRecordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case postProcessing
    case completed
}

struct LiveSegment: Identifiable, Equatable {
    let id: UUID
    var speakerLabel: String
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var isProvisional: Bool

    init(id: UUID = UUID(), speakerLabel: String = "Speaker", text: String,
         startTime: TimeInterval, endTime: TimeInterval, isProvisional: Bool = true) {
        self.id = id
        self.speakerLabel = speakerLabel
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.isProvisional = isProvisional
    }
}

enum TranscriptionEngineType: String, CaseIterable, Identifiable {
    case whisperKit = "WhisperKit (Local)"
    case openAI = "OpenAI Whisper"
    case deepgram = "Deepgram"

    var id: String { rawValue }
    var isLocal: Bool { self == .whisperKit }
}
