import SwiftUI
import SwiftData

struct CampaignDetailView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Bindable var campaign: Campaign
    @State private var errorMessage: String?
    @State private var showNuke = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(campaign.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("\(campaign.owner?.login ?? "—") · \(campaign.defaultRepoName)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    HStack(spacing: 6) {
                        SKTag(kind: campaign.dryRun ? .dry : .live)
                        SKTag(kind: statusTag)
                        if campaign.collaborator != nil { SKTag(kind: .ux, label: "Cross-account") }
                    }
                }

                if !runtime.missingScopeWarnings(for: campaign).isEmpty {
                    SKCard {
                        Text("Scope warnings")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        ForEach(runtime.missingScopeWarnings(for: campaign), id: \.self) { warning in
                            Text(warning)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(SKTheme.accent)
                        }
                    }
                }

                if let plan = campaign.plan {
                    SKCard {
                        Text("Heatmap preview")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        HeatmapView(days: plan.heatmap)
                        HStack {
                            metric("Commits", plan.summary.commitCount)
                            metric("PRs", plan.summary.prCount)
                            metric("Issues", plan.summary.issueCount)
                            metric("API", plan.summary.estimatedAPICalls)
                        }
                    }
                }

                HStack(spacing: 8) {
                    SKQuietButton(title: "Plan") {
                        do { try runtime.generatePlan(for: campaign) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    SKPrimaryButton(title: "Run", enabled: campaign.status != .running) {
                        do { try runtime.startCampaign(campaign) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    SKQuietButton(title: "Pause") { runtime.pauseCampaign(campaign) }
                    SKQuietButton(title: "Resume") {
                        do { try runtime.resumeCampaign(campaign) }
                        catch { errorMessage = error.localizedDescription }
                    }
                    SKPrimaryButton(title: "Nuke", destructive: true, enabled: !campaign.resources.isEmpty) {
                        showNuke = true
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Plan")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    ForEach(campaign.jobs.sorted(by: { $0.orderIndex < $1.orderIndex })) { job in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(StatusTint.color(for: job.status))
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.summary)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                Text("\(job.accountLogin) · \(job.kind.title)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(SKTheme.mute)
                            }
                        }
                    }
                }
            }
            .padding(22)
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
            await runtime.refreshHeatmap(for: campaign)
        }
    }

    private var statusTag: SKTagKind {
        switch campaign.status {
        case .running: return .running
        case .failed: return .failed
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

struct NukeConfirmSheet: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var campaign: Campaign
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Delete resources created by “\(campaign.name)”? Repos the campaign created will be deleted. Issues and PRs will be closed.")
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
