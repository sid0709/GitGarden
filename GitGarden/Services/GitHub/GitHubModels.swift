import Foundation

nonisolated struct GitHubUser: Codable, Sendable, Hashable {
    var login: String
    var id: Int
    var name: String?
    var email: String?
    var avatarUrl: String
    var bio: String?
    var htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case login, id, name, email, bio
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

nonisolated struct GitHubEmail: Codable, Sendable, Hashable {
    var email: String
    var primary: Bool
    var verified: Bool
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

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case `private`
    }
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
        var contributionsCollection: Collection
        nonisolated struct Collection: Decodable, Sendable {
            var contributionCalendar: ContributionCalendar
        }
    }
}

nonisolated protocol GitHubServicing: Sendable {
    func validateToken() async throws -> (user: GitHubUser, scopes: [String], rateLimit: RateLimit)
    func fetchRateLimit() async throws -> RateLimit
    func fetchEmails() async throws -> [GitHubEmail]
    func fetchContributionCalendar(login: String, from: Date, to: Date) async throws -> [HeatmapDay]
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
