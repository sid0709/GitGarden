import Testing
import Foundation
import SwiftData
@testable import GitGarden

struct GitGardenTests {
    @Test func cadenceRespectsCountAndOrder() {
        var rng = SeededGenerator(seed: 42)
        let persona = Persona.rustaceanFallback
        let sampler = CadenceSampler(timezone: persona.timezone)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(86400 * 400)
        let dates = sampler.sampleDates(count: 80, from: start, to: end, persona: persona, rng: &rng)
        #expect(dates.count == 80)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= start && $0 <= end.addingTimeInterval(86400) })
    }

    @Test func cadenceSkipsVacationWindow() {
        var rng = SeededGenerator(seed: 7)
        var persona = Persona.rustaceanFallback
        persona.vacationGaps = [VacationGap(start: "01-01", end: "12-31")]
        let sampler = CadenceSampler(timezone: "UTC")
        let start = Date(timeIntervalSince1970: 1_704_067_200)
        let dates = sampler.sampleDates(count: 10, from: start, to: start.addingTimeInterval(86400 * 10), persona: persona, rng: &rng)
        #expect(dates.isEmpty)
    }

    @Test func plannerBuildsCrossAccountIssueAndPRFlow() {
        let persona = PersonaLoader.load(from: PersonaCatalog.rustaceanYAML)
        let input = PlannerInput(
            ownerLogin: "alice",
            ownerName: "Alice",
            ownerEmail: "alice@users.noreply.github.com",
            collaboratorLogin: "bob",
            repoName: "gitgarden-test-demo",
            repoDescription: "demo",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_730_000_000),
            commitCount: 24,
            prCount: 3,
            issueCount: 4,
            includeHistory: true,
            includePRs: true,
            includeIssues: true,
            includeProfile: true,
            includeSocial: false,
            dripMode: false,
            dripInterval: 45,
            persona: persona,
            seed: 99,
            language: "rust"
        )
        let plan = Planner().build(input)
        #expect(plan.summary.commitCount == 24)
        #expect(!plan.steps.contains { $0.kind == .createRepo })
        #expect(plan.steps.contains { $0.kind == .commit })
        #expect(plan.steps.contains { $0.kind == .inviteCollaborator })
        #expect(plan.steps.contains { $0.kind == .createIssue })
        #expect(plan.steps.contains { $0.kind == .commentIssue })
        #expect(plan.steps.contains { $0.kind == .createPR })
        #expect(plan.steps.contains { $0.kind == .reviewPR })
        #expect(plan.steps.contains { $0.kind == .mergePR })
        #expect(plan.steps.contains { $0.kind == .patchProfile })
        #expect(!plan.steps.contains { $0.kind == .follow })
        let actors = Set(plan.steps.map(\.accountLogin))
        #expect(actors.contains("alice"))
        #expect(actors.contains("bob"))
        #expect(!plan.heatmap.isEmpty)
        let commits = plan.steps.filter { $0.kind == .commit }
        #expect(commits.allSatisfy { !($0.payload.files ?? []).isEmpty })
    }

    @Test func plannerSplitsHistoryIssuesAndPulls() {
        let persona = Persona.rustaceanFallback
        func base(history: Bool, prs: Bool, issues: Bool, commits: Int, prCount: Int, issueCount: Int) -> PlannerInput {
            PlannerInput(
                ownerLogin: "alice",
                ownerName: "Alice",
                ownerEmail: "a@x.com",
                collaboratorLogin: nil,
                repoName: "RepoPlay",
                repoDescription: "",
                start: Date(timeIntervalSince1970: 1_700_000_000),
                end: Date(timeIntervalSince1970: 1_710_000_000),
                commitCount: commits,
                prCount: prCount,
                issueCount: issueCount,
                includeHistory: history,
                includePRs: prs,
                includeIssues: issues,
                includeProfile: false,
                includeSocial: false,
                dripMode: false,
                dripInterval: 45,
                persona: persona,
                seed: 11,
                language: "rust"
            )
        }
        let history = Planner().build(base(history: true, prs: false, issues: false, commits: 8, prCount: 0, issueCount: 0))
        #expect(history.summary.commitCount == 8)
        #expect(history.summary.prCount == 0)
        #expect(history.summary.issueCount == 0)
        #expect(history.steps.contains { $0.kind == .growHistory })
        #expect(history.steps.contains { $0.kind == .push })
        #expect(!history.steps.contains { $0.kind == .commit || $0.kind == .createIssue || $0.kind == .createPR })

        let issues = Planner().build(base(history: false, prs: false, issues: true, commits: 0, prCount: 0, issueCount: 5))
        #expect(issues.summary.commitCount == 0)
        #expect(issues.summary.issueCount == 5)
        #expect(!issues.steps.contains { $0.kind == .commit || $0.kind == .createPR })

        let pulls = Planner().build(base(history: false, prs: true, issues: false, commits: 0, prCount: 3, issueCount: 0))
        #expect(pulls.summary.prCount >= 1)
        #expect(pulls.steps.contains { $0.kind == .commit })
        #expect(pulls.steps.contains { $0.kind == .createPR })
        #expect(!pulls.steps.contains { $0.kind == .createIssue })
    }

    @Test func innoHistoryWalksDaysAndCapsCommits() {
        let start = Date(timeIntervalSince1970: 1_577_836_800)
        let end = start.addingTimeInterval(86400 * 400)
        let dates = InnoHistory.commitDates(from: start, to: end, maxCommits: 40, seed: 7)
        #expect(dates.count == 40)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= start && $0 <= end.addingTimeInterval(86400) })
    }

    @Test func socialLayerIsOptIn() {
        var input = PlannerInput(
            ownerLogin: "alice",
            ownerName: "Alice",
            ownerEmail: "a@x.com",
            collaboratorLogin: "bob",
            repoName: "demo",
            repoDescription: "",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            end: Date(timeIntervalSince1970: 1_710_000_000),
            commitCount: 4,
            prCount: 0,
            issueCount: 0,
            includeHistory: true,
            includePRs: false,
            includeIssues: false,
            includeProfile: false,
            includeSocial: true,
            dripMode: true,
            dripInterval: 10,
            persona: .rustaceanFallback,
            seed: 3,
            language: "rust"
        )
        let on = Planner().build(input)
        #expect(on.summary.socialCount >= 2)
        input.includeSocial = false
        let off = Planner().build(input)
        #expect(off.summary.socialCount == 0)
        let intervals = zip(on.steps, on.steps.dropFirst()).map { $1.scheduledAt.timeIntervalSince($0.scheduledAt) }
        #expect(intervals.allSatisfy { $0 >= 9 })
    }

    @Test func rustMutatorProducesNonEmptyDiffs() {
        var rng = SeededGenerator(seed: 12)
        let mutator = CodeMutator()
        var state = mutator.seed(language: "rust", repoName: "garden-demo")
        let first = state.files
        let result = mutator.apply(state: state, slug: "parser", index: 0, persona: .rustaceanFallback, rng: &rng)
        #expect(result.state.files != first)
        #expect(!result.changedPaths.isEmpty)
        #expect(result.state.files["src/parser.rs"] != nil)
    }

    @Test func personaYAMLMintsUniqueIdentity() {
        #expect(PersonaYAML.uniqueName("Custom", existing: ["Custom", "Custom 2"]) == "Custom 3")
        #expect(PersonaYAML.uniqueID("rustacean-copy", existing: ["rustacean", "rustacean-copy"]) == "rustacean-copy-2")
        let patched = PersonaYAML.replacingIdentity(PersonaCatalog.rustaceanYAML, id: "night-owl", name: "Night Owl")
        #expect(patched.contains("id: night-owl"))
        #expect(patched.contains("name: Night Owl"))
    }

    @Test func yamlPersonaParse() throws {
        let value = try SimpleYAML.parse(PersonaCatalog.rustaceanYAML)
        let persona = Persona.from(yaml: value)
        #expect(persona.id == "rustacean")
        #expect(persona.language == "rust")
        #expect(persona.workingHours.start == 9)
        #expect(persona.messages.count >= 3)
        #expect(persona.branchPatterns.contains { $0.contains("{slug}") })
    }

    @Test func rateLimitHeaderParse() {
        let headers: [AnyHashable: Any] = [
            "X-RateLimit-Remaining": "42",
            "X-RateLimit-Limit": "5000",
            "X-RateLimit-Reset": "1700000000",
            "Retry-After": "8",
            "X-OAuth-Scopes": "repo, user, delete_repo"
        ]
        let limit = RateLimit.parse(headers: headers)
        #expect(limit.remaining == 42)
        #expect(limit.limit == 5000)
        #expect(limit.retryAfter == 8)
        let scopes = RateLimit.parseClassicScopes(headers: headers)
        #expect(scopes.contains("repo"))
        #expect(scopes.contains("delete_repo"))
    }

    @Test @MainActor func nukeOrdersRepoLast() {
        let issue = CreatedResource(kind: .issue, ownerLogin: "a", name: "r", number: 1)
        let repo = CreatedResource(kind: .repo, ownerLogin: "a", name: "r")
        let pull = CreatedResource(kind: .pullRequest, ownerLogin: "a", name: "r", number: 2)
        let ordered = NukeOrder.sorted([repo, issue, pull])
        #expect(ordered.map(\.kind) == [.pullRequest, .issue, .repo])
    }

    @Test func tokenRedactorScrubsPATs() {
        let raw = "https://x-access-token:ghp_abcdefghijklmnopqrstuvwxyz123456@github.com/a/b.git"
        let redacted = TokenRedactor.redact(raw)
        #expect(!redacted.contains("ghp_"))
        #expect(redacted.contains("[redacted"))
    }

    @Test func heatmapBuilderCountsDays() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let d1 = formatter.date(from: "2024-01-02")!
        let d2 = formatter.date(from: "2024-01-02")!
        let d3 = formatter.date(from: "2024-01-03")!
        let days = HeatmapBuilder.build(dates: [d1, d2, d3])
        #expect(days.first { $0.date == "2024-01-02" }?.planned == 2)
        #expect(days.first { $0.date == "2024-01-03" }?.planned == 1)
    }

    @Test func githubUserDecodesProfileFields() throws {
        let json = """
        {
          "login": "omnimu",
          "id": 42,
          "name": "Omni",
          "email": "a@x.com",
          "avatar_url": "https://example.com/a.png",
          "html_url": "https://github.com/omnimu",
          "bio": "hello",
          "company": "@acme",
          "location": "Chicago",
          "blog": "https://example.com",
          "twitter_username": "omni",
          "followers": 3,
          "following": 9,
          "public_repos": 12,
          "public_gists": 1,
          "total_private_repos": 4,
          "created_at": "2019-03-14T12:00:00Z",
          "updated_at": "2026-09-20T01:00:00Z",
          "two_factor_authentication": true,
          "plan": { "name": "free", "space": 1, "private_repos": 10000, "collaborators": 0 }
        }
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(GitHubUser.self, from: json)
        #expect(user.login == "omnimu")
        #expect(user.followers == 3)
        #expect(user.plan?.name == "free")
        #expect(GitHubDate.parse(user.createdAt) != nil)
    }

    @Test func contributionYearsCoverFullHistory() {
        let start = GitHubDate.parse("2019-03-14T00:00:00Z")!
        let end = GitHubDate.parse("2021-08-01T00:00:00Z")!
        let windows = GitHubDate.yearWindows(from: start, to: end)
        #expect(windows.count == 3)
        #expect(Calendar(identifier: .gregorian).component(.year, from: windows[0].from) == 2019)
        #expect(Calendar(identifier: .gregorian).component(.year, from: windows[2].to) == 2021)
        let days = [
            HeatmapDay(date: "2019-03-14", existing: 2, planned: 0),
            HeatmapDay(date: "2021-01-02", existing: 5, planned: 0)
        ]
        let groups = HeatmapYears.groups(from: days)
        #expect(groups.map(\.year) == [2021, 2019])
        #expect(groups.first?.total == 5)
    }

    @Test @MainActor func tenYearHistoryPresetsScale() {
        #expect(Campaign.suggestedCommitCount(forYears: 10) == 400)
        #expect(Campaign.suggestedPRCount(forYears: 10) == 30)
        #expect(Campaign.suggestedIssueCount(forYears: 10) == 40)
        let campaign = Campaign(name: "decade")
        campaign.endDate = Date(timeIntervalSince1970: 1_800_000_000)
        campaign.setHistoryYears(10)
        #expect(campaign.historyYears == 10)
        campaign.setHistoryYears(3)
        #expect(campaign.historyYears == 3)
    }

    @Test @MainActor func campaignPlanSkipAndDryRunControls() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        runtime.seedDefaults()
        let account = Account(login: "alice", name: "Alice", email: "a@x.com", token: "test")
        container.mainContext.insert(account)
        let campaign = Campaign(name: "dry then live", owner: account)
        campaign.includeHistory = true
        campaign.includePRs = false
        campaign.includeIssues = false
        campaign.includeProfile = false
        campaign.includeSocial = false
        campaign.commitCount = 3
        campaign.repoName = "demo"
        container.mainContext.insert(campaign)
        try runtime.generatePlan(for: campaign)
        #expect(!campaign.jobs.isEmpty)
        #expect(campaign.status == .planned)
        let first = campaign.jobs.sorted(by: { $0.orderIndex < $1.orderIndex }).first!
        runtime.skipJob(first)
        #expect(first.status == .skipped)
        try runtime.startCampaign(campaign, live: false)
        #expect(campaign.dryRun)
        #expect(campaign.status == .running)
        runtime.pauseCampaign(campaign)
        #expect(campaign.status == .paused)
        for job in campaign.jobs { job.status = .completed }
        try runtime.startCampaign(campaign, live: true)
        runtime.pauseCampaign(campaign)
        #expect(!campaign.dryRun)
        #expect(campaign.jobs.contains { $0.status == .pending })
    }

    @Test @MainActor func clearGitGardenWorkKeepsAccountsAndDropsCampaigns() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        runtime.seedDefaults()
        let account = Account(login: "alice", name: "Alice", email: "a@x.com", token: "test")
        account.heatmapJSON = Data("[]".utf8)
        container.mainContext.insert(account)
        let campaign = Campaign(name: "old run", owner: account)
        campaign.repoName = "RepoPlay"
        container.mainContext.insert(campaign)
        try runtime.generatePlan(for: campaign)
        container.mainContext.insert(AuditEvent(accountLogin: "alice", method: "GIT", path: "commit", statusCode: 0))
        runtime.heatmaps["alice"] = [HeatmapDay(date: "2017-01-01", existing: 1, planned: 0)]
        try runtime.clearGitGardenWork()
        let campaigns = try container.mainContext.fetch(FetchDescriptor<Campaign>())
        let jobs = try container.mainContext.fetch(FetchDescriptor<Job>())
        let events = try container.mainContext.fetch(FetchDescriptor<AuditEvent>())
        let accounts = try container.mainContext.fetch(FetchDescriptor<Account>())
        #expect(campaigns.isEmpty)
        #expect(jobs.isEmpty)
        #expect(events.isEmpty)
        #expect(accounts.map(\.login) == ["alice"])
        #expect(accounts.first?.heatmapJSON == nil)
        #expect(runtime.heatmaps.isEmpty)
    }

    @Test @MainActor func failedCreateRepoJobsAreSkippedAndNeverRetried() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        runtime.seedDefaults()
        let account = Account(login: "alice", name: "Alice", email: "a@x.com", token: "test")
        container.mainContext.insert(account)
        let campaign = Campaign(name: "existing repo only", owner: account)
        campaign.repoName = "RepoPlay"
        campaign.status = .failed
        container.mainContext.insert(campaign)
        let create = Job(
            step: PlanStep(
                id: "create",
                kind: .createRepo,
                accountLogin: "alice",
                scheduledAt: Date(),
                summary: "Create alice/RepoPlay",
                payload: StepPayload(repo: "RepoPlay", owner: "alice")
            ),
            orderIndex: 0,
            campaign: campaign
        )
        create.status = .failed
        create.lastError = "Rate limited on POST /user/repos"
        container.mainContext.insert(create)
        runtime.processDueJobs()
        #expect(create.status == .skipped)
        #expect(create.lastError.isEmpty)
        #expect(campaign.status != .failed)
    }

    @Test func repoRefParsesOwnerNameAndURL() {
        let slash = RepoRef.parse("omnimuh730/RepoPlay", defaultOwner: "alice")
        #expect(slash?.owner == "omnimuh730")
        #expect(slash?.name == "RepoPlay")
        let short = RepoRef.parse("RepoPlay", defaultOwner: "omnimuh730")
        #expect(short?.fullName == "omnimuh730/RepoPlay")
        let url = RepoRef.parse("https://github.com/omnimuh730/RepoPlay.git", defaultOwner: "alice")
        #expect(url?.fullName == "omnimuh730/RepoPlay")
        #expect(RepoRef.parse("  ", defaultOwner: "alice") == nil)
    }

    @Test func ghOutputParsesIssueAndPullURLs() {
        #expect(GhOutput.resourceNumber(in: "https://github.com/a/b/issues/12") == 12)
        #expect(GhOutput.firstURL(in: "Opened https://github.com/a/b/pull/3\n") == "https://github.com/a/b/pull/3")
        #expect(GhOutput.alreadyExists("GraphQL: Name already exists on this account"))
    }

    @Test @MainActor func generatePlanRequiresExistingRepo() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        runtime.seedDefaults()
        let account = Account(login: "alice", name: "Alice", email: "a@x.com", token: "test")
        container.mainContext.insert(account)
        let campaign = Campaign(name: "needs repo", owner: account)
        container.mainContext.insert(campaign)
        do {
            try runtime.generatePlan(for: campaign)
            Issue.record("expected missing repo")
        } catch GitGardenError.missingRepo {
            // expected
        }
    }

    @Test @MainActor func personasCanBeCreatedDuplicatedAndDeleted() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        runtime.seedDefaults()
        let bundled = try container.mainContext.fetch(FetchDescriptor<PersonaRecord>())
        #expect(bundled.count == 3)
        let rustacean = try #require(bundled.first(where: { $0.personaID == "rustacean" }))
        let copy = runtime.createPersona(copying: rustacean)
        #expect(!copy.isBundled)
        #expect(copy.personaID == "rustacean-copy")
        #expect(copy.name == "Rustacean copy")
        copy.name = "Night Owl"
        try runtime.savePersona(copy, yaml: PersonaYAML.replacingIdentity(copy.yamlBody, id: "night-owl", name: "Night Owl"))
        #expect(copy.personaID == "night-owl")
        #expect(copy.name == "Night Owl")
        #expect(copy.yamlBody.contains("id: night-owl"))
        let account = Account(login: "alice", name: "Alice", email: "a@x.com", token: "test", personaID: copy.personaID)
        container.mainContext.insert(account)
        runtime.deletePersona(copy)
        let leftover = try container.mainContext.fetch(FetchDescriptor<PersonaRecord>())
        #expect(!leftover.contains { $0.personaID == "night-owl" })
        #expect(account.personaID != "night-owl")
        runtime.deletePersona(rustacean)
        runtime.seedDefaults()
        let afterDelete = try container.mainContext.fetch(FetchDescriptor<PersonaRecord>())
        #expect(!afterDelete.contains { $0.personaID == "rustacean" })
        runtime.restoreBundledPersonas()
        let restored = try container.mainContext.fetch(FetchDescriptor<PersonaRecord>())
        #expect(restored.contains { $0.personaID == "rustacean" })
    }

    @Test @MainActor func auditEventsCanBeDismissed() throws {
        let schema = Schema([
            Account.self, PersonaRecord.self, Campaign.self, Job.self,
            CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self
        ])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let runtime = GardenRuntime(modelContainer: container)
        let keep = AuditEvent(accountLogin: "alice", method: "GIT", path: "push", statusCode: 0, message: "main")
        let drop = AuditEvent(accountLogin: "alice", method: "POST", path: "/graphql", statusCode: 500)
        container.mainContext.insert(keep)
        container.mainContext.insert(drop)
        runtime.dismissAudit(drop)
        var events = try container.mainContext.fetch(FetchDescriptor<AuditEvent>())
        #expect(events.map(\.path) == ["push"])
        runtime.clearAudit()
        events = try container.mainContext.fetch(FetchDescriptor<AuditEvent>())
        #expect(events.isEmpty)
    }
}
