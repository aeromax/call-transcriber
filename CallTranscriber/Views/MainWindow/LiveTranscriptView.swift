import SwiftUI

struct LiveTranscriptView: View {
    let segments: [LiveSegment]
    @State private var autoScroll = true

    private let speakerColors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        SegmentBubble(
                            segment: segment,
                            color: colorForSpeaker(segment.speakerLabel)
                        )
                        .id(segment.id)
                    }

                    // Scroll anchor
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .onChange(of: segments.count) { _, _ in
                if autoScroll {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("bottom")
                    }
                }
            }
        }
    }

    private func colorForSpeaker(_ label: String) -> Color {
        // Deterministic color from speaker label hash
        let hash = abs(label.hashValue)
        return speakerColors[hash % speakerColors.count]
    }
}

struct SegmentBubble: View {
    let segment: LiveSegment
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Speaker avatar
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(speakerInitial)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(segment.speakerLabel)
                        .font(.caption.bold())
                        .foregroundStyle(color)

                    Text(formatTime(segment.startTime))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if segment.isProvisional {
                        Text("provisional")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }

                Text(segment.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .opacity(segment.isProvisional ? 0.8 : 1.0)
    }

    private var speakerInitial: String {
        segment.speakerLabel.first.map { String($0) } ?? "?"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
