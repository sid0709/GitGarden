import SwiftUI
import SwiftData

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
            SKBoard {
                SKKanbanColumn(title: "Accounts", count: filtered.count) {
                    ForEach(filtered) { account in
                        Button {
                            withAnimation(SKMotion.spring) {
                                selected = selected == account.id ? nil : account.id
                            }
                        } label: {
                            SKCard(rotateOnHover: true) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(account.login)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(SKTheme.ink)
                                        SKTag(
                                            kind: account.isFineGrained ? .ux : .ui,
                                            label: account.scopes.isEmpty ? "fine-grained" : account.scopes.prefix(2).joined(separator: ", ")
                                        )
                                    }
                                    Spacer()
                                    SKAvatar(url: account.avatarURL, name: account.login, size: 34)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    SKGhostCard(title: "+ Account") { showAdd = true }
                }
            }
            if let account = accounts.first(where: { $0.id == selected }) {
                AccountDetailView(account: account, personas: personas)
                    .frame(width: 420)
                    .background(SKTheme.railColor(for: scheme))
                    .overlay(alignment: .leading) { Rectangle().fill(SKTheme.hairline).frame(width: 1) }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(SKMotion.spring, value: selected)
        .sheet(isPresented: $showAdd) {
            AddAccountSheet(personas: personas)
        }
    }
}

struct AccountDetailView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Bindable var account: Account
    var personas: [PersonaRecord]
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SKAvatar(url: account.avatarURL, name: account.login, size: 48)
                    VStack(alignment: .leading) {
                        Text(account.displayName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("@\(account.login)")
                            .foregroundStyle(SKTheme.mute)
                    }
                }
                SKCard {
                    LabeledContent("Email", value: account.email.isEmpty ? "—" : account.email)
                    Picker("Persona", selection: $account.personaID) {
                        ForEach(personas) { persona in
                            Text(persona.name).tag(persona.personaID)
                        }
                    }
                }
                SKCard {
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
                SKCard {
                    LabeledContent("Remaining", value: "\(account.rateLimitRemaining) / \(account.rateLimitLimit)")
                    if let reset = account.rateLimitReset {
                        LabeledContent("Resets", value: reset.formatted())
                    }
                }
                SKPrimaryButton(title: busy ? "Validating…" : "Revalidate", enabled: !busy) {
                    Task {
                        busy = true
                        defer { busy = false }
                        do { try await runtime.validate(account: account) }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            .padding(22)
        }
        .alert("Validation failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
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
