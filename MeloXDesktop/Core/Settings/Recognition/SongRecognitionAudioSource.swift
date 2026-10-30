import Foundation

enum SongRecognitionAudioSource: String, CaseIterable, Identifiable {
    case microphone
    case systemAudio

    var id: String { rawValue }

    var title: String {
        L10n.string("ui.desktop.recognition.source.\(rawValue)")
    }

    var detail: String {
        L10n.string("ui.desktop.recognition.source.\(rawValue).detail")
    }

    var systemImage: String {
        self == .microphone ? "mic.fill" : "speaker.wave.2.fill"
    }

    var preparationTitle: String {
        L10n.string(
            self == .microphone
                ? "ui.recognition.preparing_microphone"
                : "ui.desktop.recognition.preparing_system_audio"
        )
    }

    var permissionMessage: String {
        L10n.string(
            self == .microphone
                ? "ui.recognition.microphone_permission_message"
                : "ui.desktop.recognition.system_audio_permission_message"
        )
    }

    var settingsTitle: String {
        L10n.string(
            self == .microphone
                ? "ui.desktop.recognition.open_microphone_settings"
                : "ui.desktop.recognition.open_system_audio_settings"
        )
    }

    var settingsURL: URL? {
        let pane = self == .microphone ? "Privacy_Microphone" : "Privacy_ScreenCapture"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
    }
}
