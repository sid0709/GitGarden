import Foundation

nonisolated enum CampaignStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case planned
    case running
    case paused
    case completed
    case failed
    case nuked
}

nonisolated enum JobStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case completed
    case failed
    case skipped
    case cancelled
}

nonisolated enum StepKind: String, Codable, CaseIterable, Sendable {
    case createRepo
    case inviteCollaborator
    case commit
    case push
    case createIssue
    case commentIssue
    case closeIssue
    case createBranch
    case createPR
    case reviewPR
    case mergePR
    case createRelease
    case patchProfile
    case follow
    case star

    var requiredScopes: [String] {
        switch self {
        case .createRepo, .inviteCollaborator, .commit, .push, .createIssue, .commentIssue, .closeIssue, .createBranch, .createPR, .reviewPR, .mergePR, .createRelease:
            return ["repo"]
        case .patchProfile, .follow:
            return ["user"]
        case .star:
            return ["public_repo", "repo"]
        }
    }

    var title: String {
        switch self {
        case .createRepo: return "Create repo"
        case .inviteCollaborator: return "Invite collaborator"
        case .commit: return "Commit"
        case .push: return "Push"
        case .createIssue: return "Open issue"
        case .commentIssue: return "Comment on issue"
        case .closeIssue: return "Close issue"
        case .createBranch: return "Create branch"
        case .createPR: return "Open pull request"
        case .reviewPR: return "Review pull request"
        case .mergePR: return "Merge pull request"
        case .createRelease: return "Create release"
        case .patchProfile: return "Edit profile"
        case .follow: return "Follow user"
        case .star: return "Star repo"
        }
    }
}

nonisolated enum ResourceKind: String, Codable, CaseIterable, Sendable {
    case repo
    case issue
    case pullRequest
    case gist
    case release
}

nonisolated struct FileChange: Codable, Hashable, Sendable {
    var path: String
    var content: String
}

nonisolated struct StepPayload: Codable, Hashable, Sendable {
    var repo: String?
    var owner: String?
    var message: String?
    var files: [FileChange]?
    var branch: String?
    var baseBranch: String?
    var title: String?
    var body: String?
    var issueNumber: Int?
    var prNumber: Int?
    var username: String?
    var authorDate: Date?
    var committerEmail: String?
    var committerName: String?
    var relatedIssue: Int?
    var tag: String?
    var bio: String?
    var privateRepo: Bool?
    var description: String?
    var homepage: String?
    var language: String?
    var eventRef: String?
}

nonisolated struct PlanStep: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var kind: StepKind
    var accountLogin: String
    var scheduledAt: Date
    var summary: String
    var payload: StepPayload
}

nonisolated struct HeatmapDay: Codable, Hashable, Sendable {
    var date: String
    var existing: Int
    var planned: Int

    var total: Int { existing + planned }
}

nonisolated struct PlanSummary: Codable, Hashable, Sendable {
    var commitCount: Int
    var prCount: Int
    var issueCount: Int
    var reviewCount: Int
    var releaseCount: Int
    var socialCount: Int
    var estimatedAPICalls: Int
}

nonisolated struct CampaignPlanDocument: Codable, Hashable, Sendable {
    var steps: [PlanStep]
    var heatmap: [HeatmapDay]
    var summary: PlanSummary
    var seed: UInt64
}

nonisolated struct AuditPayload: Codable, Hashable, Sendable {
    var timestamp: Date
    var accountLogin: String
    var method: String
    var path: String
    var statusCode: Int
    var retryAfter: TimeInterval?
    var message: String
}

nonisolated enum GitGardenError: Error, LocalizedError, Sendable {
    case invalidToken
    case missingAccount
    case missingScope(String)
    case conflict(String)
    case gitFailed(String)
    case api(String)
    case planMissing
    case cancelled
    case nukeBlocked(String)

    var errorDescription: String? {
        switch self {
        case .invalidToken: return "GitHub rejected this token."
        case .missingAccount: return "No GitHub account is selected."
        case .missingScope(let scope): return "Token is missing the \(scope) scope."
        case .conflict(let message): return message
        case .gitFailed(let message): return message
        case .api(let message): return message
        case .planMissing: return "Generate a dry-run plan before executing."
        case .cancelled: return "Cancelled."
        case .nukeBlocked(let message): return message
        }
    }
}

nonisolated enum TokenRedactor {
    static func redact(_ text: String) -> String {
        var result = text
        let patterns = [
            #"ghp_[A-Za-z0-9_]+"#,
            #"github_pat_[A-Za-z0-9_]+"#,
            #"gho_[A-Za-z0-9_]+"#,
            #"ghu_[A-Za-z0-9_]+"#,
            #"ghs_[A-Za-z0-9_]+"#,
            #"ghr_[A-Za-z0-9_]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[redacted-token]")
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"x-access-token:[^@\s]+"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "x-access-token:[redacted]")
        }
        return result
    }
}
