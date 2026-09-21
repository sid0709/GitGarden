import Foundation
import SwiftData

@Model
final class Campaign {
    var name: String
    var statusRaw: String
    var includeHistory: Bool
    var includePRs: Bool
    var includeIssues: Bool
    var includeProfile: Bool
    var includeSocial: Bool
    var dryRun: Bool
    var dripMode: Bool
    var dripInterval: TimeInterval
    var throwawayRepo: Bool
    var startDate: Date
    var endDate: Date
    var commitCount: Int
    var prCount: Int
    var issueCount: Int
    var repoName: String
    var repoDescription: String
    var language: String
    var personaID: String
    var planJSON: Data?
    var heatmapJSON: Data?
    var createdAt: Date
    var updatedAt: Date
    var lastError: String
    var seed: Int64
    var workspaceID: String
    var dailySchedule: Bool = false
    var lastScheduleDay: String = ""
    var appliedCommitsToday: Int = 0
    var appliedIssuesToday: Int = 0
    var appliedPRsToday: Int = 0
    var lastScheduleSucceeded: Bool = false
    var lastScheduleMessage: String = ""
    var lastScheduleAt: Date?

    var owner: Account?
    var collaborator: Account?

    @Relationship(deleteRule: .cascade, inverse: \Job.campaign)
    var jobs: [Job]

    @Relationship(deleteRule: .cascade, inverse: \CreatedResource.campaign)
    var resources: [CreatedResource]

    @Relationship(deleteRule: .cascade, inverse: \CampaignSnapshot.campaign)
    var snapshots: [CampaignSnapshot]

    init(
        name: String,
        owner: Account? = nil,
        collaborator: Account? = nil,
        personaID: String = "rustacean"
    ) {
        self.name = name
        self.statusRaw = CampaignStatus.draft.rawValue
        self.includeHistory = true
        self.includePRs = true
        self.includeIssues = true
        self.includeProfile = false
        self.includeSocial = false
        self.dryRun = false
        self.dripMode = false
        self.dripInterval = 45
        self.throwawayRepo = false
        let now = Date()
        self.endDate = now
        self.startDate = Calendar.current.date(byAdding: .year, value: -10, to: now) ?? now
        self.commitCount = 400
        self.prCount = 30
        self.issueCount = 40
        self.repoName = ""
        self.repoDescription = ""
        self.language = "rust"
        self.personaID = personaID
        self.planJSON = nil
        self.heatmapJSON = nil
        self.createdAt = now
        self.updatedAt = now
        self.lastError = ""
        self.seed = Int64.random(in: 1...Int64.max)
        self.workspaceID = UUID().uuidString
        self.dailySchedule = false
        self.lastScheduleDay = ""
        self.appliedCommitsToday = 0
        self.appliedIssuesToday = 0
        self.appliedPRsToday = 0
        self.lastScheduleSucceeded = false
        self.lastScheduleMessage = ""
        self.lastScheduleAt = nil
        self.owner = owner
        self.collaborator = collaborator
        self.jobs = []
        self.resources = []
        self.snapshots = []
    }

    var status: CampaignStatus {
        get { CampaignStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var plan: CampaignPlanDocument? {
        get {
            guard let planJSON else { return nil }
            return try? JSONDecoder.garden.decode(CampaignPlanDocument.self, from: planJSON)
        }
        set {
            planJSON = try? JSONEncoder.garden.encode(newValue)
            heatmapJSON = try? JSONEncoder.garden.encode(newValue?.heatmap ?? [])
        }
    }

    var involvedLogins: [String] {
        var logins: [String] = []
        if let owner { logins.append(owner.login) }
        if let collaborator { logins.append(collaborator.login) }
        return logins
    }

    var defaultRepoName: String {
        if !repoName.isEmpty { return repoName }
        return "pick a repo"
    }

    func resolvedRepoName(prefix: String) -> String {
        if !repoName.isEmpty { return repoName }
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return (throwawayRepo ? prefix : "") + (slug.isEmpty ? "garden" : slug)
    }

    var progress: Double {
        guard !jobs.isEmpty else { return 0 }
        let done = jobs.filter { $0.status == .completed || $0.status == .skipped }.count
        return Double(done) / Double(jobs.count)
    }

    var historyYears: Int {
        let years = Calendar.current.dateComponents([.year], from: startDate, to: endDate).year ?? 10
        return min(20, max(1, years == 0 ? 1 : years))
    }

    func setHistoryYears(_ years: Int) {
        let clamped = min(20, max(1, years))
        startDate = Calendar.current.date(byAdding: .year, value: -clamped, to: endDate) ?? startDate
    }

    static func suggestedCommitCount(forYears years: Int) -> Int {
        min(2500, max(8, years * 40))
    }

    static func suggestedPRCount(forYears years: Int) -> Int {
        min(120, max(0, years * 3))
    }

    static func suggestedIssueCount(forYears years: Int) -> Int {
        min(160, max(0, years * 4))
    }
}

extension JSONEncoder {
    static let garden: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let garden: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
