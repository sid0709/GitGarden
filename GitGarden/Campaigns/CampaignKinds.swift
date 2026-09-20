import Foundation

nonisolated enum CampaignKind: String, CaseIterable, Identifiable, Sendable {
    case daily
    case history
    case issues
    case pullRequests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .history: return "Fake history"
        case .issues: return "Issues"
        case .pullRequests: return "Pull requests"
        }
    }

    var blurb: String {
        switch self {
        case .daily: return "Standing schedule: each launch applies today’s remaining commits, issues, and PRs into one repo."
        case .history: return "Backdated git commits pushed into an existing repo."
        case .issues: return "Open, comment, and close issues with gh."
        case .pullRequests: return "Open and merge pull requests with gh."
        }
    }
}

extension Campaign {
    var kind: CampaignKind {
        get {
            if dailySchedule { return .daily }
            if includeIssues && !includeHistory && !includePRs { return .issues }
            if includePRs && !includeIssues { return .pullRequests }
            return .history
        }
        set { applyKind(newValue) }
    }

    func applyKind(_ kind: CampaignKind) {
        dailySchedule = kind == .daily
        includeHistory = kind == .history || kind == .daily
        includePRs = kind == .pullRequests || kind == .daily
        includeIssues = kind == .issues || kind == .daily
        includeProfile = false
        includeSocial = false
        collaborator = nil
        switch kind {
        case .daily:
            commitCount = 3
            prCount = 2
            issueCount = 2
            endDate = Date()
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
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

    func remainingDaily(on today: String) -> (commits: Int, issues: Int, prs: Int) {
        (
            CronTick.remaining(target: commitCount, applied: appliedCommitsToday, lastDay: lastScheduleDay, today: today),
            CronTick.remaining(target: issueCount, applied: appliedIssuesToday, lastDay: lastScheduleDay, today: today),
            CronTick.remaining(target: prCount, applied: appliedPRsToday, lastDay: lastScheduleDay, today: today)
        )
    }

    var isDailyCaughtUp: Bool {
        let rem = remainingDaily(on: CronTick.dayKey(Date()))
        return rem.commits == 0 && rem.issues == 0 && rem.prs == 0
    }
}
