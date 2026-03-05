import Foundation
import AVFoundation

actor DeepgramEngine: TranscriptionEngine {
    nonisolated let name = "Deepgram"
    nonisolated let supportsStreaming = false
    var isLoaded: Bool { true }

    private let apiKey: String
    private let model: String

    init(apiKey: String, model: String = "nova-2") {
        self.apiKey = apiKey
        self.model = model
    }

    func load() async throws {}
    func unload() async {}

    func transcribe(samples: [Float], sampleRate: Double) async throws -> TranscriptionResult {
        guard !apiKey.isEmpty else { throw AppError.missingAPIKey("Deepgram") }

        let wavData = try encodeWAV(samples: samples, sampleRate: sampleRate)

        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")!
        components.queryItems = [
            .init(name: "model", value: model),
            .init(name: "smart_format", value: "true"),
            .init(name: "utterances", value: "true"),
            .init(name: "punctuate", value: "true"),
            .init(name: "diarize", value: "true"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = wavData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.networkError("Deepgram API: \(String(data: data, encoding: .utf8) ?? "unknown error")")
        }

        return try parseResponse(data)
    }

    nonisolated func cancel() {}

    // MARK: - Private

    private func parseResponse(_ data: Data) throws -> TranscriptionResult {
        struct Response: Decodable {
            let results: Results
            struct Results: Decodable {
                let channels: [Channel]
                let utterances: [Utterance]?
                struct Channel: Decodable {
                    let alternatives: [Alt]
                    struct Alt: Decodable { let transcript: String }
                }
                struct Utterance: Decodable { let transcript: String; let start, end: Double; let speaker: Int? }
            }
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        let text = r.results.channels.first?.alternatives.first?.transcript ?? ""
        let segments = (r.results.utterances ?? []).map {
            TranscriptionSegment(text: $0.transcript, startTime: $0.start, endTime: $0.end, confidence: 1)
        }
        return TranscriptionResult(text: text, segments: segments, language: nil)
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
