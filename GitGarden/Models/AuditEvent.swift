import Foundation
import SwiftData

@Model
final class AuditEvent {
    var timestamp: Date
    var accountLogin: String
    var method: String
    var path: String
    var statusCode: Int
    var retryAfter: TimeInterval
    var message: String
    var campaignName: String

    init(
        timestamp: Date = Date(),
        accountLogin: String,
        method: String,
        path: String,
        statusCode: Int,
        retryAfter: TimeInterval = 0,
        message: String = "",
        campaignName: String = ""
    ) {
        self.timestamp = timestamp
        self.accountLogin = accountLogin
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.retryAfter = retryAfter
        self.message = TokenRedactor.redact(message)
        self.campaignName = campaignName
    }
}

@Model
final class CampaignSnapshot {
    var createdAt: Date
    var phase: String
    var json: Data
    var campaign: Campaign?

    init(phase: String, json: Data, campaign: Campaign?) {
        self.createdAt = Date()
        self.phase = phase
        self.json = json
        self.campaign = campaign
    }
}

@Model
final class AppSettings {
    var defaultDryRun: Bool
    var throwawayPrefix: String
    var worktreePath: String
    var dripInterval: TimeInterval

    init() {
        self.defaultDryRun = true
        self.throwawayPrefix = "gitgarden-test-"
        self.worktreePath = ""
        self.dripInterval = 45
    }

    var resolvedWorktreePath: URL {
        if !worktreePath.isEmpty {
            return URL(fileURLWithPath: worktreePath)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("GitGarden/worktrees", isDirectory: true)
    }
}
