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

    @Relationship(deleteRule: .nullify, inverse: \Campaign.owner)
    var ownedCampaigns: [Campaign]

    @Relationship(deleteRule: .nullify, inverse: \Campaign.collaborator)
    var collabCampaigns: [Campaign]

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
        self.ownedCampaigns = []
        self.collabCampaigns = []
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
