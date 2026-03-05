import Foundation
import AVFoundation

actor OpenAIWhisperEngine: TranscriptionEngine {
    nonisolated let name = "OpenAI Whisper"
    nonisolated let supportsStreaming = false
    var isLoaded: Bool { true } // Cloud engine — always ready

    private let apiKey: String
    private var currentTask: Task<TranscriptionResult, Error>?

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func load() async throws {}
    func unload() async {}

    func transcribe(samples: [Float], sampleRate: Double) async throws -> TranscriptionResult {
        guard !apiKey.isEmpty else { throw AppError.missingAPIKey("OpenAI") }

        let wavData = try encodeWAV(samples: samples, sampleRate: sampleRate)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)
        field("model", "whisper-1")
        field("response_format", "verbose_json")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.networkError("OpenAI API: \(String(data: data, encoding: .utf8) ?? "unknown error")")
        }

        return try parseResponse(data)
    }

    nonisolated func cancel() {
        Task { await self.currentTask?.cancel() }
    }

    // MARK: - Private

    private func parseResponse(_ data: Data) throws -> TranscriptionResult {
        struct Response: Decodable {
            let text: String; let language: String?
            let segments: [Segment]?
            struct Segment: Decodable { let text: String; let start, end: Double }
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        return TranscriptionResult(
            text: r.text,
            segments: (r.segments ?? []).map { TranscriptionSegment(text: $0.text, startTime: $0.start, endTime: $0.end, confidence: 1) },
            language: r.language
        )
    }

    private func encodeWAV(samples: [Float], sampleRate: Double) throws -> Data {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw AppError.audioConversionFailed
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData?[0].update(from: $0.baseAddress!, count: samples.count) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
    }
}
