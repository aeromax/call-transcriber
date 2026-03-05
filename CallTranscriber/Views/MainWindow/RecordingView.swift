import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var permissionService = PermissionService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            RecordingControlBar()
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Error banner
            if let error = appState.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                    Text(error).font(.caption)
                    Spacer()
                    Button("Dismiss") { appState.lastError = nil }.font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.12))

                Divider()
            }

            // Audio meters
            AudioMeterView(
                systemLevel: appState.systemAudioLevel,
                micLevel: appState.microphoneLevel
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Live transcript
            if appState.liveSegments.isEmpty {
                EmptyTranscriptView()
            } else {
                LiveTranscriptView(segments: appState.liveSegments)
            }
        }
        .task {
            await permissionService.checkAll()
        }
    }
}

struct RecordingControlBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            // Record button
            Button(action: handleRecordTap) {
                HStack(spacing: 8) {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(appState.isRecording ? .red : .primary)
                    Text(buttonTitle)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isRecording ? .red : .accentColor)
            .disabled(appState.sessionState == .preparing || appState.sessionState == .postProcessing)

            // Duration
            if appState.isRecording {
                Text(formatDuration(appState.currentRecordingDuration))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                // Live indicator
                RecordingIndicator()
            }

            Spacer()

            // Engine selector
            Picker("Engine", selection: $appState.selectedEngine) {
                ForEach(TranscriptionEngineType.allCases) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)
            .disabled(appState.isRecording)

            // Post-processing indicator
            if appState.sessionState == .postProcessing {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Processing…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var buttonTitle: String {
        switch appState.sessionState {
        case .idle: return "Start Recording"
        case .preparing: return "Preparing…"
        case .recording: return "Stop Recording"
        case .postProcessing: return "Processing…"
        case .completed: return "Start Recording"
        }
    }

    private func handleRecordTap() {
        if appState.isRecording {
            Task { await appState.stopRecording() }
        } else {
            Task { await appState.startRecording() }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RecordingIndicator: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.2
                }
            }
    }
}

struct EmptyTranscriptView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Start recording to see live transcription")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("System audio and microphone will be captured")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
