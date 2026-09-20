import Foundation

nonisolated struct RateLimit: Sendable, Hashable {
    var remaining: Int
    var limit: Int
    var reset: Date?
    var retryAfter: TimeInterval?
    var resource: String

    static let unknown = RateLimit(remaining: 5000, limit: 5000, reset: nil, retryAfter: nil, resource: "core")

    var isExhausted: Bool {
        remaining <= 5
    }

    var waitInterval: TimeInterval {
        if let retryAfter, retryAfter > 0 { return retryAfter }
        if isExhausted, let reset {
            return max(0, reset.timeIntervalSinceNow)
        }
        return 0
    }

    static func parse(headers: [AnyHashable: Any]) -> RateLimit {
        func intValue(_ key: String) -> Int? {
            if let value = headers[key] as? String { return Int(value) }
            if let value = headers[AnyHashable(key)] as? String { return Int(value) }
            for (existing, raw) in headers {
                if String(describing: existing).lowercased() == key.lowercased() {
                    if let text = raw as? String { return Int(text) }
                    if let number = raw as? Int { return number }
                }
            }
            return nil
        }
        func stringValue(_ key: String) -> String? {
            if let value = headers[key] as? String { return value }
            for (existing, raw) in headers {
                if String(describing: existing).lowercased() == key.lowercased() {
                    return raw as? String
                }
            }
            return nil
        }

        let remaining = intValue("X-RateLimit-Remaining") ?? 5000
        let limit = intValue("X-RateLimit-Limit") ?? 5000
        let resetEpoch = intValue("X-RateLimit-Reset")
        let retry = TimeInterval(intValue("Retry-After") ?? 0)
        let reset = resetEpoch.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return RateLimit(
            remaining: remaining,
            limit: limit,
            reset: reset,
            retryAfter: retry > 0 ? retry : nil,
            resource: stringValue("X-RateLimit-Resource") ?? "core"
        )
    }

    static func parseClassicScopes(headers: [AnyHashable: Any]) -> [String] {
        var raw: String?
        for (existing, value) in headers {
            if String(describing: existing).lowercased() == "x-oauth-scopes" {
                raw = value as? String
                break
            }
        }
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
