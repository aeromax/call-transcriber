import Foundation
import KeychainAccess

final class KeychainService {
    static let shared = KeychainService()

    private let keychain = Keychain(service: "com.callTranscriber.app")

    private init() {}

    // MARK: - API Keys

    var openAIAPIKey: String? {
        get { try? keychain.get("openai_api_key") }
        set {
            if let value = newValue, !value.isEmpty {
                try? keychain.set(value, key: "openai_api_key")
            } else {
                try? keychain.remove("openai_api_key")
            }
        }
    }

    var deepgramAPIKey: String? {
        get { try? keychain.get("deepgram_api_key") }
        set {
            if let value = newValue, !value.isEmpty {
                try? keychain.set(value, key: "deepgram_api_key")
            } else {
                try? keychain.remove("deepgram_api_key")
            }
        }
    }

    func clearAll() {
        try? keychain.removeAll()
    }
}
