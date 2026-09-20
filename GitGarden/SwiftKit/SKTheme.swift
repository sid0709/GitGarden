import SwiftUI

enum SKTheme {
    static let canvas = Color(red: 0.965, green: 0.969, blue: 0.976)
    static let canvasDark = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let card = Color.white
    static let ink = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let mute = Color(red: 0.62, green: 0.64, blue: 0.68)
    static let hairline = Color.primary.opacity(0.08)
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.22)
    static let accentSoft = Color(red: 1.0, green: 0.55, blue: 0.22).opacity(0.14)
    static let peach = Color(red: 1.0, green: 0.72, blue: 0.45)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.38)
    static let rose = Color(red: 0.98, green: 0.35, blue: 0.48)

    static let radiusCard: CGFloat = 18
    static let radiusPill: CGFloat = 22
    static let radiusRail: CGFloat = 14
    static let railWidth: CGFloat = 76

    static func canvasColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : canvas
    }

    static func cardColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.18, green: 0.185, blue: 0.20) : card
    }

    static func railColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.14, green: 0.145, blue: 0.16) : card
    }

    static func searchFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.18, green: 0.185, blue: 0.20) : card
    }

    static func inkColor(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.92) : ink
    }
}

enum SKTagKind: String {
    case bug, ux, ui, history, pull, issue, social, profile, running, pending, failed, live, dry

    var title: String {
        switch self {
        case .bug: return "Bug"
        case .ux: return "UX design"
        case .ui: return "UI design"
        case .history: return "History"
        case .pull: return "Pull request"
        case .issue: return "Issue"
        case .social: return "Social"
        case .profile: return "Profile"
        case .running: return "Running"
        case .pending: return "Queued"
        case .failed: return "Failed"
        case .live: return "Live"
        case .dry: return "Dry run"
        }
    }

    var tint: Color {
        switch self {
        case .bug, .failed, .issue: return Color(red: 0.95, green: 0.32, blue: 0.38)
        case .ux, .history, .pending, .dry: return Color(red: 0.93, green: 0.58, blue: 0.22)
        case .ui, .pull, .running: return Color(red: 0.31, green: 0.72, blue: 0.45)
        case .social, .profile, .live: return Color(red: 0.39, green: 0.50, blue: 0.95)
        }
    }
}

enum SKMotion {
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let lift = Animation.spring(response: 0.36, dampingFraction: 0.72)
}

struct GardenSearchKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var gardenSearch: String {
        get { self[GardenSearchKey.self] }
        set { self[GardenSearchKey.self] = newValue }
    }
}

extension View {
    func skSoftTransition() -> some View {
        transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)),
            removal: .opacity
        ))
    }
}
