import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case plainText = "Plain Text"
    case srt = "SRT"
    case vtt = "VTT"
    case json = "JSON"

    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .plainText: return "txt"
        case .srt: return "srt"
        case .vtt: return "vtt"
        case .json: return "json"
        }
    }
}

final class TranscriptExporter {
    static func export(transcript: Transcript, format: ExportFormat, recordingTitle: String) throws -> Data {
        let segments = transcript.segments.sorted { $0.index < $1.index }

        let text: String
        switch format {
        case .plainText:
            text = exportPlainText(segments: segments, title: recordingTitle)
        case .srt:
            text = exportSRT(segments: segments)
        case .vtt:
            text = exportVTT(segments: segments)
        case .json:
            return try exportJSON(segments: segments, title: recordingTitle)
        }

        guard let data = text.data(using: .utf8) else {
            throw AppError.fileWriteFailed("Text encoding failed")
        }
        return data
    }

    // MARK: - Plain Text

    private static func exportPlainText(segments: [TranscriptSegment], title: String) -> String {
        var lines = ["# \(title)", ""]
        for seg in segments {
            let time = formatTimestamp(seg.startTime)
            lines.append("[\(time)] \(seg.speakerLabel): \(seg.text)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - SRT

    private static func exportSRT(segments: [TranscriptSegment]) -> String {
        var lines: [String] = []
        for (index, seg) in segments.enumerated() {
            lines.append(String(index + 1))
            lines.append("\(srtTimestamp(seg.startTime)) --> \(srtTimestamp(seg.endTime))")
            lines.append("<v \(seg.speakerLabel)>\(seg.text)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func srtTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }

    // MARK: - VTT

    private static func exportVTT(segments: [TranscriptSegment]) -> String {
        var lines = ["WEBVTT", ""]
        for (index, seg) in segments.enumerated() {
            lines.append("cue-\(index + 1)")
            lines.append("\(vttTimestamp(seg.startTime)) --> \(vttTimestamp(seg.endTime))")
            lines.append("<v \(seg.speakerLabel)>\(seg.text)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func vttTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let millis = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }

    // MARK: - JSON

    private static func exportJSON(segments: [TranscriptSegment], title: String) throws -> Data {
        struct JSONExport: Encodable {
            let title: String
            let exportedAt: String
            let segments: [JSONSegment]
        }
        struct JSONSegment: Encodable {
            let index: Int
            let speaker: String
            let text: String
            let startTime: Double
            let endTime: Double
        }

        let export = JSONExport(
            title: title,
            exportedAt: ISO8601DateFormatter().string(from: Date()),
            segments: segments.map {
                JSONSegment(index: $0.index, speaker: $0.speakerLabel,
                            text: $0.text, startTime: $0.startTime, endTime: $0.endTime)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    // MARK: - Helpers

    private static func formatTimestamp(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
