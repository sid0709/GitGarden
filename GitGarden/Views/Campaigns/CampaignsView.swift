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
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(filtered) { campaign in
                            Button {
                                withAnimation(SKMotion.spring) { selected = campaign.id }
                            } label: {
                                SKFilmRow(selected: selected == campaign.id) {
                                    VStack(alignment: .leading, spacing: 6) {
                                            Text(campaign.name)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SKTheme.inkColor(for: scheme))
                                            .lineLimit(2)
                                        HStack(spacing: 6) {
                                            SKTag(kind: campaign.dryRun ? .dry : .live)
                                            Text(campaign.status.rawValue)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(SKTheme.mute)
                                        }
                                        if campaign.status == .running {
                                            ProgressView(value: campaign.progress)
                                                .tint(SKTheme.accent)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
            .frame(width: 280)
            .background(SKTheme.railColor(for: scheme))
            .overlay(alignment: .trailing) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }

            if let campaign = campaigns.first(where: { $0.id == selected }) ?? filtered.first {
                CampaignDetailView(campaign: campaign)
            } else {
                VStack(spacing: 10) {
                    Text("Compose a season")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("A campaign is a score: backdated commits, issues, and PRs laid over a decade.")
                        .foregroundStyle(SKTheme.mute)
                    SKPrimaryButton(title: "New campaign", enabled: !accounts.isEmpty) { showComposer = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
    }
}

struct CampaignComposerView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var personas: [PersonaRecord]

    @State private var name = "10-year history"
    @State private var ownerLogin = ""
    @State private var collaboratorLogin = ""
    @State private var personaID = "rustacean"
    @State private var includeHistory = true
    @State private var includePRs = true
    @State private var includeIssues = true
    @State private var includeProfile = false
    @State private var includeSocial = false
    @State private var dryRun = false
    @State private var dripMode = false
    @State private var throwaway = true
    @State private var historyYears = 10
    @State private var commitCount = 400
    @State private var prCount = 30
    @State private var issueCount = 40
    @State private var start = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
    @State private var end = Date()
    @State private var repoName = ""
    @State private var repoDescription = ""
    @State private var language = "rust"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Campaign") {
                    TextField("Name", text: $name)
                    Picker("Owner", selection: $ownerLogin) {
                        ForEach(accounts) { account in
                            Text(account.login).tag(account.login)
                        }
                    }
                    Picker("Collaborator", selection: $collaboratorLogin) {
                        Text("None").tag("")
                        ForEach(accounts.filter { $0.login != ownerLogin }) { account in
                            Text(account.login).tag(account.login)
                        }
                    }
                    Picker("Persona", selection: $personaID) {
                        ForEach(personas) { persona in
                            Text(persona.name).tag(persona.personaID)
                        }
                    }
                    Picker("Language", selection: $language) {
                        Text("Rust").tag("rust")
                        Text("TypeScript").tag("typescript")
                        Text("Go").tag("go")
                    }
                }
                Section("History window") {
                    Stepper("Past \(historyYears) years", value: $historyYears, in: 1...20)
                        .onChange(of: historyYears) { _, years in
                            applyHistoryYears(years)
                        }
                    DatePicker("Start", selection: $start, displayedComponents: .date)
                    DatePicker("End", selection: $end, displayedComponents: .date)
                    Stepper("Commits: \(commitCount)", value: $commitCount, in: 1...2500)
                    Stepper("Pull requests: \(prCount)", value: $prCount, in: 0...120)
                    Stepper("Issues: \(issueCount)", value: $issueCount, in: 0...160)
                    Text("Backdated commits are spread across this window so the GitHub contribution graph fills in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Layers") {
                    Toggle("Backdated commit history", isOn: $includeHistory)
                    Toggle("Issue / PR lifecycle", isOn: $includePRs)
                    Toggle("Issues", isOn: $includeIssues)
                    Toggle("Profile bio", isOn: $includeProfile)
                    Toggle("Social follow / star", isOn: $includeSocial)
                    Toggle("Simulate only (no GitHub writes)", isOn: $dryRun)
                    Toggle("Drip over real time", isOn: $dripMode)
                    Toggle("Throwaway repo prefix", isOn: $throwaway)
                }
                Section("Repo") {
                    TextField("Repo name (optional)", text: $repoName)
                    TextField("Description", text: $repoDescription)
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
                    Button(dryRun ? "Generate plan" : "Generate & run live") { save() }
                }
            }
            .onAppear {
                ownerLogin = accounts.first?.login ?? ""
                personaID = personas.first?.personaID ?? "rustacean"
                let settings = runtime.settings()
                dryRun = settings.defaultDryRun
                historyYears = max(1, settings.defaultHistoryYears)
                applyHistoryYears(historyYears)
            }
            .frame(minWidth: 520, minHeight: 560)
        }
    }

    private func save() {
        guard let owner = accounts.first(where: { $0.login == ownerLogin }) else {
            errorMessage = "Pick an owner account."
            return
        }
        let campaign = Campaign(name: name, owner: owner, collaborator: accounts.first(where: { $0.login == collaboratorLogin }), personaID: personaID)
        campaign.includeHistory = includeHistory
        campaign.includePRs = includePRs
        campaign.includeIssues = includeIssues
        campaign.includeProfile = includeProfile
        campaign.includeSocial = includeSocial
        campaign.dryRun = dryRun
        campaign.dripMode = dripMode
        campaign.throwawayRepo = throwaway
        campaign.commitCount = commitCount
        campaign.prCount = prCount
        campaign.issueCount = issueCount
        campaign.startDate = start
        campaign.endDate = end
        campaign.repoName = repoName
        campaign.repoDescription = repoDescription
        campaign.language = language
        campaign.dripInterval = runtime.settings().dripInterval
        runtime.context.insert(campaign)
        do {
            try runtime.generatePlan(for: campaign)
            if !dryRun {
                try runtime.startCampaign(campaign, live: true)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyHistoryYears(_ years: Int) {
        let clamped = min(20, max(1, years))
        historyYears = clamped
        end = Date()
        start = Calendar.current.date(byAdding: .year, value: -clamped, to: end) ?? start
        commitCount = Campaign.suggestedCommitCount(forYears: clamped)
        prCount = Campaign.suggestedPRCount(forYears: clamped)
        issueCount = Campaign.suggestedIssueCount(forYears: clamped)
        name = clamped == 1 ? "One-year history" : "\(clamped)-year history"
    }
}
