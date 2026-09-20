import SwiftUI
import SwiftData
import AppKit

struct GardenView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Account.login) private var accounts: [Account]
    @Query(sort: \Campaign.updatedAt, order: .reverse) private var campaigns: [Campaign]
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var selectedLogin: String?
    @State private var showAdd = false

    private var visibleAccounts: [Account] {
        guard !search.isEmpty else { return accounts }
        return accounts.filter {
            $0.login.localizedCaseInsensitiveContains(search) || $0.displayName.localizedCaseInsensitiveContains(search)
        }
    }

    private var selectedAccount: Account? {
        visibleAccounts.first { $0.login == selectedLogin } ?? visibleAccounts.first
    }

    private var seasons: [Campaign] {
        campaigns.filter { selectedAccount == nil || $0.involvedLogins.contains(selectedAccount?.login ?? "") }
    }

    private var plotDays: [HeatmapDay] {
        let live = runtime.heatmaps[selectedAccount?.login ?? ""]
            ?? selectedAccount?.cachedHeatmap
            ?? []
        if !live.isEmpty {
            if let planned = campaigns.first(where: { $0.owner?.login == selectedAccount?.login })?.plan?.heatmap {
                let plannedMap = Dictionary(planned.map { ($0.date, $0.planned) }, uniquingKeysWith: { _, last in last })
                return live.map { HeatmapDay(date: $0.date, existing: $0.existing, planned: plannedMap[$0.date] ?? 0) }
            }
            return live
        }
        return campaigns.first(where: { $0.plan != nil })?.plan?.heatmap ?? []
    }

    private var selectedRepos: [GitHubRepo] {
        guard let account = selectedAccount else { return [] }
        return runtime.repositories[account.login] ?? account.cachedRepos
    }

    private var selectedOrgs: [GitHubOrg] {
        guard let account = selectedAccount else { return [] }
        return runtime.organizations[account.login] ?? account.cachedOrgs
    }

    var body: some View {
        SKPage {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The plot")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    Text(selectedAccount.map { account in
                        if let created = account.githubCreatedAt {
                            return "@\(account.login) since \(created.formatted(.dateTime.year()))"
                        }
                        return "@\(account.login)’s garden"
                    } ?? "Plant an account to grow a year")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                HStack(spacing: 8) {
                    SKQuietButton(title: "Refresh") {
                        Task {
                            if let account = selectedAccount {
                                await runtime.loadHeatmap(for: account)
                            } else {
                                await runtime.validateAllAccounts()
                            }
                        }
                    }
                    SKPrimaryButton(title: "Add account") { showAdd = true }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                SKMetricChip(title: "Accounts", value: "\(accounts.count)", kind: .ui)
                SKMetricChip(title: "Campaigns", value: "\(campaigns.count)", kind: .history)
                SKMetricChip(title: "Running", value: "\(campaigns.filter { $0.status == .running }.count)", kind: .running)
                SKMetricChip(title: "Queued", value: "\(jobs.filter { $0.status == .pending }.count)", kind: .pending)
            }

            if let account = selectedAccount {
                AccountStatGrid(account: account, days: plotDays, repos: selectedRepos)
            }

            SKCard(padding: 22) {
                if let account = selectedAccount {
                    HStack(alignment: .center, spacing: 14) {
                        SKAvatar(url: account.avatarURL, name: account.login, size: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text(account.email.isEmpty ? "@\(account.login)" : account.email)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                        }
                        Spacer()
                        if runtime.heatmapLoading.contains(account.login) {
                            ProgressView()
                                .controlSize(.small)
                        }
                        if let url = URL(string: account.htmlURL), !account.htmlURL.isEmpty {
                            SKQuietButton(title: "GitHub") { NSWorkspace.shared.open(url) }
                        }
                        SKTag(kind: account.isFineGrained ? .ux : .ui, label: account.isFineGrained ? "Fine-grained" : "Classic PAT")
                    }
                    AccountProfileFacts(account: account)
                    ContributionHistoryView(days: plotDays, showsPlanned: true, cell: 11)
                    SKRateBar(remaining: account.rateLimitRemaining, limit: max(account.rateLimitLimit, 1))
                    if let next = runtime.nextFire {
                        Text("Next job \(next.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Empty soil")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Paste a classic PAT with repo, user, and delete_repo. The plot fills in from GitHub’s contribution calendar.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                    }
                    .frame(minHeight: 140, alignment: .leading)
                }
            }

            if !visibleAccounts.isEmpty {
                Text("Orchard")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(visibleAccounts) { account in
                        Button {
                            withAnimation(SKMotion.spring) { selectedLogin = account.login }
                            Task { await runtime.loadHeatmap(for: account) }
                        } label: {
                            SKFilmRow(selected: selectedAccount?.login == account.login) {
                                HStack(spacing: 10) {
                                    SKAvatar(url: account.avatarURL, name: account.login, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.displayName)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SKTheme.inkColor(for: scheme))
                                        Text(joinedLine(for: account))
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(SKTheme.mute)
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            OrgListView(orgs: selectedOrgs)
            RepoListView(repos: selectedRepos, query: search)

            if let live = campaigns.first(where: { $0.status == .running }) {
                SKCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Now growing")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                            Text(live.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        SKTag(kind: live.dryRun ? .dry : .live)
                        SKTag(kind: .running, label: "\(Int(live.progress * 100))%")
                        SKQuietButton(title: "Pause") { runtime.pauseCampaign(live) }
                    }
                    ProgressView(value: live.progress)
                        .tint(SKTheme.accent)
                }
            }

            if !seasons.isEmpty {
                Text("Seasons on this plot")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                ForEach(seasons.prefix(6)) { campaign in
                    SKFilmRow(selected: campaign.status == .running) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(campaign.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                HStack(spacing: 6) {
                                    SKTag(kind: campaign.dryRun ? .dry : .live)
                                    SKTag(kind: .history, label: campaign.status.rawValue)
                                }
                            }
                            Spacer()
                            if campaign.status == .running && campaign.dryRun {
                                SKPrimaryButton(title: "Run live") {
                                    try? runtime.startCampaign(campaign, live: true)
                                }
                            } else if campaign.status == .paused {
                                SKQuietButton(title: "Resume") {
                                    try? runtime.resumeCampaign(campaign)
                                }
                            } else if campaign.plan != nil, campaign.status != .running {
                                SKQuietButton(title: "Simulate") {
                                    try? runtime.startCampaign(campaign, live: false)
                                }
                                SKPrimaryButton(title: "Run live", enabled: campaign.status != .nuked) {
                                    try? runtime.startCampaign(campaign, live: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAccountSheet(personas: personas)
        }
        .task {
            if selectedLogin == nil { selectedLogin = accounts.first?.login }
            await runtime.validateAllAccounts()
        }
        .onChange(of: accounts.count) { _, _ in
            if selectedLogin == nil { selectedLogin = accounts.first?.login }
        }
    }

    private func joinedLine(for account: Account) -> String {
        var parts: [String] = []
        if let created = account.githubCreatedAt {
            parts.append("Joined \(created.formatted(.dateTime.month(.abbreviated).year()))")
        }
        parts.append("\(max(account.totalRepoCount, (runtime.repositories[account.login] ?? account.cachedRepos).count)) repos")
        parts.append("\(campaigns.filter { $0.involvedLogins.contains(account.login) }.count) campaigns")
        return parts.joined(separator: " · ")
    }
}
