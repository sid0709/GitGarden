import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.colorScheme) private var scheme
    @State private var selection: SidebarItem = .garden
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            SKIconRail(selection: $selection)
            VStack(spacing: 0) {
                SKTopBar(title: "GitGarden", subtitle: selection.title, search: $search)
                ZStack {
                    SKTheme.canvasColor(for: scheme).ignoresSafeArea()
                    page
                        .id(selection)
                        .skSoftTransition()
                }
                .animation(SKMotion.spring, value: selection)
            }
        }
        .background(SKTheme.canvasColor(for: scheme))
        .environment(\.gardenSearch, search)
        .onAppear { runtime.seedDefaults() }
    }

    @ViewBuilder
    private var page: some View {
        switch selection {
        case .garden:
            GardenView()
        case .accounts:
            AccountsView()
        case .campaigns:
            CampaignsView()
        case .queue:
            QueueView()
        case .personas:
            PersonasView()
        case .audit:
            AuditView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    let schema = Schema([Account.self, PersonaRecord.self, Campaign.self, Job.self, CreatedResource.self, AuditEvent.self, CampaignSnapshot.self, AppSettings.self])
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView()
        .environment(GardenRuntime(modelContainer: container))
        .modelContainer(container)
}
