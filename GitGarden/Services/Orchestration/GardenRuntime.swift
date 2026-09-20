import Foundation
import SwiftData

@Observable
final class GardenRuntime {
    let modelContainer: ModelContainer
    private var clients: [String: GitHubClient] = [:]
    private var accountTasks: [String: Task<Void, Never>] = [:]
    private var runningLogins: Set<String> = []
    private var timer: Timer?
    private var background: NSBackgroundActivityScheduler?
    var lastTick: Date = .distantPast
    var nextFire: Date?
    var heatmaps: [String: [HeatmapDay]] = [:]
    var repositories: [String: [GitHubRepo]] = [:]
    var organizations: [String: [GitHubOrg]] = [:]
    var heatmapLoading: Set<String> = []

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func start() {
        seedDefaults()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.processDueJobs()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
        let activity = NSBackgroundActivityScheduler(identifier: "com.sidgroup.GitGarden.drip")
        activity.repeats = true
        activity.interval = 15
        activity.schedule { [weak self] completion in
            Task { @MainActor [weak self] in
                self?.processDueJobs()
                completion(.finished)
            }
        }
        background = activity
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        background?.invalidate()
        background = nil
    }

    var context: ModelContext { modelContainer.mainContext }

    func settings() -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }

    func seedDefaults() {
        let settings = settings()
        if settings.defaultHistoryYears < 1 {
            settings.defaultHistoryYears = 10
            settings.defaultDryRun = false
        }
        let existing = (try? context.fetch(FetchDescriptor<PersonaRecord>())) ?? []
        let ids = Set(existing.map(\.personaID))
        for item in PersonaCatalog.bundledYAML where !ids.contains(item.id) {
            let body: String
            if let url = Bundle.main.url(forResource: item.id, withExtension: "yaml"),
               let text = try? String(contentsOf: url, encoding: .utf8),
               !text.isEmpty {
                body = text
            } else {
                body = item.body
            }
            context.insert(PersonaRecord(personaID: item.id, name: item.name, yamlBody: body, isBundled: true))
        }
        try? context.save()
    }

    func persona(for id: String) -> Persona {
        let records = (try? context.fetch(FetchDescriptor<PersonaRecord>())) ?? []
        if let record = records.first(where: { $0.personaID == id }) {
            return PersonaLoader.load(from: record.yamlBody)
        }
        return PersonaLoader.bundled().first(where: { $0.id == id }) ?? .rustaceanFallback
    }

    func client(for account: Account) -> GitHubClient {
        if let existing = clients[account.login] {
            return existing
        }
        let created = GitHubClient(token: account.token, loginHint: account.login)
        clients[account.login] = created
        return created
    }

    func validate(account: Account) async throws {
        let client = client(for: account)
        let result = try await client.validateToken()
        account.apply(user: result.user)
        account.scopes = result.scopes
        account.rateLimitRemaining = result.rateLimit.remaining
        account.rateLimitLimit = result.rateLimit.limit
        account.rateLimitReset = result.rateLimit.reset
        account.lastValidatedAt = Date()
        if let emails = try? await client.fetchEmails(), let primary = emails.first(where: \.primary) ?? emails.first {
            account.email = primary.email
        } else if let email = result.user.email {
            account.email = email
        }
        try context.save()
        audit(
            account: account.login,
            method: "GET",
            path: "/user",
            status: 200,
            message: "validated \(account.login)"
        )
    }

    func addAccount(token: String, personaID: String) async throws -> Account {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitGardenError.invalidToken }
        let client = GitHubClient(token: trimmed, loginHint: "")
        let result = try await client.validateToken()
        if let existing = ((try? context.fetch(FetchDescriptor<Account>())) ?? []).first(where: { $0.login == result.user.login }) {
            existing.token = trimmed
            existing.scopes = result.scopes
            clients[existing.login] = GitHubClient(token: trimmed, loginHint: existing.login)
            try await validate(account: existing)
            await loadHeatmap(for: existing)
            return existing
        }
        let account = Account(
            login: result.user.login,
            name: result.user.name ?? "",
            avatarURL: result.user.avatarUrl ?? "",
            token: trimmed,
            scopes: result.scopes,
            rateLimitRemaining: result.rateLimit.remaining,
            rateLimitLimit: result.rateLimit.limit,
            rateLimitReset: result.rateLimit.reset,
            personaID: personaID
        )
        context.insert(account)
        clients[account.login] = GitHubClient(token: trimmed, loginHint: account.login)
        try await validate(account: account)
        await loadHeatmap(for: account)
        return account
    }

    func generatePlan(for campaign: Campaign) throws {
        guard let owner = campaign.owner else { throw GitGardenError.missingAccount }
        if campaign.status == .running {
            pauseCampaign(campaign)
        }
        guard let ref = RepoRef.parse(campaign.repoName, defaultOwner: owner.login) else {
            throw GitGardenError.missingRepo
        }
        campaign.repoName = ref.name
        let persona = persona(for: campaign.personaID)
        let match = owner.cachedRepos.first {
            $0.name.caseInsensitiveCompare(ref.name) == .orderedSame
        }
        let defaultBranch: String
        if let match, (match.size ?? 0) > 0, let branch = match.defaultBranch, !branch.isEmpty {
            defaultBranch = branch
        } else {
            defaultBranch = "main"
        }
        let input = PlannerInput(
            ownerLogin: owner.login,
            ownerName: owner.name,
            ownerEmail: owner.email.isEmpty ? "\(owner.login)@users.noreply.github.com" : owner.email,
            collaboratorLogin: campaign.collaborator?.login,
            repoName: ref.name,
            repoOwner: ref.owner,
            defaultBranch: defaultBranch,
            repoDescription: campaign.repoDescription.isEmpty ? campaign.name : campaign.repoDescription,
            start: campaign.startDate,
            end: campaign.endDate,
            commitCount: campaign.commitCount,
            prCount: campaign.prCount,
            issueCount: campaign.issueCount,
            includeHistory: campaign.includeHistory,
            includePRs: campaign.includePRs,
            includeIssues: campaign.includeIssues,
            includeProfile: campaign.includeProfile,
            includeSocial: campaign.includeSocial,
            dripMode: campaign.dripMode,
            dripInterval: campaign.dripInterval,
            persona: persona,
            seed: UInt64(bitPattern: campaign.seed),
            language: campaign.language
        )
        let plan = Planner().build(input)
        campaign.plan = plan
        campaign.status = .planned
        campaign.updatedAt = Date()
        campaign.jobs.forEach { context.delete($0) }
        campaign.jobs = []
        for (index, step) in plan.steps.enumerated() {
            let job = Job(step: step, orderIndex: index, campaign: campaign)
            context.insert(job)
        }
        try context.save()
    }

    func missingScopeWarnings(for campaign: Campaign) -> [String] {
        guard let plan = campaign.plan else { return [] }
        var warnings: [String] = []
        let accounts = [campaign.owner, campaign.collaborator].compactMap { $0 }
        for account in accounts {
            let kinds = plan.steps.filter { $0.accountLogin == account.login }.map(\.kind)
            for scope in account.missingScopes(for: kinds) {
                warnings.append("\(account.login) is missing `\(scope)`")
            }
        }
        return warnings
    }

    func startCampaign(_ campaign: Campaign, live: Bool) throws {
        guard campaign.plan != nil else { throw GitGardenError.planMissing }
        if campaign.status == .running {
            for login in campaign.involvedLogins {
                accountTasks[login]?.cancel()
                accountTasks[login] = nil
                runningLogins.remove(login)
            }
        }
        try ConflictGuard.assertCanRun(campaign, context: context, runningLogins: runningLogins)
        if campaign.jobs.isEmpty {
            try generatePlan(for: campaign)
        }
        let switchingToLive = live && campaign.dryRun
        let replay = campaign.jobs.allSatisfy {
            $0.status == .completed || $0.status == .skipped || $0.status == .failed || $0.status == .cancelled
        }
        if switchingToLive || replay {
            for job in campaign.jobs {
                job.status = .pending
                job.lastError = ""
                job.attempt = 0
                job.completedAt = nil
            }
        } else {
            for job in campaign.jobs where job.status == .failed || job.status == .cancelled {
                job.status = .pending
                job.lastError = ""
            }
        }
        snapshot(campaign, phase: live ? "before" : "before-dry")
        campaign.dryRun = !live
        campaign.status = .running
        campaign.lastError = ""
        campaign.updatedAt = Date()
        discardCreateRepoJobs(on: campaign)
        try context.save()
        processDueJobs()
    }

    func retryJob(_ job: Job) throws {
        guard let campaign = job.campaign else { return }
        if job.kind == .createRepo {
            skipJob(job)
            return
        }
        try ConflictGuard.assertCanRun(campaign, context: context, runningLogins: runningLogins)
        job.status = .pending
        job.lastError = ""
        job.attempt = 0
        campaign.status = .running
        campaign.lastError = ""
        try context.save()
        processDueJobs()
    }

    func skipJob(_ job: Job) {
        job.status = .skipped
        job.completedAt = Date()
        try? context.save()
        processDueJobs()
    }

    func retryCampaign(_ campaign: Campaign) throws {
        try ConflictGuard.assertCanRun(campaign, context: context, runningLogins: runningLogins)
        for job in campaign.jobs where job.status == .failed || job.status == .cancelled {
            job.status = .pending
            job.lastError = ""
        }
        campaign.status = .running
        campaign.lastError = ""
        discardCreateRepoJobs(on: campaign)
        try context.save()
        processDueJobs()
    }

    func deleteCampaign(_ campaign: Campaign) {
        pauseCampaign(campaign)
        context.delete(campaign)
        try? context.save()
    }

    func clearGitGardenWork() throws {
        for login in Array(accountTasks.keys) {
            accountTasks[login]?.cancel()
            accountTasks[login] = nil
        }
        runningLogins.removeAll()
        nextFire = nil
        heatmaps.removeAll()
        repositories.removeAll()
        organizations.removeAll()
        heatmapLoading.removeAll()

        for campaign in ((try? context.fetch(FetchDescriptor<Campaign>())) ?? []) {
            context.delete(campaign)
        }
        for event in ((try? context.fetch(FetchDescriptor<AuditEvent>())) ?? []) {
            context.delete(event)
        }
        for job in ((try? context.fetch(FetchDescriptor<Job>())) ?? []) {
            context.delete(job)
        }
        for resource in ((try? context.fetch(FetchDescriptor<CreatedResource>())) ?? []) {
            context.delete(resource)
        }
        for snapshot in ((try? context.fetch(FetchDescriptor<CampaignSnapshot>())) ?? []) {
            context.delete(snapshot)
        }
        for account in ((try? context.fetch(FetchDescriptor<Account>())) ?? []) {
            account.heatmapJSON = nil
            account.reposJSON = nil
            account.orgsJSON = nil
        }
        try context.save()

        let root = settings().resolvedWorktreePath
        if let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            for child in children {
                try? FileManager.default.removeItem(at: child)
            }
        }
    }

    func deleteAccount(_ account: Account) throws {
        let running = account.ownedCampaigns.contains { $0.status == .running } || account.collabCampaigns.contains { $0.status == .running }
        if running {
            throw GitGardenError.conflict("Pause running campaigns before removing @\(account.login).")
        }
        clients[account.login] = nil
        heatmaps[account.login] = nil
        repositories[account.login] = nil
        organizations[account.login] = nil
        context.delete(account)
        try context.save()
    }

    func validateAllAccounts() async {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for account in accounts where !account.token.isEmpty {
            try? await validate(account: account)
            await loadHeatmap(for: account)
        }
    }

    func loadHeatmap(for account: Account) async {
        heatmapLoading.insert(account.login)
        defer { heatmapLoading.remove(account.login) }
        if heatmaps[account.login] == nil, !account.cachedHeatmap.isEmpty {
            heatmaps[account.login] = account.cachedHeatmap
        }
        if repositories[account.login] == nil, !account.cachedRepos.isEmpty {
            repositories[account.login] = account.cachedRepos
        }
        if organizations[account.login] == nil, !account.cachedOrgs.isEmpty {
            organizations[account.login] = account.cachedOrgs
        }
        let githubLaunch = GitHubDate.parse("2008-04-01T00:00:00Z") ?? Date(timeIntervalSince1970: 1_207_008_000)
        let to = Date()
        let from = account.githubCreatedAt ?? githubLaunch
        let client = client(for: account)
        async let history = client.fetchContributionHistory(login: account.login, from: from, to: to)
        async let repoList = client.fetchRepos()
        async let orgList = client.fetchOrgs()
        if let days = try? await history, !days.isEmpty {
            heatmaps[account.login] = days
            account.cachedHeatmap = days
        }
        if let repos = try? await repoList {
            repositories[account.login] = repos
            account.cachedRepos = repos
            if account.publicRepos == 0 && account.totalPrivateRepos == 0 {
                account.publicRepos = repos.filter { !$0.private }.count
                account.totalPrivateRepos = repos.filter { $0.private }.count
            }
        }
        if let orgs = try? await orgList {
            organizations[account.login] = orgs
            account.cachedOrgs = orgs
        }
        account.rateLimitRemaining = await client.lastRateLimit.remaining
        account.rateLimitLimit = max(account.rateLimitLimit, await client.lastRateLimit.limit)
        try? context.save()
    }

    func pauseCampaign(_ campaign: Campaign) {
        campaign.status = .paused
        campaign.updatedAt = Date()
        try? context.save()
        for login in campaign.involvedLogins {
            accountTasks[login]?.cancel()
            runningLogins.remove(login)
        }
    }

    func resumeCampaign(_ campaign: Campaign) throws {
        try ConflictGuard.assertCanRun(campaign, context: context, runningLogins: runningLogins)
        campaign.status = .running
        campaign.updatedAt = Date()
        discardCreateRepoJobs(on: campaign)
        try context.save()
        processDueJobs()
    }

    func processDueJobs() {
        lastTick = Date()
        for campaign in ((try? context.fetch(FetchDescriptor<Campaign>())) ?? []) {
            discardCreateRepoJobs(on: campaign)
        }
        let campaigns = ((try? context.fetch(FetchDescriptor<Campaign>())) ?? []).filter { $0.status == .running }
        let dueLogins = Set(campaigns.flatMap(\.involvedLogins))
        nextFire = campaigns
            .flatMap(\.jobs)
            .filter { $0.status == .pending }
            .map(\.scheduledAt)
            .min()
        for login in dueLogins {
            kickAccount(login)
        }
        for campaign in campaigns {
            let remaining = campaign.jobs.filter { $0.status == .pending || $0.status == .running }
            if remaining.isEmpty {
                campaign.status = campaign.jobs.contains(where: { $0.status == .failed }) ? .failed : .completed
                snapshot(campaign, phase: "after")
            }
        }
        try? context.save()
    }

    private func kickAccount(_ login: String) {
        if accountTasks[login] != nil { return }
        let task = Task { @MainActor [weak self] in
            await self?.drain(login: login)
            self?.accountTasks[login] = nil
            self?.runningLogins.remove(login)
        }
        accountTasks[login] = task
    }

    private func drain(login: String) async {
        runningLogins.insert(login)
        while !Task.isCancelled {
            guard let job = nextJob(for: login) else { break }
            guard let campaign = job.campaign, campaign.status == .running else { break }
            if job.scheduledAt > Date() {
                nextFire = job.scheduledAt
                break
            }
            if job.kind == .createRepo {
                job.status = .skipped
                job.completedAt = Date()
                job.lastError = ""
                try? context.save()
                continue
            }
            job.status = .running
            job.attempt += 1
            try? context.save()
            do {
                try await execute(job: job)
                job.status = .completed
                job.completedAt = Date()
                job.lastError = ""
            } catch {
                job.status = .failed
                job.lastError = TokenRedactor.redact(error.localizedDescription)
                campaign.status = .failed
                campaign.lastError = job.lastError
            }
            try? context.save()
            if campaign.status != .running { break }
        }
    }

    private func nextJob(for login: String) -> Job? {
        let campaigns = ((try? context.fetch(FetchDescriptor<Campaign>())) ?? []).filter { $0.status == .running }
        let jobs = campaigns
            .flatMap(\.jobs)
            .filter { $0.accountLogin == login && $0.status == .pending }
            .sorted { lhs, rhs in
                if lhs.scheduledAt != rhs.scheduledAt { return lhs.scheduledAt < rhs.scheduledAt }
                return lhs.orderIndex < rhs.orderIndex
            }
        return jobs.first
    }

    func worktree(for campaign: Campaign) -> URL {
        settings().resolvedWorktreePath.appendingPathComponent(campaign.workspaceID, isDirectory: true)
    }

    private func execute(job: Job) async throws {
        guard let campaign = job.campaign else { throw GitGardenError.planMissing }
        guard let account = account(named: job.accountLogin) else { throw GitGardenError.missingAccount }
        if campaign.dryRun {
            try await Task.sleep(nanoseconds: 50_000_000)
            audit(
                account: account.login,
                method: job.kind == .commit || job.kind == .push || job.kind == .createBranch ? "GIT" : "DRY",
                path: job.kind.title,
                status: 0,
                campaign: campaign.name,
                message: "simulated \(job.summary)"
            )
            return
        }
        let gh = GitHubCLI(token: account.token)
        let payload = job.payload
        let ref = RepoRef.parse(
            payload.repo ?? campaign.repoName,
            defaultOwner: payload.owner ?? campaign.owner?.login ?? account.login
        )
        let owner = ref?.owner ?? payload.owner ?? campaign.owner?.login ?? account.login
        let repo = ref?.name ?? payload.repo ?? campaign.repoName
        let git = BackdatedCommitEngine()
        let root = worktree(for: campaign)
        let base = payload.baseBranch ?? "main"

        func prepareClone() throws {
            try git.ensureExistingClone(at: root, owner: owner, repo: repo, token: account.token, gh: gh)
            try git.configureIdentity(
                at: root,
                name: account.name.isEmpty ? account.login : account.name,
                email: account.email.isEmpty ? "\(account.login)@users.noreply.github.com" : account.email
            )
        }

        switch job.kind {
        case .createRepo:
            return

        case .growHistory:
            try prepareClone()
            let dates = InnoHistory.commitDates(
                from: campaign.startDate,
                to: campaign.endDate,
                maxCommits: max(campaign.commitCount, 1),
                seed: UInt64(bitPattern: campaign.seed)
            )
            let author = payload.committerName ?? (account.name.isEmpty ? account.login : account.name)
            let email = payload.committerEmail ?? (account.email.isEmpty ? "\(account.login)@users.noreply.github.com" : account.email)
            let workURL = root
            try await Task.detached {
                try FakeHistoryEngine().apply(dates: dates, at: workURL, name: author, email: email)
            }.value
            audit(account: account.login, method: "GIT", path: "hello.txt history", status: 0, campaign: campaign.name, message: "\(dates.count) commits")

        case .inviteCollaborator:
            guard let username = payload.username else { return }
            try gh.inviteCollaborator(owner: owner, repo: repo, username: username)
            audit(account: account.login, method: "GH", path: "api repos/\(owner)/\(repo)/collaborators/\(username)", status: 0, campaign: campaign.name)

        case .commit:
            try prepareClone()
            if let branch = payload.branch, branch != base {
                try git.checkoutBranch(at: root, name: branch)
            } else {
                try? git.checkoutMain(at: root, named: base)
            }
            try git.writeFiles(at: root, files: payload.files ?? [])
            try git.commit(
                at: root,
                message: payload.message ?? job.summary,
                date: payload.authorDate ?? Date(),
                name: payload.committerName ?? account.name,
                email: payload.committerEmail ?? account.email
            )
            audit(account: account.login, method: "GIT", path: "commit", status: 0, campaign: campaign.name, message: job.summary)

        case .push:
            try prepareClone()
            try git.push(at: root, branch: payload.branch ?? base)
            audit(account: account.login, method: "GIT", path: "push", status: 0, campaign: campaign.name, message: payload.branch ?? base)

        case .createBranch:
            try prepareClone()
            try git.checkoutBranch(at: root, name: payload.branch ?? "feat/work")
            audit(account: account.login, method: "GIT", path: "checkout", status: 0, campaign: campaign.name, message: payload.branch ?? "")

        case .createIssue:
            let issue = try gh.createIssue(
                owner: owner,
                repo: repo,
                title: payload.title ?? "Issue",
                body: payload.body ?? ""
            )
            var updated = payload
            updated.issueNumber = issue.number
            job.payload = updated
            remapIssue(planNumber: payload.issueNumber, actual: issue.number, campaign: campaign)
            track(kind: .issue, owner: owner, name: repo, number: issue.number, remoteID: issue.number, url: issue.url, campaign: campaign)
            audit(account: account.login, method: "GH", path: "issue create \(owner)/\(repo)", status: 0, campaign: campaign.name, message: "#\(issue.number)")

        case .commentIssue:
            let number = resolvedIssue(payload.issueNumber, campaign: campaign)
            try gh.commentIssue(owner: owner, repo: repo, number: number, body: payload.body ?? "")
            audit(account: account.login, method: "GH", path: "issue comment \(number)", status: 0, campaign: campaign.name)

        case .closeIssue:
            let number = resolvedIssue(payload.issueNumber, campaign: campaign)
            try gh.closeIssue(owner: owner, repo: repo, number: number)
            audit(account: account.login, method: "GH", path: "issue close \(number)", status: 0, campaign: campaign.name)

        case .createPR:
            let pull = try gh.createPull(
                owner: owner,
                repo: repo,
                title: payload.title ?? "Update",
                body: payload.body ?? "",
                head: payload.branch ?? "feat/work",
                base: payload.baseBranch ?? base
            )
            var updated = payload
            updated.prNumber = pull.number
            job.payload = updated
            remapPR(branch: payload.branch ?? "", actual: pull.number, campaign: campaign)
            track(kind: .pullRequest, owner: owner, name: repo, number: pull.number, remoteID: pull.number, url: pull.url, campaign: campaign)
            audit(account: account.login, method: "GH", path: "pr create \(owner)/\(repo)", status: 0, campaign: campaign.name, message: "#\(pull.number)")

        case .reviewPR:
            let number = resolvedPR(payload.prNumber, branch: payload.branch, campaign: campaign)
            try gh.reviewPull(owner: owner, repo: repo, number: number, body: payload.body ?? "Looks good.")
            audit(account: account.login, method: "GH", path: "pr review \(number)", status: 0, campaign: campaign.name)

        case .mergePR:
            let number = resolvedPR(payload.prNumber, branch: payload.branch, campaign: campaign)
            try gh.mergePull(owner: owner, repo: repo, number: number)
            try? git.pullMain(at: root)
            audit(account: account.login, method: "GH", path: "pr merge \(number)", status: 0, campaign: campaign.name)

        case .createRelease:
            let url = try gh.createRelease(
                owner: owner,
                repo: repo,
                tag: payload.tag ?? "v0.1.0",
                name: payload.title ?? payload.tag ?? "v0.1.0",
                body: payload.body ?? ""
            )
            track(kind: .release, owner: owner, name: payload.tag ?? "v0.1.0", remoteID: 0, url: url, campaign: campaign)
            audit(account: account.login, method: "GH", path: "release create \(owner)/\(repo)", status: 0, campaign: campaign.name)

        case .patchProfile:
            try gh.patchProfile(bio: payload.bio, name: payload.committerName)
            audit(account: account.login, method: "GH", path: "api user", status: 0, campaign: campaign.name)

        case .follow:
            guard let username = payload.username else { return }
            try gh.follow(username: username)
            audit(account: account.login, method: "GH", path: "api user/following/\(username)", status: 0, campaign: campaign.name)

        case .star:
            try gh.star(owner: owner, repo: repo)
            audit(account: account.login, method: "GH", path: "api user/starred/\(owner)/\(repo)", status: 0, campaign: campaign.name)
        }
    }

    func nuke(_ campaign: Campaign) async throws {
        snapshot(campaign, phase: "before-nuke")
        campaign.status = .paused
        try? context.save()
        let resources = NukeOrder.sorted(campaign.resources)
        for resource in resources {
            guard let account = campaign.owner ?? account(named: resource.ownerLogin) else { continue }
            let gh = GitHubCLI(token: account.token)
            do {
                switch resource.kind {
                case .pullRequest:
                    try gh.closePull(owner: resource.ownerLogin, repo: resource.name, number: resource.number)
                    audit(account: account.login, method: "GH", path: "pr close \(resource.number)", status: 0, campaign: campaign.name, message: "close PR")
                case .issue:
                    try gh.closeIssue(owner: resource.ownerLogin, repo: resource.name, number: resource.number)
                    audit(account: account.login, method: "GH", path: "issue close \(resource.number)", status: 0, campaign: campaign.name, message: "close issue")
                case .release, .gist, .repo:
                    break
                }
            } catch {
                audit(account: account.login, method: "NUKE", path: resource.label, status: 500, campaign: campaign.name, message: error.localizedDescription)
            }
        }
        campaign.status = .nuked
        campaign.updatedAt = Date()
        snapshot(campaign, phase: "after-nuke")
        try context.save()
    }

    func refreshHeatmap(for campaign: Campaign) async {
        guard let owner = campaign.owner else { return }
        do {
            let days = try await client(for: owner).fetchContributionCalendar(
                login: owner.login,
                from: campaign.startDate,
                to: campaign.endDate
            )
            if var plan = campaign.plan {
                var planned: [String: Int] = [:]
                for day in plan.heatmap { planned[day.date] = day.planned }
                plan.heatmap = HeatmapBuilder.build(
                    dates: [],
                    existing: days
                )
                plan.heatmap = days.map { day in
                    HeatmapDay(date: day.date, existing: day.existing, planned: planned[day.date] ?? 0)
                }
                campaign.plan = plan
                try? context.save()
            }
        } catch {
            audit(account: owner.login, method: "POST", path: "/graphql", status: 500, campaign: campaign.name, message: error.localizedDescription)
        }
    }

    private func discardCreateRepoJobs(on campaign: Campaign) {
        var skippedFailedCreate = false
        for job in campaign.jobs where job.kind == .createRepo {
            if job.status == .failed { skippedFailedCreate = true }
            if job.status != .skipped {
                job.status = .skipped
                job.lastError = ""
                job.completedAt = Date()
            }
        }
        let otherFailures = campaign.jobs.contains { $0.kind != .createRepo && $0.status == .failed }
        if skippedFailedCreate, campaign.status == .failed, !otherFailures {
            campaign.status = .running
            campaign.lastError = ""
        }
    }

    private func account(named login: String) -> Account? {
        ((try? context.fetch(FetchDescriptor<Account>())) ?? []).first { $0.login == login }
    }

    private func track(kind: ResourceKind, owner: String, name: String, number: Int = 0, remoteID: Int, url: String, campaign: Campaign) {
        let resource = CreatedResource(kind: kind, ownerLogin: owner, name: name, number: number, remoteID: remoteID, url: url, campaign: campaign)
        context.insert(resource)
    }

    private func remapIssue(planNumber: Int?, actual: Int, campaign: Campaign) {
        guard let planNumber else { return }
        for job in campaign.jobs where job.payload.issueNumber == planNumber {
            var payload = job.payload
            payload.issueNumber = actual
            job.payload = payload
        }
    }

    private func remapPR(branch: String, actual: Int, campaign: Campaign) {
        for job in campaign.jobs {
            if job.payload.branch == branch && (job.kind == .reviewPR || job.kind == .mergePR || job.kind == .createPR) {
                var payload = job.payload
                payload.prNumber = actual
                job.payload = payload
            }
        }
    }

    private func resolvedIssue(_ number: Int?, campaign: Campaign) -> Int {
        number ?? campaign.resources.last(where: { $0.kind == .issue })?.number ?? 1
    }

    private func resolvedPR(_ number: Int?, branch: String?, campaign: Campaign) -> Int {
        if let number, number > 0 { return number }
        if let branch {
            if let match = campaign.jobs.first(where: { $0.kind == .createPR && $0.payload.branch == branch && ($0.payload.prNumber ?? 0) > 0 }) {
                return match.payload.prNumber ?? 1
            }
        }
        return campaign.resources.last(where: { $0.kind == .pullRequest })?.number ?? 1
    }

    func snapshot(_ campaign: Campaign, phase: String) {
        struct Shot: Codable {
            var name: String
            var status: String
            var resources: [String]
            var jobs: [String]
        }
        let shot = Shot(
            name: campaign.name,
            status: campaign.status.rawValue,
            resources: campaign.resources.map(\.label),
            jobs: campaign.jobs.map { "\($0.status.rawValue) \($0.summary)" }
        )
        let data = (try? JSONEncoder().encode(shot)) ?? Data()
        context.insert(CampaignSnapshot(phase: phase, json: data, campaign: campaign))
    }

    func audit(account: String, method: String, path: String, status: Int, retryAfter: TimeInterval = 0, campaign: String = "", message: String = "") {
        context.insert(
            AuditEvent(
                accountLogin: account,
                method: method,
                path: TokenRedactor.redact(path),
                statusCode: status,
                retryAfter: retryAfter,
                message: message,
                campaignName: campaign
            )
        )
    }
}

enum ConflictGuard {
    static func assertCanRun(_ campaign: Campaign, context: ModelContext, runningLogins: Set<String>) throws {
        let logins = Set(campaign.involvedLogins)
        if !runningLogins.isEmpty && !runningLogins.isDisjoint(with: logins) {
            throw GitGardenError.conflict("An account in this campaign is already running a job.")
        }
        let others = ((try? context.fetch(FetchDescriptor<Campaign>())) ?? []).filter {
            $0.status == .running && $0.persistentModelID != campaign.persistentModelID
        }
        for other in others {
            if !Set(other.involvedLogins).isDisjoint(with: logins) {
                throw GitGardenError.conflict("\(other.name) is already running against the same account.")
            }
        }
    }
}
