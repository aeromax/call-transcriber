import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AppTab = .record

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab)
        } detail: {
            switch selectedTab {
            case .record:
                RecordingView()
            case .history:
                RecordingHistoryView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

enum AppTab: String, CaseIterable {
    case record = "Record"
    case history = "History"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .record: return "waveform"
        case .history: return "clock"
        case .settings: return "gear"
        }
    }
}

struct Sidebar: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(AppTab.allCases, id: \.self, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .badge(tab == .record && appState.isRecording ? "●" : nil)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        .navigationTitle("Call Transcriber")
    }
}
