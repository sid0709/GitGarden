import Foundation
import SwiftData

@Model
final class CreatedResource {
    var kindRaw: String
    var ownerLogin: String
    var name: String
    var number: Int
    var remoteID: Int
    var url: String
    var createdAt: Date
    var campaign: Campaign?

    init(
        kind: ResourceKind,
        ownerLogin: String,
        name: String,
        number: Int = 0,
        remoteID: Int = 0,
        url: String = "",
        campaign: Campaign? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.ownerLogin = ownerLogin
        self.name = name
        self.number = number
        self.remoteID = remoteID
        self.url = url
        self.createdAt = Date()
        self.campaign = campaign
    }

    var kind: ResourceKind {
        ResourceKind(rawValue: kindRaw) ?? .repo
    }

    var label: String {
        switch kind {
        case .repo:
            return "\(ownerLogin)/\(name)"
        case .issue:
            return "Issue #\(number) in \(ownerLogin)/\(name)"
        case .pullRequest:
            return "PR #\(number) in \(ownerLogin)/\(name)"
        case .gist:
            return "Gist \(name)"
        case .release:
            return "Release \(name)"
        }
    }
}

enum NukeOrder {
    static func sorted(_ resources: [CreatedResource]) -> [CreatedResource] {
        let rank: [ResourceKind: Int] = [
            .gist: 0,
            .release: 1,
            .pullRequest: 2,
            .issue: 3,
            .repo: 4
        ]
        return resources.sorted { lhs, rhs in
            let left = rank[lhs.kind] ?? 99
            let right = rank[rhs.kind] ?? 99
            if left != right { return left < right }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
