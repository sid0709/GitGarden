import Foundation

nonisolated enum YAMLValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case list([YAMLValue])
    case map([String: YAMLValue])
    case null

    var string: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    var int: Int? {
        switch self {
        case .int(let value): return value
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var double: Double? {
        switch self {
        case .double(let value): return value
        case .int(let value): return Double(value)
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var list: [YAMLValue]? {
        if case .list(let value) = self { return value }
        return nil
    }

    var map: [String: YAMLValue]? {
        if case .map(let value) = self { return value }
        return nil
    }

    subscript(_ key: String) -> YAMLValue? {
        map?[key]
    }
}

nonisolated enum SimpleYAML {
    static func parse(_ text: String) throws -> YAMLValue {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var index = 0
        return try parseBlock(lines: lines, index: &index, indent: 0)
    }

    private static func parseBlock(lines: [String], index: inout Int, indent: Int) throws -> YAMLValue {
        skipEmpty(lines: lines, index: &index)
        guard index < lines.count else { return .map([:]) }
        let current = stripped(lines[index])
        if current.trimmed.hasPrefix("- ") || current.trimmed == "-" {
            return try parseList(lines: lines, index: &index, indent: indent)
        }
        return try parseMap(lines: lines, index: &index, indent: indent)
    }

    private static func parseMap(lines: [String], index: inout Int, indent: Int) throws -> YAMLValue {
        var result: [String: YAMLValue] = [:]
        while index < lines.count {
            let raw = lines[index]
            if raw.trimmingCharacters(in: .whitespaces).isEmpty || raw.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                index += 1
                continue
            }
            let info = stripped(raw)
            if info.indent < indent { break }
            if info.indent > indent && indent > 0 { break }
            if info.trimmed.hasPrefix("- ") { break }
            guard let colon = info.trimmed.firstIndex(of: ":") else {
                throw GitGardenError.api("Invalid YAML line: \(info.trimmed)")
            }
            let key = String(info.trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(info.trimmed[info.trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            index += 1
            if rest.isEmpty {
                skipEmpty(lines: lines, index: &index)
                if index < lines.count {
                    let next = stripped(lines[index])
                    if next.indent > info.indent {
                        result[key] = try parseBlock(lines: lines, index: &index, indent: next.indent)
                        continue
                    }
                }
                result[key] = .null
            } else if rest.hasPrefix("[") && rest.hasSuffix("]") {
                result[key] = parseFlowList(String(rest.dropFirst().dropLast()))
            } else {
                result[key] = scalar(rest)
            }
        }
        return .map(result)
    }

    private static func parseList(lines: [String], index: inout Int, indent: Int) throws -> YAMLValue {
        var items: [YAMLValue] = []
        while index < lines.count {
            let raw = lines[index]
            if raw.trimmingCharacters(in: .whitespaces).isEmpty || raw.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                index += 1
                continue
            }
            let info = stripped(raw)
            if info.indent < indent { break }
            if !info.trimmed.hasPrefix("- ") && info.trimmed != "-" { break }
            let rest = info.trimmed.hasPrefix("- ") ? String(info.trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces) : ""
            index += 1
            if rest.isEmpty {
                skipEmpty(lines: lines, index: &index)
                if index < lines.count {
                    let next = stripped(lines[index])
                    items.append(try parseBlock(lines: lines, index: &index, indent: max(next.indent, indent + 2)))
                } else {
                    items.append(.null)
                }
            } else if rest.hasPrefix("\"") || rest.hasPrefix("'") {
                items.append(scalar(rest))
            } else if isBareMapItem(rest) {
                var synthetic = ["\(String(repeating: " ", count: info.indent + 2))\(rest)"]
                while index < lines.count {
                    let peek = stripped(lines[index])
                    if peek.indent > info.indent && !peek.trimmed.hasPrefix("- ") {
                        synthetic.append(lines[index])
                        index += 1
                    } else {
                        break
                    }
                }
                var nestedIndex = 0
                items.append(try parseMap(lines: synthetic, index: &nestedIndex, indent: info.indent + 2))
            } else {
                items.append(scalar(rest))
            }
        }
        return .list(items)
    }

    private static func isBareMapItem(_ rest: String) -> Bool {
        guard let colon = rest.firstIndex(of: ":") else { return false }
        let key = rest[..<colon].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return false }
        return key.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    private static func parseFlowList(_ raw: String) -> YAMLValue {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return .list(parts.map(scalar))
    }

    private static func scalar(_ raw: String) -> YAMLValue {
        var text = raw
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2 {
            text = String(text.dropFirst().dropLast())
            return .string(text)
        }
        if text.hasPrefix("'") && text.hasSuffix("'") && text.count >= 2 {
            text = String(text.dropFirst().dropLast())
            return .string(text)
        }
        if text == "true" { return .bool(true) }
        if text == "false" { return .bool(false) }
        if text == "null" || text == "~" { return .null }
        if let int = Int(text) { return .int(int) }
        if let double = Double(text) { return .double(double) }
        return .string(text)
    }

    private static func skipEmpty(lines: [String], index: inout Int) {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
            } else {
                break
            }
        }
    }

    private static func stripped(_ line: String) -> (indent: Int, trimmed: String) {
        var indent = 0
        for ch in line {
            if ch == " " { indent += 1 }
            else if ch == "\t" { indent += 2 }
            else { break }
        }
        return (indent, line.trimmingCharacters(in: .whitespaces))
    }
}
