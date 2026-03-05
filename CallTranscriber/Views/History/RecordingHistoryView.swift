import SwiftUI
import SwiftData

struct RecordingHistoryView: View {
    @Query(sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    @State private var selectedRecording: Recording?
    @State private var searchText = ""
    @Environment(\.modelContext) private var context

    private var filteredRecordings: [Recording] {
        guard !searchText.isEmpty else { return recordings }
        return recordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.transcript?.fullText.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredRecordings, selection: $selectedRecording) { recording in
                RecordingListRow(recording: recording)
                    .tag(recording)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteRecording(recording)
                        }
                    }
            }
            .searchable(text: $searchText, prompt: "Search recordings")
            .navigationTitle("History")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .overlay {
                if recordings.isEmpty {
                    ContentUnavailableView("No Recordings", systemImage: "waveform",
                                          description: Text("Start recording a call to see it here."))
                }
            }
        } detail: {
            if let recording = selectedRecording {
                RecordingDetailView(recording: recording)
            } else {
                ContentUnavailableView("Select a Recording", systemImage: "waveform")
            }
        }
    }

    private func deleteRecording(_ recording: Recording) {
        context.delete(recording)
        if selectedRecording == recording { selectedRecording = nil }
        try? context.save()
    }
}

struct RecordingListRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
            HStack {
                Text(recording.createdAt, style: .date)
                Text("·")
                Text(recording.formattedDuration)
                Text("·")
                Text(recording.engineUsed)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
