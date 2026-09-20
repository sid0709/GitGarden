import Foundation
import SwiftData

@Model
final class Account {
    var login: String
    var name: String
    var email: String
    var avatarURL: String
    var token: String
    var scopes: [String]
    var rateLimitRemaining: Int
    var rateLimitLimit: Int
    var rateLimitReset: Date?
    var personaID: String
    var createdAt: Date
    var lastValidatedAt: Date?
    var bio: String = ""
    var company: String = ""
    var location: String = ""
    var blog: String = ""
    var htmlURL: String = ""
    var twitter: String = ""
    var githubID: Int = 0
    var followers: Int = 0
    var following: Int = 0
    var publicRepos: Int = 0
    var publicGists: Int = 0
    var totalPrivateRepos: Int = 0
    var ownedPrivateRepos: Int = 0
    var collaboratorCount: Int = 0
    var diskUsage: Int = 0
    var planName: String = ""
    var accountType: String = ""
    var hireable: Bool = false
    var twoFactorEnabled: Bool = false
    var githubCreatedAt: Date?
    var githubUpdatedAt: Date?
    var heatmapJSON: Data?
    var reposJSON: Data?
    var orgsJSON: Data?

    @Relationship(deleteRule: .nullify, inverse: \Campaign.owner)
    var ownedCampaigns: [Campaign]

    @Relationship(deleteRule: .nullify, inverse: \Campaign.collaborator)
    var collabCampaigns: [Campaign]

    @Relationship(deleteRule: .cascade, inverse: \AccountCron.account)
    var crons: [AccountCron]

    init(
        login: String,
        name: String = "",
        email: String = "",
        avatarURL: String = "",
        token: String,
        scopes: [String] = [],
        rateLimitRemaining: Int = 0,
        rateLimitLimit: Int = 5000,
        rateLimitReset: Date? = nil,
        personaID: String = "rustacean"
    ) {
        self.login = login
        self.name = name
        self.email = email
        self.avatarURL = avatarURL
        self.token = token
        self.scopes = scopes
        self.rateLimitRemaining = rateLimitRemaining
        self.rateLimitLimit = rateLimitLimit
        self.rateLimitReset = rateLimitReset
        self.personaID = personaID
        self.createdAt = Date()
        self.lastValidatedAt = nil
        self.bio = ""
        self.company = ""
        self.location = ""
        self.blog = ""
        self.htmlURL = ""
        self.twitter = ""
        self.githubID = 0
        self.followers = 0
        self.following = 0
        self.publicRepos = 0
        self.publicGists = 0
        self.totalPrivateRepos = 0
        self.ownedPrivateRepos = 0
        self.collaboratorCount = 0
        self.diskUsage = 0
        self.planName = ""
        self.accountType = ""
        self.hireable = false
        self.twoFactorEnabled = false
        self.githubCreatedAt = nil
        self.githubUpdatedAt = nil
        self.heatmapJSON = nil
        self.reposJSON = nil
        self.orgsJSON = nil
        self.ownedCampaigns = []
        self.collabCampaigns = []
        self.crons = []
    }

    var cron: AccountCron? { crons.first }

    func apply(user: GitHubUser) {
        login = user.login
        name = user.name ?? name
        avatarURL = user.avatarUrl ?? avatarURL
        if let email = user.email, !email.isEmpty { self.email = email }
        bio = user.bio ?? ""
        company = user.company ?? ""
        location = user.location ?? ""
        blog = user.blog ?? ""
        htmlURL = user.htmlUrl ?? htmlURL
        twitter = user.twitterUsername ?? ""
        githubID = user.id
        followers = user.followers ?? 0
        following = user.following ?? 0
        publicRepos = user.publicRepos ?? 0
        publicGists = user.publicGists ?? 0
        totalPrivateRepos = user.totalPrivateRepos ?? 0
        ownedPrivateRepos = user.ownedPrivateRepos ?? 0
        collaboratorCount = user.collaborators ?? 0
        diskUsage = user.diskUsage ?? 0
        planName = user.plan?.name ?? ""
        accountType = user.type ?? ""
        hireable = user.hireable ?? false
        twoFactorEnabled = user.twoFactorAuthentication ?? twoFactorEnabled
        githubCreatedAt = GitHubDate.parse(user.createdAt) ?? githubCreatedAt
        githubUpdatedAt = GitHubDate.parse(user.updatedAt) ?? githubUpdatedAt
    }

    var cachedHeatmap: [HeatmapDay] {
        get {
            guard let heatmapJSON else { return [] }
            return (try? JSONDecoder.garden.decode([HeatmapDay].self, from: heatmapJSON)) ?? []
        }
        set {
            heatmapJSON = try? JSONEncoder.garden.encode(newValue)
        }
    }

    var cachedRepos: [GitHubRepo] {
        get {
            guard let reposJSON else { return [] }
            return (try? JSONDecoder.garden.decode([GitHubRepo].self, from: reposJSON)) ?? []
        }
        set {
            reposJSON = try? JSONEncoder.garden.encode(newValue)
        }
    }

    var cachedOrgs: [GitHubOrg] {
        get {
            guard let orgsJSON else { return [] }
            return (try? JSONDecoder.garden.decode([GitHubOrg].self, from: orgsJSON)) ?? []
        }
        set {
            orgsJSON = try? JSONEncoder.garden.encode(newValue)
        }
    }

    var totalRepoCount: Int {
        max(publicRepos + totalPrivateRepos, cachedRepos.count)
    }

    var contributionTotal: Int {
        cachedHeatmap.reduce(0) { $0 + $1.existing }
    }

    var displayName: String {
        name.isEmpty ? login : name
    }

    var isFineGrained: Bool {
        scopes.isEmpty
    }

    func missingScopes(for kinds: [StepKind]) -> [String] {
        guard !isFineGrained else { return [] }
        var missing: [String] = []
        for kind in kinds {
            let needed = kind.requiredScopes
            let hasAny = needed.contains { scopes.contains($0) }
            if !hasAny, let first = needed.first, !missing.contains(first) {
                missing.append(first)
            }
        }
        return missing
    }
}
