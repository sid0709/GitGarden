import Foundation

nonisolated struct VacationGap: Hashable, Sendable {
    var start: String
    var end: String
}

nonisolated struct Persona: Hashable, Sendable {
    var id: String
    var name: String
    var language: String
    var commitStyle: String
    var timezone: String
    var workingHours: (start: Int, end: Int)
    var weekendWeight: Double
    var vacationGaps: [VacationGap]
    var branchPatterns: [String]
    var messages: [String]
    var issueTitles: [String]
    var issueBodies: [String]
    var prTitles: [String]
    var prBodies: [String]
    var reviewComments: [String]
    var bio: String
    var slugs: [String]

    static let rustaceanFallback = Persona(
        id: "rustacean",
        name: "Rustacean",
        language: "rust",
        commitStyle: "conventional",
        timezone: "America/Chicago",
        workingHours: (9, 18),
        weekendWeight: 0.15,
        vacationGaps: [VacationGap(start: "12-20", end: "01-04")],
        branchPatterns: ["feat/{slug}", "fix/{slug}", "chore/{slug}"],
        messages: [
            "feat: add {slug} helper",
            "fix: handle {slug} edge case",
            "refactor: extract {slug} module",
            "test: cover {slug} path",
            "docs: mention {slug} usage",
            "chore: tidy {slug} comments"
        ],
        issueTitles: [
            "Handle empty input in {slug}",
            "{slug} panics on invalid UTF-8",
            "Document {slug} error types"
        ],
        issueBodies: [
            "Saw this while running the {slug} path locally.\n\nSteps:\n1. Feed a truncated buffer\n2. Call the public API\n\nExpected a typed error, got a panic.",
            "Would be nicer if `{slug}` returned `Result` instead of unwrapping."
        ],
        prTitles: [
            "feat: {slug} pipeline",
            "fix: {slug} null path",
            "refactor: split {slug}"
        ],
        prBodies: [
            "This wires up `{slug}` and adds a regression test.\n\nFixes #{issue}",
            "Small, reviewable slice for `{slug}`.\n\nFixes #{issue}"
        ],
        reviewComments: [
            "Nice catch on the `{slug}` path.",
            "Can we add a test for the empty buffer case?",
            "LGTM after the error type tweak."
        ],
        bio: "Systems tinkerer. Rust, git, and long walks through compiler errors.",
        slugs: ["parser", "auth", "queue", "cache", "codec", "walker", "index", "scheduler"]
    )

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Persona, rhs: Persona) -> Bool {
        lhs.id == rhs.id
    }

    static func from(yaml: YAMLValue) -> Persona {
        let map = yaml.map ?? [:]
        func str(_ key: String, _ fallback: String) -> String {
            map[key]?.string ?? fallback
        }
        func list(_ key: String, _ fallback: [String]) -> [String] {
            let parsed = map[key]?.list?.compactMap(\.string) ?? []
            return parsed.isEmpty ? fallback : parsed
        }
        let hours = map["working_hours"]?.list ?? []
        let start = hours.first?.int ?? 9
        let end = hours.dropFirst().first?.int ?? 18
        var gaps: [VacationGap] = []
        if let rawGaps = map["vacation_gaps"]?.list {
            for item in rawGaps {
                if let gapMap = item.map {
                    gaps.append(VacationGap(start: gapMap["start"]?.string ?? "", end: gapMap["end"]?.string ?? ""))
                }
            }
        }
        let fallback = Persona.rustaceanFallback
        return Persona(
            id: str("id", fallback.id),
            name: str("name", fallback.name),
            language: str("language", fallback.language),
            commitStyle: str("commit_style", fallback.commitStyle),
            timezone: str("timezone", fallback.timezone),
            workingHours: (start, end),
            weekendWeight: map["weekend_weight"]?.double ?? fallback.weekendWeight,
            vacationGaps: gaps.isEmpty ? fallback.vacationGaps : gaps,
            branchPatterns: list("branch_patterns", fallback.branchPatterns),
            messages: list("messages", fallback.messages),
            issueTitles: list("issue_titles", fallback.issueTitles),
            issueBodies: list("issue_bodies", fallback.issueBodies),
            prTitles: list("pr_titles", fallback.prTitles),
            prBodies: list("pr_bodies", fallback.prBodies),
            reviewComments: list("review_comments", fallback.reviewComments),
            bio: str("bio", fallback.bio),
            slugs: list("slugs", fallback.slugs)
        )
    }
}

nonisolated enum PersonaCatalog {
    static var bundledYAML: [(id: String, name: String, body: String)] {
        [
            ("rustacean", "Rustacean", rustaceanYAML),
            ("typescript-web", "TypeScript Web", typescriptYAML),
            ("go-systems", "Go Systems", goYAML)
        ]
    }

    static let rustaceanYAML = """
    id: rustacean
    name: Rustacean
    language: rust
    commit_style: conventional
    timezone: America/Chicago
    working_hours: [9, 18]
    weekend_weight: 0.15
    vacation_gaps:
      - start: "12-20"
        end: "01-04"
    branch_patterns:
      - feat/{slug}
      - fix/{slug}
      - chore/{slug}
    messages:
      - "feat: add {slug} helper"
      - "fix: handle {slug} edge case"
      - "refactor: extract {slug} module"
      - "test: cover {slug} path"
      - "docs: mention {slug} usage"
      - "chore: tidy {slug} comments"
    issue_titles:
      - "Handle empty input in {slug}"
      - "{slug} panics on invalid UTF-8"
      - "Document {slug} error types"
    issue_bodies:
      - "Saw this while running the {slug} path locally."
      - "Would be nicer if `{slug}` returned Result instead of unwrapping."
    pr_titles:
      - "feat: {slug} pipeline"
      - "fix: {slug} null path"
    pr_bodies:
      - "This wires up `{slug}` and adds a regression test.\\n\\nFixes #{issue}"
    review_comments:
      - "Nice catch on the `{slug}` path."
      - "Can we add a test for the empty buffer case?"
    bio: "Systems tinkerer. Rust, git, and long walks through compiler errors."
    slugs: [parser, auth, queue, cache, codec, walker, index, scheduler]
    """

    static let typescriptYAML = """
    id: typescript-web
    name: TypeScript Web
    language: typescript
    commit_style: conventional
    timezone: America/Los_Angeles
    working_hours: [10, 19]
    weekend_weight: 0.2
    vacation_gaps:
      - start: "08-10"
        end: "08-20"
    branch_patterns:
      - feat/{slug}
      - fix/{slug}
    messages:
      - "feat({slug}): add client hook"
      - "fix({slug}): guard undefined state"
      - "test({slug}): add render case"
      - "chore: format {slug} module"
    issue_titles:
      - "{slug} flashes empty state"
      - "Keyboard nav missing on {slug}"
    issue_bodies:
      - "Repro on the {slug} screen after a hard refresh."
    pr_titles:
      - "feat: {slug} screen polish"
    pr_bodies:
      - "Implements the {slug} flow.\\n\\nFixes #{issue}"
    review_comments:
      - "Can we memoize the {slug} selector?"
      - "Looks good — tiny a11y note on the button."
    bio: "Frontend person. TypeScript, a11y, and stubborn CSS."
    slugs: [auth, inbox, settings, editor, search, billing]
    """

    static let goYAML = """
    id: go-systems
    name: Go Systems
    language: go
    commit_style: terse
    timezone: America/New_York
    working_hours: [8, 17]
    weekend_weight: 0.08
    vacation_gaps: []
    branch_patterns:
      - feat/{slug}
      - fix/{slug}
    messages:
      - "{slug}: handle shutdown"
      - "{slug}: tighten timeouts"
      - "tests for {slug} retry"
    issue_titles:
      - "{slug} leaks goroutines on cancel"
    issue_bodies:
      - "Context cancel on {slug} still leaves a waiter."
    pr_titles:
      - "{slug}: bounded worker pool"
    pr_bodies:
      - "Fixes #{issue} by bounding {slug} workers."
    review_comments:
      - "Need a test with a canceled context."
    bio: "Go, queues, and mildly obsessive tracing."
    slugs: [worker, gateway, ingest, replica, lease]
    """
}

nonisolated enum PersonaLoader {
    static func load(from yamlBody: String) -> Persona {
        if let value = try? SimpleYAML.parse(yamlBody) {
            return Persona.from(yaml: value)
        }
        return .rustaceanFallback
    }

    static func bundled() -> [Persona] {
        PersonaCatalog.bundledYAML.map { load(from: $0.body) }
    }
}
