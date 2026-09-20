import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(GardenRuntime.self) private var runtime
    @State private var settings: AppSettings?
    @State private var showClearWork = false
    @State private var clearError: String?

    var body: some View {
        SKPage {
            Text("House rules")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if let settings {
                SettingsForm(settings: settings, showClearWork: $showClearWork)
            }
        }
        .onAppear { settings = runtime.settings() }
        .alert("Clear GitGarden work?", isPresented: $showClearWork) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                do {
                    try runtime.clearGitGardenWork()
                } catch {
                    clearError = error.localizedDescription
                }
            }
        } message: {
            Text("Deletes campaigns, the job queue, audit log, cached graphs, and local worktrees. Saved accounts and GitHub git history are not touched.")
        }
        .alert("Could not clear work", isPresented: Binding(
            get: { clearError != nil },
            set: { if !$0 { clearError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(clearError ?? "")
        }
    }
}

struct SettingsForm: View {
    @Environment(GardenRuntime.self) private var runtime
    @Bindable var settings: AppSettings
    @Binding var showClearWork: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SKCard {
                Toggle("Simulate new campaigns (no GitHub writes)", isOn: $settings.defaultDryRun)
                Stepper("Default history: \(settings.defaultHistoryYears) years", value: $settings.defaultHistoryYears, in: 1...20)
                TextField("Throwaway repo prefix", text: $settings.throwawayPrefix)
                    .textFieldStyle(.roundedBorder)
                Stepper("Drip interval: \(Int(settings.dripInterval))s", value: $settings.dripInterval, in: 5.0...3600.0, step: 5)
            }
            SKCard {
                Text("Worktrees")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                TextField("Custom worktree path", text: $settings.worktreePath)
                    .textFieldStyle(.roundedBorder)
                Text(settings.resolvedWorktreePath.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(SKTheme.mute)
                    .textSelection(.enabled)
            }
            SKCard {
                Text("GitGarden work")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("Clear this app’s cache, campaign history, and session. Git commits already on GitHub stay.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                SKPrimaryButton(title: "Clear cache, history, and session", destructive: true) {
                    showClearWork = true
                }
            }
            SKCard {
                Text("About")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("GitGarden writes real git history and GitHub activity unless you opt into Simulate. New campaigns default to a 10-year backdated window you can shorten or stretch.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
        }
        .onChange(of: settings.defaultDryRun) { _, _ in try? runtime.context.save() }
        .onChange(of: settings.defaultHistoryYears) { _, _ in try? runtime.context.save() }
        .onChange(of: settings.throwawayPrefix) { _, _ in try? runtime.context.save() }
        .onChange(of: settings.worktreePath) { _, _ in try? runtime.context.save() }
        .onChange(of: settings.dripInterval) { _, _ in try? runtime.context.save() }
    }
}
