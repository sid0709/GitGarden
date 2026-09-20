import Testing
import Foundation
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
}
