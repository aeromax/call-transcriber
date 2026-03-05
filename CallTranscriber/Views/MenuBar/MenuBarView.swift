import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Status
            HStack {
                Circle()
                    .fill(appState.isRecording ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                Text(appState.isRecording ? "Recording…" : "Ready")
                    .font(.headline)
                Spacer()
                if appState.isRecording {
                    Text(formatDuration(appState.currentRecordingDuration))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // Audio meters (mini)
            if appState.isRecording {
                HStack(spacing: 8) {
                    MiniMeter(level: appState.systemAudioLevel, label: "SYS", tint: .blue)
                    MiniMeter(level: appState.microphoneLevel, label: "MIC", tint: .green)
                }
                .padding(.horizontal)
            }

            // Live transcript preview
            if !appState.liveSegments.isEmpty, let last = appState.liveSegments.last {
                VStack(alignment: .leading, spacing: 4) {
                    Text(last.speakerLabel)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(last.text)
                        .font(.caption)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            Divider()

            // Controls
            Button(action: handleRecordTap) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(appState.isRecording ? .red : .accentColor)
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .disabled(appState.sessionState == .preparing || appState.sessionState == .postProcessing)

            Button("Open Main Window") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .frame(width: 260)
    }

    private func handleRecordTap() {
        if appState.isRecording {
            Task { await appState.stopRecording() }
        } else {
            Task { await appState.startRecording() }
        }
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(d)/60, Int(d)%60)
    }
}

struct MiniMeter: View {
    let level: Float
    let label: String
    let tint: Color
    private let barCount = 10

    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 22)
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > Float(i)/Float(barCount) ? tint : tint.opacity(0.2))
                    .frame(width: 5, height: 10)
            }
        }
    }
}
