import Foundation

nonisolated struct PlannerInput: Sendable {
    var ownerLogin: String
    var ownerName: String
    var ownerEmail: String
    var collaboratorLogin: String?
    var repoName: String
    var repoDescription: String
    var start: Date
    var end: Date
    var commitCount: Int
    var prCount: Int
    var issueCount: Int
    var includeHistory: Bool
    var includePRs: Bool
    var includeIssues: Bool
    var includeProfile: Bool
    var includeSocial: Bool
    var dripMode: Bool
    var dripInterval: TimeInterval
    var persona: Persona
    var seed: UInt64
    var language: String
}

nonisolated struct Planner: Sendable {
    var mutator = CodeMutator()

    func build(_ input: PlannerInput) -> CampaignPlanDocument {
        var rng = SeededGenerator(seed: input.seed)
        var steps: [PlanStep] = []
        let cadence = CadenceSampler(timezone: input.persona.timezone)
        let now = Date()
        var executeAt = now
        func schedule() -> Date {
            let stamp = executeAt
            if input.dripMode {
                executeAt.addTimeInterval(input.dripInterval)
            } else {
                executeAt.addTimeInterval(0.05)
            }
            return stamp
        }

        func add(_ kind: StepKind, account: String, summary: String, payload: StepPayload, at scheduled: Date) {
            var payload = payload
            if payload.owner == nil { payload.owner = input.ownerLogin }
            if payload.repo == nil { payload.repo = input.repoName }
            steps.append(
                PlanStep(
                    id: UUID().uuidString,
                    kind: kind,
                    accountLogin: account,
                    scheduledAt: scheduled,
                    summary: summary,
                    payload: payload
                )
            )
        }

        if input.includeHistory {
            add(
                .createRepo,
                account: input.ownerLogin,
                summary: "Create \(input.ownerLogin)/\(input.repoName)",
                payload: StepPayload(
                    repo: input.repoName,
                    owner: input.ownerLogin,
                    title: input.repoName,
                    privateRepo: false,
                    description: input.repoDescription,
                    language: input.language
                ),
                at: schedule()
            )
        }

        if let collab = input.collaboratorLogin, input.includeHistory || input.includePRs || input.includeIssues {
            add(
                .inviteCollaborator,
                account: input.ownerLogin,
                summary: "Invite \(collab) to \(input.repoName)",
                payload: StepPayload(username: collab),
                at: schedule()
            )
        }

        if input.includeProfile {
            add(
                .patchProfile,
                account: input.ownerLogin,
                summary: "Set bio for \(input.ownerLogin)",
                payload: StepPayload(committerName: input.ownerName, bio: input.persona.bio),
                at: schedule()
            )
        }

        let commitDates = input.includeHistory
            ? cadence.sampleDates(count: max(input.commitCount, 1), from: input.start, to: input.end, persona: input.persona, rng: &rng)
            : []

        var issueCounter = 0
        var issueEvents: [(date: Date, number: Int, slug: String, opener: String)] = []
        if input.includeIssues {
            let issueDates = cadence.sampleDates(
                count: max(input.issueCount, 1),
                from: input.start,
                to: input.end,
                persona: input.persona,
                rng: &rng
            )
            for date in issueDates {
                issueCounter += 1
                let slug = rng.pick(input.persona.slugs)
                let opener: String
                if let collab = input.collaboratorLogin, rng.double() < 0.55 {
                    opener = collab
                } else {
                    opener = input.ownerLogin
                }
                issueEvents.append((date, issueCounter, slug, opener))
            }
        }

        var prSlots: [(anchor: Date, slug: String, issue: Int?)] = []
        if input.includePRs {
            let prDates = strideLike(commitDates, count: max(input.prCount, 1))
            for date in prDates {
                let slug = rng.pick(input.persona.slugs)
                let linked = issueEvents.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                prSlots.append((date, slug, linked?.number))
            }
        }

        var state = mutator.seed(language: input.language, repoName: input.repoName)
        var currentBranch = "main"
        var openPRIndex = 0
        var lastPushCount = 0
        var commitIndex = 0

        for (index, date) in commitDates.enumerated() {
            let slug = rng.pick(input.persona.slugs)
            if input.includePRs, openPRIndex < prSlots.count, date >= prSlots[openPRIndex].anchor, currentBranch == "main" {
                let slot = prSlots[openPRIndex]
                currentBranch = MessageGenerator.branchName(persona: input.persona, slug: slot.slug, rng: &rng)
                add(
                    .createBranch,
                    account: input.ownerLogin,
                    summary: "Branch \(currentBranch)",
                    payload: StepPayload(branch: currentBranch, baseBranch: "main", authorDate: date),
                    at: schedule()
                )
            }

            let mutation = mutator.apply(state: state, slug: slug, index: commitIndex, persona: input.persona, rng: &rng)
            state = mutation.state
            commitIndex += 1
            let files = mutation.changedPaths.map { FileChange(path: $0, content: state[$0]) }
            var message = mutation.message
            if let slot = prSlots.first(where: { $0.slug == slug }), let issue = slot.issue, rng.double() < 0.35 {
                message += "\n\nFixes #\(issue)"
            }
            add(
                .commit,
                account: input.ownerLogin,
                summary: message,
                payload: StepPayload(
                    message: message,
                    files: files,
                    branch: currentBranch,
                    authorDate: date,
                    committerEmail: input.ownerEmail,
                    committerName: input.ownerName.isEmpty ? input.ownerLogin : input.ownerName,
                    relatedIssue: nil,
                    language: input.language
                ),
                at: schedule()
            )

            if (index + 1) % 12 == 0 || index == commitDates.count - 1 {
                add(
                    .push,
                    account: input.ownerLogin,
                    summary: "Push \(currentBranch)",
                    payload: StepPayload(branch: currentBranch),
                    at: schedule()
                )
                lastPushCount = index + 1
            }

            if input.includePRs, currentBranch != "main", openPRIndex < prSlots.count {
                let consumed = commitIndex
                let enough = consumed > 0 && (index == commitDates.count - 1 || (openPRIndex + 1 < prSlots.count && commitDates[min(index + 1, commitDates.count - 1)] >= prSlots[openPRIndex + 1].anchor) || rng.double() < 0.2)
                if enough {
                    let slot = prSlots[openPRIndex]
                    let prTitle = MessageGenerator.fill(rng.pick(input.persona.prTitles), slug: slot.slug, issue: slot.issue)
                    let prBody = MessageGenerator.fill(rng.pick(input.persona.prBodies), slug: slot.slug, issue: slot.issue)
                    add(
                        .createPR,
                        account: prAuthor(input, rng: &rng),
                        summary: prTitle,
                        payload: StepPayload(
                            branch: currentBranch,
                            baseBranch: "main",
                            title: prTitle,
                            body: prBody,
                            relatedIssue: slot.issue
                        ),
                        at: schedule()
                    )
                    if let collab = input.collaboratorLogin {
                        let reviewer = collab == steps.last?.accountLogin ? input.ownerLogin : collab
                        add(
                            .reviewPR,
                            account: reviewer,
                            summary: MessageGenerator.fill(rng.pick(input.persona.reviewComments), slug: slot.slug),
                            payload: StepPayload(
                                branch: currentBranch,
                                body: MessageGenerator.fill(rng.pick(input.persona.reviewComments), slug: slot.slug)
                            ),
                            at: schedule()
                        )
                    }
                    add(
                        .mergePR,
                        account: input.ownerLogin,
                        summary: "Merge \(currentBranch)",
                        payload: StepPayload(branch: currentBranch, baseBranch: "main"),
                        at: schedule()
                    )
                    currentBranch = "main"
                    openPRIndex += 1
                    _ = lastPushCount
                }
            }
        }

        if lastPushCount < commitDates.count, input.includeHistory, !commitDates.isEmpty {
            add(.push, account: input.ownerLogin, summary: "Push remaining commits", payload: StepPayload(branch: "main"), at: schedule())
        }

        for event in issueEvents {
            let title = MessageGenerator.fill(rng.pick(input.persona.issueTitles), slug: event.slug)
            let body = MessageGenerator.fill(rng.pick(input.persona.issueBodies), slug: event.slug)
            add(
                .createIssue,
                account: event.opener,
                summary: title,
                payload: StepPayload(title: title, body: body, issueNumber: event.number, authorDate: event.date),
                at: schedule()
            )
            if let collab = input.collaboratorLogin {
                let replier = event.opener == input.ownerLogin ? collab : input.ownerLogin
                add(
                    .commentIssue,
                    account: replier,
                    summary: "Reply on #\(event.number)",
                    payload: StepPayload(
                        body: MessageGenerator.fill(rng.pick(input.persona.reviewComments), slug: event.slug),
                        issueNumber: event.number
                    ),
                    at: schedule()
                )
            }
            if rng.double() < 0.7 {
                add(
                    .closeIssue,
                    account: input.ownerLogin,
                    summary: "Close #\(event.number)",
                    payload: StepPayload(issueNumber: event.number),
                    at: schedule()
                )
            }
        }

        if input.includeHistory, rng.double() < 0.8, !commitDates.isEmpty {
            add(
                .createRelease,
                account: input.ownerLogin,
                summary: "Tag v0.1.0",
                payload: StepPayload(title: "v0.1.0", body: "Initial cut.", tag: "v0.1.0"),
                at: schedule()
            )
        }

        if input.includeSocial {
            if let collab = input.collaboratorLogin {
                add(.follow, account: input.ownerLogin, summary: "Follow \(collab)", payload: StepPayload(username: collab), at: schedule())
                add(.follow, account: collab, summary: "Follow \(input.ownerLogin)", payload: StepPayload(username: input.ownerLogin), at: schedule())
                add(.star, account: collab, summary: "Star \(input.repoName)", payload: StepPayload(), at: schedule())
            }
        }

        let heatmap = HeatmapBuilder.build(dates: commitDates)
        let summary = PlanSummary(
            commitCount: steps.filter { $0.kind == .commit }.count,
            prCount: steps.filter { $0.kind == .createPR }.count,
            issueCount: steps.filter { $0.kind == .createIssue }.count,
            reviewCount: steps.filter { $0.kind == .reviewPR }.count,
            releaseCount: steps.filter { $0.kind == .createRelease }.count,
            socialCount: steps.filter { $0.kind == .follow || $0.kind == .star }.count,
            estimatedAPICalls: steps.filter { $0.kind != .commit }.count + steps.filter { $0.kind == .push }.count
        )
        return CampaignPlanDocument(steps: steps, heatmap: heatmap, summary: summary, seed: input.seed)
    }

    private func prAuthor(_ input: PlannerInput, rng: inout SeededGenerator) -> String {
        if let collab = input.collaboratorLogin, rng.double() < 0.5 {
            return collab
        }
        return input.ownerLogin
    }

    private func strideLike(_ dates: [Date], count: Int) -> [Date] {
        guard !dates.isEmpty else { return [] }
        if count >= dates.count { return dates }
        let step = Double(dates.count) / Double(max(count, 1))
        return (0..<count).map { index in
            dates[min(Int((Double(index) + 0.5) * step), dates.count - 1)]
        }
    }
}
