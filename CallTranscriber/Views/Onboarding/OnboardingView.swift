import SwiftUI

struct OnboardingView: View {
    @StateObject private var permissions = PermissionService()
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                Text("Welcome to Call Transcriber")
                    .font(.largeTitle.bold())
                Text("To get started, Call Transcriber needs a couple of permissions.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permissions list
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    iconColor: .green,
                    title: "Microphone",
                    description: "Captures your voice during calls.",
                    status: permissions.microphoneStatus,
                    action: { Task { await permissions.requestMicrophone() } }
                )

                PermissionRow(
                    icon: "display",
                    iconColor: .blue,
                    title: "Screen Recording",
                    description: "Required by macOS to capture system audio from conference apps. No screen is recorded.",
                    status: permissions.screenRecordingStatus,
                    action: { Task { await permissions.requestScreenRecording() } }
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)

            // Continue button
            Button(action: { isPresented = false }) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!permissions.allGranted)

            if !permissions.allGranted {
                Text("Please grant both permissions above to continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(width: 500)
        .task { await permissions.checkAll() }
    }
}

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Group {
                switch status {
                case .granted:
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption.bold())
                case .denied:
                    Button("Open Settings") { action() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                case .notDetermined:
                    Button("Allow") { action() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
    }
}
