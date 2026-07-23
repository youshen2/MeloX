import Foundation

enum PlayerVolumeControlMode: String, CaseIterable, Identifiable {
    case hidden
    case independent
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden: "不显示"
        case .independent: "独立音量"
        case .system: "系统音量"
        }
    }

    var description: String {
        switch self {
        case .hidden:
            "播放器不显示音量滑杆，音量由系统控制。"
        case .independent:
            "播放器音量独立于系统音量，并会记住上次设置。"
        case .system:
            "播放器显示系统音量滑杆，与设备音量键控制同一音量。"
        }
    }
}
