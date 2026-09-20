import Foundation

nonisolated enum GitHubDate {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    static func yearWindows(from start: Date, to end: Date) -> [(from: Date, to: Date)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let startYear = calendar.component(.year, from: min(start, end))
        let endYear = calendar.component(.year, from: max(start, end))
        var windows: [(from: Date, to: Date)] = []
        for year in startYear...endYear {
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? start
            let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59)) ?? end
            let from = max(yearStart, min(start, end))
            let to = min(yearEnd, max(start, end))
            if from <= to {
                windows.append((from, to))
            }
        }
        return windows
    }
}

nonisolated struct GitHubUser: Codable, Sendable, Hashable {
    var login: String
    var id: Int
    var name: String?
    var email: String?
    var avatarUrl: String?
    var bio: String?
    var htmlUrl: String?
    var blog: String?
    var company: String?
    var location: String?
    var twitterUsername: String?
    var followers: Int?
    var following: Int?
    var publicRepos: Int?
    var publicGists: Int?
    var totalPrivateRepos: Int?
    var ownedPrivateRepos: Int?
    var collaborators: Int?
    var createdAt: String?
    var updatedAt: String?
    var hireable: Bool?
    var type: String?
    var siteAdmin: Bool?
    var twoFactorAuthentication: Bool?
    var diskUsage: Int?
    var plan: Plan?

    nonisolated struct Plan: Codable, Sendable, Hashable {
        var name: String?
        var space: Int?
        var privateRepos: Int?
        var collaborators: Int?

        enum CodingKeys: String, CodingKey {
            case name, space, collaborators
            case privateRepos = "private_repos"
        }
    }

    enum CodingKeys: String, CodingKey {
        case login, id, name, email, bio, blog, company, location, followers, following, hireable, type, plan
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
        case twitterUsername = "twitter_username"
        case publicRepos = "public_repos"
        case publicGists = "public_gists"
        case totalPrivateRepos = "total_private_repos"
        case ownedPrivateRepos = "owned_private_repos"
        case collaborators
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case siteAdmin = "site_admin"
        case twoFactorAuthentication = "two_factor_authentication"
        case diskUsage = "disk_usage"
    }
}

nonisolated struct GitHubEmail: Codable, Sendable, Hashable {
    var email: String
    var primary: Bool
    var verified: Bool
}

nonisolated struct GitHubOrg: Codable, Sendable, Hashable {
    var login: String
    var id: Int
    var avatarUrl: String?
    var description: String?

    enum CodingKeys: String, CodingKey {
        case login, id, description
        case avatarUrl = "avatar_url"
    }
}

nonisolated struct GitHubRateLimitPayload: Codable, Sendable {
    var resources: Resources

    nonisolated struct Resources: Codable, Sendable {
        var core: Resource
        var graphql: Resource?

        nonisolated struct Resource: Codable, Sendable {
            var limit: Int
            var remaining: Int
            var reset: Int
        }
    }
}

nonisolated struct GitHubRepo: Codable, Sendable, Hashable {
    var id: Int
    var name: String
    var fullName: String
    var htmlUrl: String
    var `private`: Bool
    var owner: GitHubUser
    var description: String?
    var language: String?
    var fork: Bool?
    var archived: Bool?
    var stargazersCount: Int?
    var forksCount: Int?
    var watchersCount: Int?
    var openIssuesCount: Int?
    var defaultBranch: String?
    var createdAt: String?
    var updatedAt: String?
    var pushedAt: String?
    var homepage: String?
    var visibility: String?
    var size: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, language, fork, archived, homepage, visibility, size
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case `private`
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case watchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }

    var stars: Int { stargazersCount ?? 0 }
    var sortDate: String { pushedAt ?? updatedAt ?? createdAt ?? "" }
}

nonisolated struct GitHubIssue: Codable, Sendable, Hashable {
    var id: Int
    var number: Int
    var title: String
    var htmlUrl: String
    var state: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, state
        case htmlUrl = "html_url"
    }
}

nonisolated struct GitHubPull: Codable, Sendable, Hashable {
    var id: Int
    var number: Int
    var title: String
    var htmlUrl: String
    var state: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, state
        case htmlUrl = "html_url"
    }
}

nonisolated struct GitHubRelease: Codable, Sendable, Hashable {
    var id: Int
    var tagName: String
    var htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

nonisolated struct GitHubMergeResult: Codable, Sendable {
    var merged: Bool?
    var sha: String?
    var message: String?
}

nonisolated struct ContributionCalendar: Codable, Sendable {
    var weeks: [Week]

    nonisolated struct Week: Codable, Sendable {
        var contributionDays: [Day]
    }

    nonisolated struct Day: Codable, Sendable {
        var date: String
        var contributionCount: Int
    }
}

nonisolated struct GraphQLEnvelope<T: Decodable>: Decodable, Sendable where T: Sendable {
    var data: T?
    var errors: [GraphQLError]?

    nonisolated struct GraphQLError: Decodable, Sendable {
        var message: String
    }
}

nonisolated struct ContributionQueryData: Decodable, Sendable {
    var user: User?

    nonisolated struct User: Decodable, Sendable {
        var createdAt: String?
        var contributionsCollection: Collection
        nonisolated struct Collection: Decodable, Sendable {
            var contributionCalendar: ContributionCalendar
            var totalCommitContributions: Int?
            var totalIssueContributions: Int?
            var totalPullRequestContributions: Int?
            var totalPullRequestReviewContributions: Int?
            var restrictedContributionsCount: Int?
        }
    }
}

nonisolated protocol GitHubServicing: Sendable {
    func validateToken() async throws -> (user: GitHubUser, scopes: [String], rateLimit: RateLimit)
    func fetchRateLimit() async throws -> RateLimit
    func fetchEmails() async throws -> [GitHubEmail]
    func fetchRepos() async throws -> [GitHubRepo]
    func fetchOrgs() async throws -> [GitHubOrg]
    func fetchContributionCalendar(login: String, from: Date, to: Date) async throws -> [HeatmapDay]
    func fetchContributionHistory(login: String, from: Date, to: Date) async throws -> [HeatmapDay]
    func createRepo(name: String, description: String, isPrivate: Bool) async throws -> GitHubRepo
    func deleteRepo(owner: String, repo: String) async throws
    func inviteCollaborator(owner: String, repo: String, username: String) async throws
    func createIssue(owner: String, repo: String, title: String, body: String) async throws -> GitHubIssue
    func commentIssue(owner: String, repo: String, number: Int, body: String) async throws
    func patchIssue(owner: String, repo: String, number: Int, state: String) async throws
    func createPull(owner: String, repo: String, title: String, body: String, head: String, base: String) async throws -> GitHubPull
    func reviewPull(owner: String, repo: String, number: Int, body: String) async throws
    func mergePull(owner: String, repo: String, number: Int) async throws
    func createRelease(owner: String, repo: String, tag: String, name: String, body: String) async throws -> GitHubRelease
    func patchUser(bio: String?, name: String?) async throws -> GitHubUser
    func follow(username: String) async throws
    func star(owner: String, repo: String) async throws
    var lastRateLimit: RateLimit { get async }
    var loginHint: String { get }
}
