import Foundation

actor GitHubClient: GitHubServicing {
    let token: String
    let loginHint: String
    private let session: URLSession
    private let userAgent = "GitGarden/1.0"
    private(set) var lastRateLimit: RateLimit = .unknown
    private var lastScopes: [String] = []

    init(token: String, loginHint: String = "") {
        self.token = token
        self.loginHint = loginHint
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 45
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "GitGarden/1.0"
        ]
        self.session = URLSession(configuration: config)
    }

    func validateToken() async throws -> (user: GitHubUser, scopes: [String], rateLimit: RateLimit) {
        let (user, response): (GitHubUser, HTTPURLResponse) = try await request(method: "GET", path: "/user")
        let scopes = RateLimit.parseClassicScopes(headers: response.allHeaderFields)
        lastScopes = scopes
        lastRateLimit = RateLimit.parse(headers: response.allHeaderFields)
        _ = try? await fetchRateLimit()
        return (user, scopes, lastRateLimit)
    }

    func fetchRateLimit() async throws -> RateLimit {
        let (payload, _): (GitHubRateLimitPayload, HTTPURLResponse) = try await request(method: "GET", path: "/rate_limit")
        let core = payload.resources.core
        lastRateLimit = RateLimit(
            remaining: core.remaining,
            limit: core.limit,
            reset: Date(timeIntervalSince1970: TimeInterval(core.reset)),
            retryAfter: nil,
            resource: "core"
        )
        return lastRateLimit
    }

    func fetchEmails() async throws -> [GitHubEmail] {
        let (emails, _): ([GitHubEmail], HTTPURLResponse) = try await request(method: "GET", path: "/user/emails")
        return emails
    }

    func fetchContributionCalendar(login: String, from: Date, to: Date) async throws -> [HeatmapDay] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let query = """
        query($login:String!, $from:DateTime!, $to:DateTime!) {
          user(login:$login) {
            contributionsCollection(from:$from, to:$to) {
              contributionCalendar {
                weeks { contributionDays { date contributionCount } }
              }
            }
          }
        }
        """
        struct Body: Encodable {
            var query: String
            var variables: Variables
            struct Variables: Encodable {
                var login: String
                var from: String
                var to: String
            }
        }
        let body = Body(
            query: query,
            variables: .init(login: login, from: formatter.string(from: from), to: formatter.string(from: to))
        )
        let (envelope, _): (GraphQLEnvelope<ContributionQueryData>, HTTPURLResponse) = try await request(
            method: "POST",
            path: "/graphql",
            body: body,
            base: URL(string: "https://api.github.com")!
        )
        if let errors = envelope.errors, !errors.isEmpty {
            throw GitGardenError.api(errors.map(\.message).joined(separator: "; "))
        }
        let days = envelope.data?.user?.contributionsCollection.contributionCalendar.weeks
            .flatMap(\.contributionDays) ?? []
        return days.map { HeatmapDay(date: $0.date, existing: $0.contributionCount, planned: 0) }
    }

    func createRepo(name: String, description: String, isPrivate: Bool) async throws -> GitHubRepo {
        struct Body: Encodable {
            var name: String
            var description: String
            var `private`: Bool
            var autoInit: Bool = false
        }
        let (repo, _): (GitHubRepo, HTTPURLResponse) = try await request(
            method: "POST",
            path: "/user/repos",
            body: Body(name: name, description: description, private: isPrivate)
        )
        return repo
    }

    func deleteRepo(owner: String, repo: String) async throws {
        try await requestVoid(method: "DELETE", path: "/repos/\(owner)/\(repo)")
    }

    func inviteCollaborator(owner: String, repo: String, username: String) async throws {
        struct Body: Encodable { var permission: String = "push" }
        try await requestVoid(
            method: "PUT",
            path: "/repos/\(owner)/\(repo)/collaborators/\(username)",
            body: Body()
        )
    }

    func createIssue(owner: String, repo: String, title: String, body: String) async throws -> GitHubIssue {
        struct Body: Encodable { var title: String; var body: String }
        let (issue, _): (GitHubIssue, HTTPURLResponse) = try await request(
            method: "POST",
            path: "/repos/\(owner)/\(repo)/issues",
            body: Body(title: title, body: body)
        )
        return issue
    }

    func commentIssue(owner: String, repo: String, number: Int, body: String) async throws {
        struct Body: Encodable { var body: String }
        try await requestVoid(
            method: "POST",
            path: "/repos/\(owner)/\(repo)/issues/\(number)/comments",
            body: Body(body: body)
        )
    }

    func patchIssue(owner: String, repo: String, number: Int, state: String) async throws {
        struct Body: Encodable { var state: String }
        try await requestVoid(
            method: "PATCH",
            path: "/repos/\(owner)/\(repo)/issues/\(number)",
            body: Body(state: state)
        )
    }

    func createPull(owner: String, repo: String, title: String, body: String, head: String, base: String) async throws -> GitHubPull {
        struct Body: Encodable {
            var title: String
            var body: String
            var head: String
            var base: String
        }
        let (pull, _): (GitHubPull, HTTPURLResponse) = try await request(
            method: "POST",
            path: "/repos/\(owner)/\(repo)/pulls",
            body: Body(title: title, body: body, head: head, base: base)
        )
        return pull
    }

    func reviewPull(owner: String, repo: String, number: Int, body: String) async throws {
        struct Body: Encodable {
            var body: String
            var event: String = "COMMENT"
        }
        try await requestVoid(
            method: "POST",
            path: "/repos/\(owner)/\(repo)/pulls/\(number)/reviews",
            body: Body(body: body)
        )
    }

    func mergePull(owner: String, repo: String, number: Int) async throws {
        struct Body: Encodable { var merge_method: String = "squash" }
        let (_result, _): (GitHubMergeResult, HTTPURLResponse) = try await request(
            method: "PUT",
            path: "/repos/\(owner)/\(repo)/pulls/\(number)/merge",
            body: Body()
        )
    }

    func createRelease(owner: String, repo: String, tag: String, name: String, body: String) async throws -> GitHubRelease {
        struct Body: Encodable {
            var tag_name: String
            var name: String
            var body: String
            var generate_release_notes: Bool = false
        }
        let (release, _): (GitHubRelease, HTTPURLResponse) = try await request(
            method: "POST",
            path: "/repos/\(owner)/\(repo)/releases",
            body: Body(tag_name: tag, name: name, body: body)
        )
        return release
    }

    func patchUser(bio: String?, name: String?) async throws -> GitHubUser {
        struct Body: Encodable {
            var bio: String?
            var name: String?
        }
        let (user, _): (GitHubUser, HTTPURLResponse) = try await request(
            method: "PATCH",
            path: "/user",
            body: Body(bio: bio, name: name)
        )
        return user
    }

    func follow(username: String) async throws {
        try await requestVoid(method: "PUT", path: "/user/following/\(username)")
    }

    func star(owner: String, repo: String) async throws {
        try await requestVoid(method: "PUT", path: "/user/starred/\(owner)/\(repo)")
    }

    func lastAudit(method: String, path: String, status: Int, retryAfter: TimeInterval?) -> AuditPayload {
        AuditPayload(
            timestamp: Date(),
            accountLogin: loginHint,
            method: method,
            path: path,
            statusCode: status,
            retryAfter: retryAfter,
            message: ""
        )
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: (any Encodable)? = nil,
        base: URL = URL(string: "https://api.github.com")!
    ) async throws -> (T, HTTPURLResponse) {
        let data = try await perform(method: method, path: path, body: body, base: base)
        if T.self == Empty.self {
            return (Empty() as! T, data.response)
        }
        if data.data.isEmpty, let empty = Empty() as? T {
            return (empty, data.response)
        }
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data.data)
            return (decoded, data.response)
        } catch {
            let snippet = String(data: data.data.prefix(400), encoding: .utf8) ?? ""
            throw GitGardenError.api("Decode failed for \(path): \(error.localizedDescription) \(snippet)")
        }
    }

    private func requestVoid(method: String, path: String, body: (any Encodable)? = nil) async throws {
        _ = try await perform(method: method, path: path, body: body, base: URL(string: "https://api.github.com")!)
    }

    private func perform(
        method: String,
        path: String,
        body: (any Encodable)?,
        base: URL
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        var attempt = 0
        var lastError: Error = GitGardenError.api("Unknown GitHub error")
        while attempt < 6 {
            attempt += 1
            if lastRateLimit.isExhausted {
                let wait = min(max(lastRateLimit.waitInterval, 1), 90)
                try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            var url = base
            if path == "/graphql" {
                url = URL(string: "https://api.github.com/graphql")!
            } else {
                url = URL(string: path, relativeTo: base)!.absoluteURL
            }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            if let body {
                request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GitGardenError.api("Invalid response for \(path)")
                }
                lastRateLimit = RateLimit.parse(headers: http.allHeaderFields)
                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }
                if http.statusCode == 403 || http.statusCode == 429 {
                    let wait = lastRateLimit.waitInterval > 0 ? lastRateLimit.waitInterval : TimeInterval(min(2 << attempt, 60))
                    lastError = GitGardenError.api("Rate limited on \(method) \(path)")
                    try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                    continue
                }
                let snippet = String(data: data.prefix(500), encoding: .utf8) ?? ""
                throw GitGardenError.api("GitHub \(http.statusCode) \(method) \(path): \(snippet)")
            } catch let error as GitGardenError {
                lastError = error
                throw error
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(min(2 << attempt, 20) * 1_000_000_000))
            }
        }
        throw lastError
    }
}

nonisolated struct Empty: Decodable, Sendable {}

nonisolated struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeClosure = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
