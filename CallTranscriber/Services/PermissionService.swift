import Foundation
import AVFoundation
import ScreenCaptureKit

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

@MainActor
final class PermissionService: ObservableObject {
    @Published var microphoneStatus: PermissionStatus = .notDetermined
    @Published var screenRecordingStatus: PermissionStatus = .notDetermined

    var allGranted: Bool {
        microphoneStatus == .granted && screenRecordingStatus == .granted
    }

    func checkAll() async {
        await checkMicrophone()
        await checkScreenRecording()
    }

    func requestAll() async {
        await requestMicrophone()
        await requestScreenRecording()
    }

    // MARK: - Microphone

    func checkMicrophone() async {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            microphoneStatus = .granted
        case .denied:
            microphoneStatus = .denied
        case .undetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }

    func requestMicrophone() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        microphoneStatus = granted ? .granted : .denied
    }

    // MARK: - Screen Recording

    func checkScreenRecording() async {
        do {
            // Attempting to get shareable content is the canonical check
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecordingStatus = .granted
        } catch {
            screenRecordingStatus = .denied
        }
    }

    func requestScreenRecording() async {
        // ScreenCaptureKit will show the system permission prompt on first use.
        // We trigger it by attempting a capture, then re-check status.
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecordingStatus = .granted
        } catch {
            // If denied, open System Settings
            screenRecordingStatus = .denied
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
