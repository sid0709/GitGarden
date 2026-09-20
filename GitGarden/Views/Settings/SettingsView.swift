import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(GardenRuntime.self) private var runtime
    @State private var settings: AppSettings?

    var body: some View {
        SKBoard {
            SKKanbanColumn(title: "Defaults", count: 3) {
                if let settings {
                    SKCard {
                        Toggle("Dry-run new campaigns", isOn: Bindable(settings).defaultDryRun)
                        TextField("Throwaway repo prefix", text: Bindable(settings).throwawayPrefix)
                            .textFieldStyle(.roundedBorder)
                        Stepper("Drip interval: \(Int(settings.dripInterval))s", value: Bindable(settings).dripInterval, in: 5.0...3600.0, step: 5)
                    }
                    SKCard {
                        Text("Worktrees")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        TextField("Custom worktree path", text: Bindable(settings).worktreePath)
                            .textFieldStyle(.roundedBorder)
                        Text(settings.resolvedWorktreePath.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(SKTheme.mute)
                            .textSelection(.enabled)
                    }
                    SKCard {
                        Text("About")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("GitGarden is a personal operator console. Tokens stay in the local SwiftData store.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                    }
                }
            }
        }
        .onAppear { settings = runtime.settings() }
        .onChange(of: settings?.defaultDryRun) { _, _ in try? runtime.context.save() }
        .onChange(of: settings?.throwawayPrefix) { _, _ in try? runtime.context.save() }
        .onChange(of: settings?.worktreePath) { _, _ in try? runtime.context.save() }
        .onChange(of: settings?.dripInterval) { _, _ in try? runtime.context.save() }
    }
}
