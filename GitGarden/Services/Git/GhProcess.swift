import Foundation

nonisolated protocol GhRunning: Sendable {
    @discardableResult
    func run(in directory: URL?, _ args: [String], env: [String: String]) throws -> String
}

nonisolated struct GhProcess: GhRunning {
    func run(in directory: URL?, _ args: [String], env: [String: String] = [:]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try Self.executablePath())
        process.arguments = args
        if let directory {
            process.currentDirectoryURL = directory
        }
        var environment = ProcessInfo.processInfo.environment
        let path = environment["PATH"] ?? ""
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + path
        environment["GH_PROMPT"] = "never"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        for (key, value) in env {
            environment[key] = value
        }
        process.environment = environment
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw GitGardenError.gitFailed(TokenRedactor.redact(err.isEmpty ? out : err))
        }
        return TokenRedactor.redact(out)
    }

    static func executablePath() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh"
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        throw GitGardenError.gitFailed("GitHub CLI (`gh`) is not installed. Install it with `brew install gh`.")
    }
}

nonisolated struct GitHubCLI: Sendable {
    var gh: any GhRunning
    var token: String

    init(token: String, gh: any GhRunning = GhProcess()) {
        self.token = token
        self.gh = gh
    }

    private var env: [String: String] {
        ["GH_TOKEN": token, "GITHUB_TOKEN": token]
    }

    @discardableResult
    private func run(in directory: URL? = nil, _ args: [String]) throws -> String {
        try gh.run(in: directory, args, env: env)
    }

    func clone(owner: String, repo: String, to destination: URL) throws {
        _ = try run(["repo", "clone", "\(owner)/\(repo)", destination.path])
    }

    func closePull(owner: String, repo: String, number: Int) throws {
        _ = try run(["pr", "close", "\(number)", "--repo", "\(owner)/\(repo)"])
    }

    func inviteCollaborator(owner: String, repo: String, username: String) throws {
        _ = try run([
            "api", "-X", "PUT",
            "repos/\(owner)/\(repo)/collaborators/\(username)",
            "-f", "permission=push"
        ])
    }

    func createIssue(owner: String, repo: String, title: String, body: String) throws -> (number: Int, url: String) {
        var args = ["issue", "create", "--repo", "\(owner)/\(repo)", "--title", title]
        if !body.isEmpty { args += ["--body", body] }
        let output = try run(args)
        let url = GhOutput.firstURL(in: output) ?? "https://github.com/\(owner)/\(repo)/issues"
        return (GhOutput.resourceNumber(in: url) ?? 1, url)
    }

    func commentIssue(owner: String, repo: String, number: Int, body: String) throws {
        _ = try run(["issue", "comment", "\(number)", "--repo", "\(owner)/\(repo)", "--body", body])
    }

    func closeIssue(owner: String, repo: String, number: Int) throws {
        _ = try run(["issue", "close", "\(number)", "--repo", "\(owner)/\(repo)"])
    }

    func createPull(owner: String, repo: String, title: String, body: String, head: String, base: String) throws -> (number: Int, url: String) {
        var args = [
            "pr", "create",
            "--repo", "\(owner)/\(repo)",
            "--title", title,
            "--head", head,
            "--base", base
        ]
        if !body.isEmpty { args += ["--body", body] }
        let output = try run(args)
        let url = GhOutput.firstURL(in: output) ?? "https://github.com/\(owner)/\(repo)/pull/\(head)"
        return (GhOutput.resourceNumber(in: url) ?? 1, url)
    }

    func reviewPull(owner: String, repo: String, number: Int, body: String) throws {
        var args = ["pr", "review", "\(number)", "--repo", "\(owner)/\(repo)", "--comment"]
        if !body.isEmpty { args += ["--body", body] }
        _ = try run(args)
    }

    func mergePull(owner: String, repo: String, number: Int) throws {
        _ = try run(["pr", "merge", "\(number)", "--repo", "\(owner)/\(repo)", "--squash"])
    }

    func createRelease(owner: String, repo: String, tag: String, name: String, body: String) throws -> String {
        var args = ["release", "create", tag, "--repo", "\(owner)/\(repo)", "--title", name]
        if !body.isEmpty { args += ["--notes", body] }
        let output = try run(args)
        return GhOutput.firstURL(in: output) ?? "https://github.com/\(owner)/\(repo)/releases/tag/\(tag)"
    }

    func patchProfile(bio: String?, name: String?) throws {
        var args = ["api", "-X", "PATCH", "user"]
        if let bio { args += ["-f", "bio=\(bio)"] }
        if let name { args += ["-f", "name=\(name)"] }
        _ = try run(args)
    }

    func follow(username: String) throws {
        _ = try run(["api", "-X", "PUT", "user/following/\(username)", "-i"])
    }

    func star(owner: String, repo: String) throws {
        _ = try run(["api", "-X", "PUT", "user/starred/\(owner)/\(repo)", "-i"])
    }
}

nonisolated enum GhOutput {
    static func firstURL(in text: String) -> String? {
        let pattern = #"https://github\.com/[^\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else { return nil }
        return String(text[swiftRange]).trimmingCharacters(in: CharacterSet(charactersIn: ".,);'\""))
    }

    static func resourceNumber(in url: String) -> Int? {
        let parts = url.split(separator: "/").map(String.init)
        if let last = parts.last, let number = Int(last) { return number }
        return nil
    }

    static func alreadyExists(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.contains("already exists") || lowered.contains("name already exists")
    }
}
