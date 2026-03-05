import SwiftUI
import SwiftData
import AVFoundation

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var editingTitle = false
    @State private var titleText = ""
    @State private var exportFormat: ExportFormat = .plainText
    @State private var showExportPanel = false
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackTime: TimeInterval = 0
    @State private var playbackTimer: Timer?
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                if editingTitle {
                    TextField("Title", text: $titleText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveTitle() }
                    Button("Save") { saveTitle() }.buttonStyle(.borderedProminent)
                    Button("Cancel") { editingTitle = false }.buttonStyle(.bordered)
                } else {
                    Text(recording.title)
                        .font(.title3.bold())
                    Button(action: { titleText = recording.title; editingTitle = true }) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Export
                Menu {
                    ForEach(ExportFormat.allCases) { format in
                        Button(format.rawValue) { exportAs(format) }
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .menuStyle(.borderedButton)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Playback bar
            if let transcript = recording.transcript, !transcript.segments.isEmpty {
                PlaybackBar(
                    duration: recording.duration,
                    currentTime: $playbackTime,
                    isPlaying: $isPlaying,
                    onPlayPause: togglePlayback,
                    onSeek: seek
                )
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Transcript editor
                TranscriptEditorView(
                    transcript: transcript,
                    currentPlaybackTime: playbackTime
                )
            } else {
                ContentUnavailableView("No Transcript", systemImage: "text.bubble",
                                       description: Text("This recording has no transcript yet."))
            }
        }
        .navigationTitle(recording.title)
    }

    private func saveTitle() {
        recording.title = titleText
        try? context.save()
        editingTitle = false
    }

    private func exportAs(_ format: ExportFormat) {
        guard let transcript = recording.transcript else { return }

        do {
            let data = try TranscriptExporter.export(
                transcript: transcript,
                format: format,
                recordingTitle: recording.title
            )

            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(recording.title).\(format.fileExtension)"
            panel.allowedContentTypes = []

            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            playbackTimer?.invalidate()
            isPlaying = false
        } else {
            do {
                if player == nil {
                    player = try AVAudioPlayer(contentsOf: recording.audioFileURL)
                    player?.currentTime = playbackTime
                }
                player?.play()
                isPlaying = true
                playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    playbackTime = player?.currentTime ?? 0
                    if player?.isPlaying == false {
                        isPlaying = false
                        playbackTimer?.invalidate()
                    }
                }
            } catch {
                print("Playback error: \(error)")
            }
        }
    }

    private func seek(to time: TimeInterval) {
        playbackTime = time
        player?.currentTime = time
    }
}

struct PlaybackBar: View {
    let duration: TimeInterval
    @Binding var currentTime: TimeInterval
    @Binding var isPlaying: Bool
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24)
            }
            .buttonStyle(.plain)

            Text(formatTime(currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44)

            Slider(value: Binding(
                get: { currentTime },
                set: { onSeek($0) }
            ), in: 0...max(duration, 1))

            Text(formatTime(duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60; let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct TranscriptEditorView: View {
    let transcript: Transcript
    let currentPlaybackTime: TimeInterval
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(transcript.segments.sorted { $0.index < $1.index }) { segment in
                        EditableSegmentRow(segment: segment, isActive: isActive(segment))
                            .id(segment.id)
                    }
                }
                .padding()
            }
            .onChange(of: currentPlaybackTime) { _, time in
                if let activeSegment = activeSegment(at: time) {
                    withAnimation { proxy.scrollTo(activeSegment.id, anchor: .center) }
                }
            }
        }
    }

    private func isActive(_ segment: TranscriptSegment) -> Bool {
        currentPlaybackTime >= segment.startTime && currentPlaybackTime <= segment.endTime
    }

    private func activeSegment(at time: TimeInterval) -> TranscriptSegment? {
        transcript.segments.first { time >= $0.startTime && time <= $0.endTime }
    }
}

struct EditableSegmentRow: View {
    @Bindable var segment: TranscriptSegment
    let isActive: Bool
    @Environment(\.modelContext) private var context
    @State private var editingText = false
    @State private var editText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(segment.startTime))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                TextField("Speaker", text: $segment.speakerLabel)
                    .font(.caption.bold())
                    .textFieldStyle(.plain)
                    .frame(width: 80)
                    .onSubmit { try? context.save() }
            }

            if editingText {
                TextEditor(text: $editText)
                    .font(.body)
                    .frame(minHeight: 40)
                    .onSubmit {
                        segment.text = editText
                        try? context.save()
                        editingText = false
                    }
                VStack {
                    Button("Save") {
                        segment.text = editText
                        try? context.save()
                        editingText = false
                    }.buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Cancel") { editingText = false }.buttonStyle(.bordered).controlSize(.small)
                }
            } else {
                Text(segment.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        editText = segment.text
                        editingText = true
                    }
            }
        }
        .padding(8)
        .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let m = Int(time) / 60; let s = Int(time) % 60
        return String(format: "%d:%02d", m, s)
    }
}
