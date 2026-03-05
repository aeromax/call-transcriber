import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var title: String
    var audioFileURL: URL
    var duration: TimeInterval
    var createdAt: Date
    var engineUsed: String

    @Relationship(deleteRule: .cascade)
    var transcript: Transcript?

    init(title: String, audioFileURL: URL, duration: TimeInterval, createdAt: Date = Date(), engineUsed: String = "WhisperKit") {
        self.id = UUID()
        self.title = title
        self.audioFileURL = audioFileURL
        self.duration = duration
        self.createdAt = createdAt
        self.engineUsed = engineUsed
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@Model
final class Transcript {
    var id: UUID
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.transcript)
    var segments: [TranscriptSegment]

    @Relationship
    var recording: Recording?

    init(recording: Recording? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.segments = []
        self.recording = recording
    }

    var fullText: String {
        segments.sorted { $0.index < $1.index }
            .map { "[\($0.speakerLabel)] \($0.text)" }
            .joined(separator: "\n")
    }
}

@Model
final class TranscriptSegment {
    var id: UUID
    var index: Int
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var speakerLabel: String

    @Relationship
    var transcript: Transcript?

    init(index: Int, text: String, startTime: TimeInterval, endTime: TimeInterval,
         speakerLabel: String, transcript: Transcript? = nil) {
        self.id = UUID()
        self.index = index
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.speakerLabel = speakerLabel
        self.transcript = transcript
    }
}

@Model
final class Speaker {
    var id: UUID
    var label: String        // e.g. "Speaker 1"
    var customName: String?  // e.g. "John Smith"
    var color: String        // hex color string

    init(label: String, customName: String? = nil, color: String = "#4A90D9") {
        self.id = UUID()
        self.label = label
        self.customName = customName
        self.color = color
    }

    var displayName: String { customName ?? label }
}
