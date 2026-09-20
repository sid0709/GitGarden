import Foundation

nonisolated protocol GitRunning: Sendable {
    @discardableResult
    func run(in directory: URL?, _ args: [String], env: [String: String]) throws -> String
}

nonisolated struct GitProcess: GitRunning {
    func run(in directory: URL?, _ args: [String], env: [String: String] = [:]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        if let directory {
            process.currentDirectoryURL = directory
        }
        var environment = ProcessInfo.processInfo.environment
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
}

nonisolated struct BackdatedCommitEngine: Sendable {
    var git: any GitRunning
    var fileManager: FileManager = .default

    init(git: any GitRunning = GitProcess()) {
        self.git = git
    }

    func prepareWorktree(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.appendingPathComponent(".git").path) {
            try git.run(in: url, ["init", "-b", "main"], env: [:])
        }
    }

    func configureIdentity(at url: URL, name: String, email: String) throws {
        try git.run(in: url, ["config", "user.name", name], env: [:])
        try git.run(in: url, ["config", "user.email", email], env: [:])
    }

    func writeFiles(at url: URL, files: [FileChange]) throws {
        for file in files {
            let target = url.appendingPathComponent(file.path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try file.content.data(using: .utf8)?.write(to: target)
        }
    }

    func commit(at url: URL, message: String, date: Date, name: String, email: String) throws {
        try git.run(in: url, ["add", "-A"], env: [:])
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let stamp = iso.string(from: date)
        try git.run(
            in: url,
            ["commit", "--allow-empty", "-m", message],
            env: [
                "GIT_AUTHOR_DATE": stamp,
                "GIT_COMMITTER_DATE": stamp,
                "GIT_AUTHOR_NAME": name,
                "GIT_AUTHOR_EMAIL": email,
                "GIT_COMMITTER_NAME": name,
                "GIT_COMMITTER_EMAIL": email
            ]
        )
    }

    func checkoutBranch(at url: URL, name: String) throws {
        let existing = (try? git.run(in: url, ["branch", "--list", name], env: [:])) ?? ""
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try git.run(in: url, ["checkout", "-b", name], env: [:])
        } else {
            _ = try git.run(in: url, ["checkout", name], env: [:])
        }
    }

    func checkoutMain(at url: URL, named name: String = "main") throws {
        var seen = Set<String>()
        let candidates = [name, "main", "master"].filter { seen.insert($0).inserted }
        for branch in candidates {
            if (try? git.run(in: url, ["rev-parse", "--verify", branch], env: [:])) != nil {
                _ = try git.run(in: url, ["checkout", branch], env: [:])
                return
            }
        }
        _ = try git.run(in: url, ["checkout", "-B", name], env: [:])
    }

    func ensureExistingClone(at url: URL, owner: String, repo: String, token: String, gh: GitHubCLI) throws {
        let gitDir = url.appendingPathComponent(".git")
        if fileManager.fileExists(atPath: gitDir.path) {
            try ensureRemote(at: url, owner: owner, repo: repo, token: token)
            return
        }
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: url.path) {
            let items = (try? fileManager.contentsOfDirectory(atPath: url.path)) ?? []
            if items.isEmpty {
                try fileManager.removeItem(at: url)
            } else {
                throw GitGardenError.gitFailed("Worktree \(url.path) is not empty and is not a git clone of \(owner)/\(repo).")
            }
        }
        do {
            try gh.clone(owner: owner, repo: repo, to: url)
        } catch {
            try prepareWorktree(at: url)
        }
        if !fileManager.fileExists(atPath: gitDir.path) {
            try prepareWorktree(at: url)
        }
        try ensureRemote(at: url, owner: owner, repo: repo, token: token)
        if (try? git.run(in: url, ["rev-parse", "--verify", "HEAD"], env: [:])) == nil {
            _ = try git.run(in: url, ["checkout", "-B", "main"], env: [:])
        }
    }

    func ensureRemote(at url: URL, owner: String, repo: String, token: String) throws {
        let remoteURL = "https://x-access-token:\(token)@github.com/\(owner)/\(repo).git"
        let remotes = (try? git.run(in: url, ["remote"], env: [:])) ?? ""
        if remotes.split(separator: "\n").map(String.init).contains("origin") {
            _ = try git.run(in: url, ["remote", "set-url", "origin", remoteURL], env: [:])
        } else {
            _ = try git.run(in: url, ["remote", "add", "origin", remoteURL], env: [:])
        }
    }

    func push(at url: URL, branch: String) throws {
        _ = try git.run(in: url, ["push", "-u", "origin", "HEAD:refs/heads/\(branch)"], env: [:])
    }

    func pullMain(at url: URL) throws {
        _ = try git.run(in: url, ["checkout", "main"], env: [:])
        _ = try git.run(in: url, ["pull", "origin", "main"], env: [:])
    }
}
