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
        #expect(plan.steps.contains { $0.kind == .createRepo })
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
}
