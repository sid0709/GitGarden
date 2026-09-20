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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .animation(SKMotion.spring, value: selection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 960, minHeight: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    let schema = GardenSchema.schema
    let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView()
        .environment(GardenRuntime(modelContainer: container))
        .modelContainer(container)
}
