import SwiftUI
import SwiftData
import AppKit

struct AccountsView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Account.login) private var accounts: [Account]
    @Query(sort: \PersonaRecord.name) private var personas: [PersonaRecord]
    @State private var showAdd = false
    @State private var selected: Account.ID?

    private var filtered: [Account] {
        guard !search.isEmpty else { return accounts }
        return accounts.filter {
            $0.login.localizedCaseInsensitiveContains(search) || $0.displayName.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Roster")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    Spacer()
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SKTheme.accent)
                            .frame(width: 28, height: 28)
                            .background(SKTheme.accentSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { account in
                            Button {
                                withAnimation(SKMotion.spring) { selected = account.id }
                                Task { await runtime.loadHeatmap(for: account) }
                            } label: {
                                SKFilmRow(selected: selected == account.id) {
                                    HStack(spacing: 10) {
                                        SKAvatar(url: account.avatarURL, name: account.login, size: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(account.login)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundStyle(SKTheme.inkColor(for: scheme))
                                            Text("\(account.rateLimitRemaining) remaining")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(SKTheme.mute)
                                            if let created = account.githubCreatedAt {
                                                Text("Joined \(created.formatted(.dateTime.month(.abbreviated).year()))")
                                                    .font(.system(size: 11, design: .rounded))
                                                    .foregroundStyle(SKTheme.mute)
                                            }
                                        }
                                        Spacer(minLength: 0)
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
                if let account = accounts.first(where: { $0.id == selected }) ?? filtered.first {
                    AccountDetailView(account: account, personas: personas)
                } else {
                    VStack(spacing: 10) {
                        Text("No operators yet")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        SKPrimaryButton(title: "Add account") { showAdd = true }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if selected == nil { selected = accounts.first?.id } }
        .sheet(isPresented: $showAdd) {
            AddAccountSheet(personas: personas)
        }
    }
}

struct AccountDetailView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Bindable var account: Account
    var personas: [PersonaRecord]
    @State private var busy = false
    @State private var errorMessage: String?

    private var days: [HeatmapDay] {
        runtime.heatmaps[account.login] ?? account.cachedHeatmap
    }

    private var repos: [GitHubRepo] {
        runtime.repositories[account.login] ?? account.cachedRepos
    }

    private var orgs: [GitHubOrg] {
        runtime.organizations[account.login] ?? account.cachedOrgs
    }

    var body: some View {
        SKPage {
            HStack {
                SKAvatar(url: account.avatarURL, name: account.login, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("@\(account.login)")
                        .foregroundStyle(SKTheme.mute)
                }
                Spacer()
                if let url = URL(string: account.htmlURL), !account.htmlURL.isEmpty {
                    SKQuietButton(title: "GitHub") { NSWorkspace.shared.open(url) }
                }
                SKPrimaryButton(title: busy ? "Refreshing…" : "Revalidate", enabled: !busy) {
                    Task {
                        busy = true
                        defer { busy = false }
                        do {
                            try await runtime.validate(account: account)
                            await runtime.loadHeatmap(for: account)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            AccountStatGrid(account: account, days: days, repos: repos)
            AccountProfileFacts(account: account)

            HStack {
                Text("Contribution history")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                if runtime.heatmapLoading.contains(account.login) {
                    ProgressView().controlSize(.small)
                }
            }
            ContributionHistoryView(days: days, showsPlanned: false)

            OrgListView(orgs: orgs)
            RepoListView(repos: repos, query: search)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("GitHub ID", value: account.githubID == 0 ? "—" : "\(account.githubID)")
                LabeledContent("Created", value: account.githubCreatedAt?.formatted() ?? "—")
                LabeledContent("Updated", value: account.githubUpdatedAt?.formatted() ?? "—")
                LabeledContent("Email", value: account.email.isEmpty ? "—" : account.email)
                LabeledContent("Company", value: account.company.isEmpty ? "—" : account.company)
                LabeledContent("Location", value: account.location.isEmpty ? "—" : account.location)
                LabeledContent("Blog", value: account.blog.isEmpty ? "—" : account.blog)
                LabeledContent("Twitter", value: account.twitter.isEmpty ? "—" : "@\(account.twitter)")
                LabeledContent("Followers", value: "\(account.followers)")
                LabeledContent("Following", value: "\(account.following)")
                LabeledContent("Public repos", value: "\(account.publicRepos)")
                LabeledContent("Private repos", value: "\(account.totalPrivateRepos)")
                LabeledContent("Owned private", value: "\(account.ownedPrivateRepos)")
                LabeledContent("Public gists", value: "\(account.publicGists)")
                LabeledContent("Collaborators", value: "\(account.collaboratorCount)")
                LabeledContent("Disk", value: account.diskUsage == 0 ? "—" : "\(account.diskUsage) KB")
                LabeledContent("Plan", value: account.planName.isEmpty ? "—" : account.planName)
                LabeledContent("Type", value: account.accountType.isEmpty ? "—" : account.accountType)
                LabeledContent("Hireable", value: account.hireable ? "Yes" : "No")
                LabeledContent("2FA", value: account.twoFactorEnabled ? "On" : "Unknown / off")
                Picker("Persona", selection: $account.personaID) {
                    ForEach(personas) { persona in
                        Text(persona.name).tag(persona.personaID)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SecureField("Personal access token", text: $account.token)
                if account.isFineGrained {
                    Text("Fine-grained token — classic scope warnings skipped.")
                        .font(.caption)
                        .foregroundStyle(SKTheme.mute)
                } else {
                    Text(account.scopes.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(SKTheme.mute)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SKRateBar(remaining: account.rateLimitRemaining, limit: max(account.rateLimitLimit, 1))
                if let reset = account.rateLimitReset {
                    LabeledContent("Resets", value: reset.formatted())
                }
                if let validated = account.lastValidatedAt {
                    LabeledContent("Validated", value: validated.formatted())
                }
            }
            SKPrimaryButton(title: "Remove account", destructive: true) {
                do { try runtime.deleteAccount(account) }
                catch { errorMessage = error.localizedDescription }
            }
        }
        .alert("Validation failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await runtime.loadHeatmap(for: account)
        }
    }
}

struct AddAccountSheet: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.dismiss) private var dismiss
    var personas: [PersonaRecord]
    @State private var token = ""
    @State private var personaID = "rustacean"
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal access token") {
                    SecureField("ghp_… or github_pat_…", text: $token)
                    Text("Classic PAT with repo, user, delete_repo, and workflow if you edit Actions files.")
                        .foregroundStyle(.secondary)
                }
                Section("Persona") {
                    Picker("Default persona", selection: $personaID) {
                        ForEach(personas) { persona in
                            Text(persona.name).tag(persona.personaID)
                        }
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Checking…" : "Validate") {
                        Task {
                            busy = true
                            defer { busy = false }
                            do {
                                _ = try await runtime.addAccount(token: token, personaID: personaID)
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
                }
            }
            .frame(minWidth: 420, minHeight: 280)
        }
    }
}
