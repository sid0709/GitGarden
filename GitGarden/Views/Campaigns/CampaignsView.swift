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
            SKBoard {
                column("Queue", statuses: [.draft, .planned])
                column("In Progress", statuses: [.running, .paused])
                column("Done", statuses: [.completed, .failed, .nuked])
            }
            if let campaign = campaigns.first(where: { $0.id == selected }) {
                CampaignDetailView(campaign: campaign)
                    .frame(width: 420)
                    .background(SKTheme.railColor(for: scheme))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(SKTheme.hairline).frame(width: 1)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(SKMotion.spring, value: selected)
        .sheet(isPresented: $showComposer) {
            CampaignComposerView(accounts: accounts, personas: personas)
        }
    }

    private func column(_ title: String, statuses: [CampaignStatus]) -> some View {
        let items = filtered.filter { statuses.contains($0.status) }
        return SKKanbanColumn(title: title, count: items.count) {
            ForEach(items) { campaign in
                Button {
                    withAnimation(SKMotion.spring) {
                        selected = selected == campaign.id ? nil : campaign.id
                    }
                } label: {
                    CampaignBoardCard(campaign: campaign, selected: selected == campaign.id)
                }
                .buttonStyle(.plain)
            }
            if title == "Queue" {
                SKGhostCard(title: "+ Campaign") {
                    showComposer = true
                }
                .disabled(accounts.isEmpty)
                .opacity(accounts.isEmpty ? 0.4 : 1)
            }
        }
    }
}

private struct CampaignBoardCard: View {
    var campaign: Campaign
    var selected: Bool

    var body: some View {
        SKCard(rotateOnHover: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(campaign.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.ink)
                    HStack(spacing: 6) {
                        SKTag(kind: campaign.dryRun ? .dry : .live)
                        if campaign.includeHistory { SKTag(kind: .history) }
                        if campaign.includePRs { SKTag(kind: .pull) }
                        if campaign.includeIssues { SKTag(kind: .issue) }
                    }
                }
                Spacer()
                SKAvatarStack(people: people)
            }
            Text("\(campaign.owner?.login ?? "no owner") · \(campaign.status.rawValue)")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(SKTheme.mute)
        }
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: SKTheme.radiusCard, style: .continuous)
                    .stroke(SKTheme.accent, lineWidth: 1.5)
            }
        }
    }

    private var people: [(url: String, name: String)] {
        var list: [(url: String, name: String)] = []
        if let owner = campaign.owner {
            list.append((owner.avatarURL, owner.login))
        }
        if let collab = campaign.collaborator {
            list.append((collab.avatarURL, collab.login))
        }
        return list
    }
}

struct CampaignComposerView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var accounts: [Account]
    var personas: [PersonaRecord]

    @State private var name = "Two-year sandbox"
    @State private var ownerLogin = ""
    @State private var collaboratorLogin = ""
    @State private var personaID = "rustacean"
    @State private var includeHistory = true
    @State private var includePRs = true
    @State private var includeIssues = true
    @State private var includeProfile = false
    @State private var includeSocial = false
    @State private var dryRun = true
    @State private var dripMode = false
    @State private var throwaway = true
    @State private var commitCount = 80
    @State private var prCount = 6
    @State private var issueCount = 8
    @State private var start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
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
                    DatePicker("Start", selection: $start, displayedComponents: .date)
                    DatePicker("End", selection: $end, displayedComponents: .date)
                    Stepper("Commits: \(commitCount)", value: $commitCount, in: 1...800)
                    Stepper("Pull requests: \(prCount)", value: $prCount, in: 0...80)
                    Stepper("Issues: \(issueCount)", value: $issueCount, in: 0...80)
                }
                Section("Layers") {
                    Toggle("Backdated commit history", isOn: $includeHistory)
                    Toggle("Issue / PR lifecycle", isOn: $includePRs)
                    Toggle("Issues", isOn: $includeIssues)
                    Toggle("Profile bio", isOn: $includeProfile)
                    Toggle("Social follow / star", isOn: $includeSocial)
                    Toggle("Dry-run after compose", isOn: $dryRun)
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
                    Button("Generate plan") { save() }
                }
            }
            .onAppear {
                ownerLogin = accounts.first?.login ?? ""
                personaID = personas.first?.personaID ?? "rustacean"
                dryRun = runtime.settings().defaultDryRun
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
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
