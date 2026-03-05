import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            APIKeysTab()
                .tabItem { Label("API Keys", systemImage: "key") }
            AudioSettingsTab()
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
            ModelsTab()
                .tabItem { Label("Models", systemImage: "cpu") }
        }
        .frame(minWidth: 520, minHeight: 380)
        .navigationTitle("Settings")
    }
}

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBar") private var showMenuBar = true

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Show menu bar icon", isOn: $showMenuBar)
            }

            Section("Transcription") {
                Picker("Default Engine", selection: $appState.selectedEngine) {
                    ForEach(TranscriptionEngineType.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Storage") {
                LabeledContent("Recordings Location") {
                    let path = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                        .appendingPathComponent("CallTranscriber").path) ?? "~/Documents/CallTranscriber"
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct APIKeysTab: View {
    @State private var openAIKey: String = KeychainService.shared.openAIAPIKey ?? ""
    @State private var deepgramKey: String = KeychainService.shared.deepgramAPIKey ?? ""
    @State private var openAISaved = false
    @State private var deepgramSaved = false

    var body: some View {
        Form {
            Section("OpenAI Whisper") {
                SecureField("API Key (sk-…)", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") {
                        KeychainService.shared.openAIAPIKey = openAIKey
                        openAISaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { openAISaved = false }
                    }
                    if openAISaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }

            Section("Deepgram") {
                SecureField("API Key", text: $deepgramKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") {
                        KeychainService.shared.deepgramAPIKey = deepgramKey
                        deepgramSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { deepgramSaved = false }
                    }
                    if deepgramSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AudioSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var availableDevices: [String] = ["Default"]

    var body: some View {
        Form {
            Section("Microphone") {
                Picker("Input Device", selection: $appState.selectedMicrophoneDevice) {
                    ForEach(availableDevices, id: \.self) { device in
                        Text(device).tag(device)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Processing") {
                LabeledContent("Sample Rate") { Text("16 kHz (optimized for speech)") }
                LabeledContent("Channels") { Text("Mono") }
                LabeledContent("Chunk Duration") { Text("10 seconds with 2s overlap") }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ModelsTab: View {
    @State private var whisperAvailable = ModelManagementService.shared.areModelsAvailable

    var body: some View {
        Form {
            Section("Local Models") {
                LabeledContent("Whisper Small") {
                    HStack {
                        Circle()
                            .fill(whisperAvailable ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(whisperAvailable ? "Ready" : "Not downloaded")
                            .foregroundStyle(.secondary)
                    }
                }
                if !whisperAvailable {
                    Text("Run `Scripts/download-models.sh` to download bundled models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Model Size") { Text("~465 MB (Whisper Small)") }
                LabeledContent("Performance") { Text("~10x real-time on Apple Silicon") }
            }

            Section("About") {
                LabeledContent("Transcription") { Text("WhisperKit + CoreML") }
                LabeledContent("Diarization") { Text("FluidAudio (VAD + pyannote + WeSpeaker)") }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
