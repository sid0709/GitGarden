import SwiftUI
import SwiftData

struct CampaignsView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Campaign.updatedAt, order: .reverse) private var campaigns: [Campaign]
    @Query(sort: \Account.login) private var accounts: [Account]
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var selected: Campaign.ID?
    @State private var showComposer = false
    @State private var showClearWork = false

    private var filtered: [Campaign] {
        guard !search.isEmpty else { return campaigns }
        return campaigns.filter {
            $0.name.localizedCaseInsensitiveContains(search) || ($0.owner?.login ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Seasons")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    Spacer()
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SKTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(SKTheme.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(accounts.isEmpty)
                    .help("New campaign")
                    Button {
                        showClearWork = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SKTheme.mute)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Clear GitGarden work")
                    .disabled(campaigns.isEmpty)
                }
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { campaign in
                            Button {
                                withAnimation(SKMotion.spring) { selected = campaign.id }
                            } label: {
                                SKFilmRow(selected: selected == campaign.id) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .top, spacing: 8) {
                                            Text(campaign.name)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(SKTheme.inkColor(for: scheme))
                                                .lineLimit(2)
                                                .skFillWidth()
                                            if campaign.status == .completed {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(SKTagKind.completed.tint)
                                            }
                                        }
                                        HStack(spacing: 6) {
                                            SKTag(kind: campaign.kindTag)
                                            SKTag(kind: campaign.dryRun ? .dry : .live)
                                            SKTag(kind: campaign.statusTag, label: campaign.status.rawValue)
                                        }
                                        if campaign.status == .running {
                                            ProgressView(value: campaign.progress)
                                                .tint(SKTheme.accent)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .skFillWidth()
                        }
                    }
                    .skFillWidth()
                }
            }
            .padding(18)
            .frame(width: 280)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(SKTheme.railColor(for: scheme))
            .overlay(alignment: .trailing) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }

            Group {
                if let campaign = campaigns.first(where: { $0.id == selected }) ?? filtered.first {
                    CampaignDetailView(campaign: campaign)
                } else {
                    VStack(spacing: 10) {
                        Text("Compose a season")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("Pick one job: fake commit history, issues, or pull requests. Each campaign writes into a repo you already have.")
                            .foregroundStyle(SKTheme.mute)
                        SKPrimaryButton(title: "New campaign", enabled: !accounts.isEmpty) { showComposer = true }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if selected == nil { selected = campaigns.first?.id }
        }
        .onChange(of: campaigns.count) { _, _ in
            if selected == nil || !campaigns.contains(where: { $0.id == selected }) {
                selected = campaigns.first?.id
            }
        }
        .sheet(isPresented: $showComposer) {
            CampaignComposerView(accounts: accounts, personas: personas)
        }
        .alert("Clear GitGarden work?", isPresented: $showClearWork) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                try? runtime.clearGitGardenWork()
                selected = nil
            }
        } message: {
            Text("Removes campaigns, queue, audit log, caches, and local worktrees. Accounts and GitHub git history stay.")
        }
    }
}

private extension Campaign {
    var kindTag: SKTagKind {
        switch kind {
        case .history: return .history
        case .issues: return .issue
        case .pullRequests: return .pull
        }
    }

    var statusTag: SKTagKind {
        switch status {
        case .running: return .running
        case .failed: return .failed
        case .completed: return .completed
        case .planned, .draft, .paused: return .pending
        default: return .ui
        }
    }
}

struct CampaignComposerView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var personas: [PersonaRecord]

    @State private var kind: CampaignKind = .history
    @State private var ownerLogin = ""
    @State private var personaID = "rustacean"
    @State private var historyYears = 10
    @State private var commitCount = 400
    @State private var prCount = 4
    @State private var issueCount = 8
    @State private var start = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
    @State private var end = Date()
    @State private var repoName = ""
    @State private var language = "rust"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What to grow") {
                    Picker("Campaign", selection: $kind) {
                        ForEach(CampaignKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, newKind in
                        applyKindDefaults(newKind)
                    }
                    Text(kind.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Account and repo") {
                    Picker("Account", selection: $ownerLogin) {
                        ForEach(accounts) { account in
                            Text(account.login).tag(account.login)
                        }
                    }
                    Picker("Repo", selection: $repoName) {
                        Text("Choose a repo").tag("")
                        ForEach(ownerRepos, id: \.fullName) { repo in
                            Text(repo.fullName).tag(repo.name)
                        }
                    }
                    TextField("Or type owner/name", text: $repoName)
                    Picker("Persona", selection: $personaID) {
                        ForEach(personas) { persona in
                            Text(persona.name).tag(persona.personaID)
                        }
                    }
                }
                Section(kind.title) {
                    switch kind {
                    case .history:
                        Stepper("Past \(historyYears) years", value: $historyYears, in: 1...20)
                            .onChange(of: historyYears) { _, years in
                                applyHistoryYears(years)
                            }
                        Stepper("Commits: \(commitCount)", value: $commitCount, in: 1...2500)
                    case .issues:
                        Stepper("Issues: \(issueCount)", value: $issueCount, in: 1...160)
                    case .pullRequests:
                        Stepper("Pull requests: \(prCount)", value: $prCount, in: 1...120)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run live") { save() }
                }
            }
            .onAppear {
                ownerLogin = accounts.first?.login ?? ""
                personaID = personas.first?.personaID ?? "rustacean"
                let settings = runtime.settings()
                historyYears = max(1, settings.defaultHistoryYears)
                applyHistoryYears(historyYears)
            }
            .task(id: ownerLogin) {
                guard let account = accounts.first(where: { $0.login == ownerLogin }) else { return }
                await runtime.loadHeatmap(for: account)
            }
            .frame(minWidth: 480, minHeight: 420)
        }
    }

    private var ownerRepos: [GitHubRepo] {
        guard let account = accounts.first(where: { $0.login == ownerLogin }) else { return [] }
        let repos = runtime.repositories[account.login] ?? account.cachedRepos
        return repos.sorted { $0.sortDate > $1.sortDate }
    }

    private var name: String {
        let repo = repoName.isEmpty ? "repo" : (RepoRef.parse(repoName, defaultOwner: ownerLogin)?.name ?? repoName)
        switch kind {
        case .history: return "\(historyYears)-year history · \(repo)"
        case .issues: return "Issues · \(repo)"
        case .pullRequests: return "Pull requests · \(repo)"
        }
    }

    private func save() {
        guard let owner = accounts.first(where: { $0.login == ownerLogin }) else {
            errorMessage = "Pick an owner account."
            return
        }
        guard RepoRef.parse(repoName, defaultOwner: owner.login) != nil else {
            errorMessage = GitGardenError.missingRepo.localizedDescription
            return
        }
        let campaign = Campaign(name: name, owner: owner, personaID: personaID)
        campaign.applyKind(kind)
        campaign.dryRun = false
        campaign.dripMode = false
        campaign.throwawayRepo = false
        campaign.commitCount = kind == .history ? commitCount : 0
        campaign.prCount = kind == .pullRequests ? prCount : 0
        campaign.issueCount = kind == .issues ? issueCount : 0
        campaign.startDate = start
        campaign.endDate = end
        campaign.repoName = repoName
        campaign.language = language
        campaign.dripInterval = runtime.settings().dripInterval
        runtime.context.insert(campaign)
        do {
            try runtime.generatePlan(for: campaign)
            try runtime.startCampaign(campaign, live: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyKindDefaults(_ kind: CampaignKind) {
        switch kind {
        case .history:
            applyHistoryYears(historyYears)
        case .issues, .pullRequests:
            start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            end = Date()
        }
    }

    private func applyHistoryYears(_ years: Int) {
        let clamped = min(20, max(1, years))
        historyYears = clamped
        end = Date()
        start = Calendar.current.date(byAdding: .year, value: -clamped, to: end) ?? start
        commitCount = Campaign.suggestedCommitCount(forYears: clamped)
    }
}
