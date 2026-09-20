import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
    case garden
    case accounts
    case campaigns
    case queue
    case personas
    case audit
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .garden: return "Garden"
        case .accounts: return "Accounts"
        case .campaigns: return "Campaigns"
        case .queue: return "Queue"
        case .personas: return "Personas"
        case .audit: return "Console"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .garden: return "square.grid.2x2"
        case .accounts: return "person"
        case .campaigns: return "folder.fill"
        case .queue: return "chart.pie"
        case .personas: return "sparkles"
        case .audit: return "bell"
        case .settings: return "gearshape"
        }
    }
}

enum StatusTint {
    static func color(for status: CampaignStatus) -> Color {
        switch status {
        case .draft: return .secondary
        case .planned: return .blue
        case .running: return .green
        case .paused: return .orange
        case .completed: return .teal
        case .failed: return .red
        case .nuked: return .pink
        }
    }

    static func color(for status: JobStatus) -> Color {
        switch status {
        case .pending: return .secondary
        case .running: return .orange
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        case .cancelled: return .pink
        }
    }
}
