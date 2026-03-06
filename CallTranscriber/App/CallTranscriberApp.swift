import SwiftUI
import SwiftData

@main
struct CallTranscriberApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(PersistenceController.shared.container)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .task {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .help) {
                Button("Grant Permissions…") { showOnboarding = true }
                    .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra(
            "Call Transcriber",
            systemImage: appState.isRecording ? "waveform.circle.fill" : "waveform.circle"
        ) {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
