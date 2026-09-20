import Foundation
import SwiftData

nonisolated enum CronKind: String, CaseIterable, Identifiable, Sendable {
    case issues
    case pullRequests
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .issues: return "Issues"
        case .pullRequests: return "Pull requests"
        case .both: return "Issues and PRs"
        }
    }

    var includesIssues: Bool { self == .issues || self == .both }
    var includesPulls: Bool { self == .pullRequests || self == .both }
}

nonisolated enum CronTick {
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func dueKinds(
        kind: CronKind,
        lastIssueDay: String,
        lastPullDay: String,
        today: String
    ) -> [CronKind] {
        var due: [CronKind] = []
        if kind.includesIssues, lastIssueDay != today { due.append(.issues) }
        if kind.includesPulls, lastPullDay != today { due.append(.pullRequests) }
        return due
    }

    static func remaining(target: Int, applied: Int, lastDay: String, today: String) -> Int {
        max(0, target - (lastDay == today ? applied : 0))
    }
}

@Model
final class AccountCron {
    var enabled: Bool
    var kindRaw: String
    var repoName: String
    var lastIssueDay: String
    var lastPullDay: String
    var lastAppliedAt: Date?
    var lastSucceeded: Bool
    var lastMessage: String
    var lastURL: String
    var account: Account?

    init(account: Account, repoName: String = "", kind: CronKind = .issues) {
        self.enabled = false
        self.kindRaw = kind.rawValue
        self.repoName = repoName
        self.lastIssueDay = ""
        self.lastPullDay = ""
        self.lastAppliedAt = nil
        self.lastSucceeded = false
        self.lastMessage = ""
        self.lastURL = ""
        self.account = account
    }

    var kind: CronKind {
        get { CronKind(rawValue: kindRaw) ?? .issues }
        set { kindRaw = newValue.rawValue }
    }

    func dueKinds(on day: String) -> [CronKind] {
        CronTick.dueKinds(
            kind: kind,
            lastIssueDay: lastIssueDay,
            lastPullDay: lastPullDay,
            today: day
        )
    }

    var isCaughtUp: Bool {
        enabled && dueKinds(on: CronTick.dayKey(Date())).isEmpty
    }
}
