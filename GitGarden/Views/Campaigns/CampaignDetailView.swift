import SwiftUI
import SwiftData
import AppKit

struct CampaignDetailView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Bindable var campaign: Campaign
    @State private var errorMessage: String?
    @State private var showNuke = false
    @State private var jobPage = 0
    @State private var resourcePage = 0

    var body: some View {
        SKPage {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(campaign.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(campaign.owner?.login ?? "—") · \(campaign.defaultRepoName)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    HStack(spacing: 6) {
                        SKTag(
                            kind: campaign.kind == .issues ? .issue : campaign.kind == .pullRequests ? .pull : campaign.kind == .daily ? .live : .history,
                            label: campaign.kind.title
                        )
                        SKTag(kind: campaign.dryRun ? .dry : .live)
                        SKTag(kind: statusTag, label: campaign.status.rawValue)
                        if campaign.kind == .daily, campaign.status == .running {
                            SKTag(
                                kind: campaign.isDailyCaughtUp ? .completed : .pending,
                                label: campaign.isDailyCaughtUp ? "Applied today" : "Due today"
                            )
                        }
                    }
                }
                Spacer()
                SKAvatarStack(people: people)
            }

            if !runtime.missingScopeWarnings(for: campaign).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Scope warnings")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    ForEach(runtime.missingScopeWarnings(for: campaign), id: \.self) { warning in
                        Text(warning)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(SKTheme.accent)
                    }
                }
            }

            if campaign.kind == .daily {
                DailySchedulePanel(campaign: campaign)
            } else if let plan = campaign.plan {
                HStack {
                    Text("Season preview")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(campaign.historyYears) years · \(Int(campaign.progress * 100))% grown")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                }
                Stepper(
                    campaign.kind == .history
                        ? "Backdated history: \(campaign.historyYears) years"
                        : campaign.kind == .issues
                            ? "Issues: \(campaign.issueCount)"
                            : "Pull requests: \(campaign.prCount)",
                    value: Binding(
                        get: {
                            switch campaign.kind {
                            case .daily: return 0
                            case .history: return campaign.historyYears
                            case .issues: return campaign.issueCount
                            case .pullRequests: return campaign.prCount
                            }
                        },
                        set: { value in
                            switch campaign.kind {
                            case .daily:
                                break
                            case .history:
                                campaign.setHistoryYears(value)
                                campaign.commitCount = Campaign.suggestedCommitCount(forYears: value)
                            case .issues:
                                campaign.issueCount = min(160, max(1, value))
                            case .pullRequests:
                                campaign.prCount = min(120, max(1, value))
                            }
                            do { try runtime.generatePlan(for: campaign) }
                            catch { errorMessage = error.localizedDescription }
                        }
                    ),
                    in: 1...20
                )
                ContributionHistoryView(days: plan.heatmap, showsPlanned: true)
                ProgressView(value: campaign.progress)
                    .tint(SKTheme.accent)
                HStack {
                    metric("Commits", plan.summary.commitCount)
                    metric("PRs", plan.summary.prCount)
                    metric("Issues", plan.summary.issueCount)
                    metric("API", plan.summary.estimatedAPICalls)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    SKQuietButton(title: "Generate plan") {
                        do { try runtime.generatePlan(for: campaign) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .disabled(campaign.kind == .daily)
                    SKQuietButton(title: "Simulate") {
                        do { try runtime.startCampaign(campaign, live: false) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .disabled(campaign.kind == .daily)
                    SKPrimaryButton(
                        title: campaign.kind == .daily ? "Schedule daily" : "Run live",
                        enabled: campaign.status != .running || campaign.dryRun || campaign.kind == .daily
                    ) {
                        do { try runtime.startCampaign(campaign, live: true) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    SKQuietButton(title: "Pause") { runtime.pauseCampaign(campaign) }
                    SKQuietButton(title: "Resume") {
                        do { try runtime.resumeCampaign(campaign) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    if campaign.status == .failed {
                        SKQuietButton(title: "Retry failed") {
                            do { try runtime.retryCampaign(campaign) }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                    SKPrimaryButton(title: "Nuke", destructive: true, enabled: !campaign.resources.isEmpty) {
                        showNuke = true
                    }
                    SKQuietButton(title: "Delete") {
                        runtime.deleteCampaign(campaign)
                    }
                }
            }
            .scrollIndicators(.visible, axes: .horizontal)

            if !campaign.lastError.isEmpty {
                Text(campaign.lastError)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(SKTheme.coral)
            }

            if !campaign.resources.isEmpty {
                Text("Grown artifacts")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                ForEach(SKPaging.slice(campaign.resources, page: resourcePage)) { resource in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.label)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Text(resource.kind.rawValue)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                        }
                        Spacer()
                        if let url = URL(string: resource.url), !resource.url.isEmpty {
                            Button("Open") { NSWorkspace.shared.open(url) }
                                .buttonStyle(.plain)
                                .foregroundStyle(SKTheme.accent)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .padding(.vertical, 6)
                }
                SKPagerBar(page: $resourcePage, total: campaign.resources.count, noun: "artifacts")
            }

            if campaign.kind != .daily {
                Text("Score")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)

                ForEach(SKPaging.slice(scoreJobs, page: jobPage)) { job in
                    HStack(alignment: .top, spacing: 12) {
                        VStack {
                            Circle()
                                .fill(StatusTint.color(for: job.status))
                                .frame(width: 9, height: 9)
                            Rectangle()
                                .fill(SKTheme.hairline)
                                .frame(width: 2)
                        }
                        .frame(width: 12)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(job.summary)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Text("\(job.accountLogin) · \(job.kind.title) · \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                            if !job.lastError.isEmpty {
                                Text(job.lastError)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(SKTheme.coral)
                            }
                        }
                        Spacer()
                        if job.status == .failed {
                            SKQuietButton(title: "Retry") {
                                do { try runtime.retryJob(job) }
                                catch { errorMessage = error.localizedDescription }
                            }
                        } else if job.status == .pending {
                            SKQuietButton(title: "Skip") { runtime.skipJob(job) }
                        }
                    }
                }
                SKPagerBar(page: $jobPage, total: scoreJobs.count, noun: "jobs")
            }
        }
        .alert("Campaign error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showNuke) {
            NukeConfirmSheet(campaign: campaign)
        }
        .task {
            if campaign.kind != .daily {
                await runtime.refreshHeatmap(for: campaign)
            }
        }
        .onChange(of: campaign.persistentModelID) { _, _ in
            jobPage = 0
            resourcePage = 0
        }
    }

    private var scoreJobs: [Job] {
        campaign.jobs.filter { $0.kind != .createRepo }.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var people: [(url: String, name: String)] {
        var list: [(url: String, name: String)] = []
        if let owner = campaign.owner { list.append((owner.avatarURL, owner.login)) }
        if let collab = campaign.collaborator { list.append((collab.avatarURL, collab.login)) }
        return list
    }

    private var statusTag: SKTagKind {
        switch campaign.status {
        case .running: return .running
        case .failed: return .failed
        case .completed: return .completed
        case .planned, .draft, .paused: return .pending
        default: return .ui
        }
    }

    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.system(size: 11, design: .rounded)).foregroundStyle(SKTheme.mute)
            Text("\(value)").font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DailySchedulePanel: View {
    @Environment(GardenRuntime.self) private var runtime
    @Bindable var campaign: Campaign
    @State private var applying = false

    private var today: String { CronTick.dayKey(Date()) }
    private var remaining: (commits: Int, issues: Int, prs: Int) {
        campaign.remainingDaily(on: today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily quota")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                if campaign.status == .running {
                    SKTag(
                        kind: campaign.isDailyCaughtUp ? .completed : .pending,
                        label: campaign.isDailyCaughtUp ? "Applied today" : "Due today"
                    )
                }
            }
            Text("Each launch applies remaining commits, issues, and PRs into \(campaign.defaultRepoName) with this campaign’s persona.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            Stepper("Commits per day: \(campaign.commitCount)", value: $campaign.commitCount, in: 0...20)
            Stepper("Issues per day: \(campaign.issueCount)", value: $campaign.issueCount, in: 0...20)
            Stepper("Pull requests per day: \(campaign.prCount)", value: $campaign.prCount, in: 0...20)
            HStack {
                metric("Commits left", remaining.commits, campaign.commitCount)
                metric("Issues left", remaining.issues, campaign.issueCount)
                metric("PRs left", remaining.prs, campaign.prCount)
            }
            if !campaign.lastScheduleMessage.isEmpty {
                Text(campaign.lastScheduleMessage)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(campaign.lastScheduleSucceeded ? SKTagKind.completed.tint : SKTheme.coral)
            }
            HStack {
                SKPrimaryButton(
                    title: applying ? "Applying…" : campaign.isDailyCaughtUp ? "Applied" : "Apply today",
                    enabled: campaign.status == .running && !applying && !campaign.isDailyCaughtUp
                ) {
                    Task {
                        applying = true
                        defer { applying = false }
                        await runtime.applyDailyCampaign(campaign)
                    }
                }
                if let applied = campaign.lastScheduleAt {
                    Text(applied.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                }
            }
        }
        .onChange(of: campaign.commitCount) { _, _ in try? runtime.context.save() }
        .onChange(of: campaign.issueCount) { _, _ in try? runtime.context.save() }
        .onChange(of: campaign.prCount) { _, _ in try? runtime.context.save() }
    }

    private func metric(_ title: String, _ left: Int, _ total: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            Text("\(left)/\(total)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NukeConfirmSheet: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var campaign: Campaign
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Close issues and pull requests this campaign opened on “\(campaign.name)”? The existing target repo is never deleted.")
                    .font(.system(size: 14, design: .rounded))
                List(NukeOrder.sorted(campaign.resources), id: \.persistentModelID) { resource in
                    VStack(alignment: .leading) {
                        Text(resource.label)
                        Text(resource.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                    .tag(resource.persistentModelID)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Nuke campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(busy ? "Nuking…" : "Nuke") {
                        Task {
                            busy = true
                            defer { busy = false }
                            do {
                                try await runtime.nuke(campaign)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(busy)
                }
            }
            .frame(minWidth: 420, minHeight: 360)
        }
    }
}
