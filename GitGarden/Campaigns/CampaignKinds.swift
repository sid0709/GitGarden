import Foundation

nonisolated enum CampaignKind: String, CaseIterable, Identifiable, Sendable {
    case history
    case issues
    case pullRequests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "Fake history"
        case .issues: return "Issues"
        case .pullRequests: return "Pull requests"
        }
    }

    var blurb: String {
        switch self {
        case .history: return "Backdated git commits pushed into an existing repo."
        case .issues: return "Open, comment, and close issues with gh."
        case .pullRequests: return "Open and merge pull requests with gh."
        }
    }
}

extension Campaign {
    var kind: CampaignKind {
        get {
            if includeIssues && !includeHistory && !includePRs { return .issues }
            if includePRs && !includeIssues { return .pullRequests }
            return .history
        }
        set { applyKind(newValue) }
    }

    func applyKind(_ kind: CampaignKind) {
        includeHistory = kind == .history
        includePRs = kind == .pullRequests
        includeIssues = kind == .issues
        includeProfile = false
        includeSocial = false
        collaborator = nil
        switch kind {
        case .history:
            commitCount = Campaign.suggestedCommitCount(forYears: historyYears)
            prCount = 0
            issueCount = 0
        case .issues:
            commitCount = 0
            prCount = 0
            issueCount = max(issueCount, 8)
        case .pullRequests:
            commitCount = 0
            prCount = max(prCount, 4)
            issueCount = 0
        }
    }
}
