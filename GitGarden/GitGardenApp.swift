import SwiftUI
import SwiftData

@main
struct GitGardenApp: App {
    let sharedModelContainer: ModelContainer
    @State private var runtime: GardenRuntime

    init() {
        let schema = GardenSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            sharedModelContainer = container
            _runtime = State(initialValue: GardenRuntime(modelContainer: container))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(runtime)
                .onAppear { runtime.start() }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1280, height: 840)

        MenuBarExtra("GitGarden", systemImage: "leaf.fill") {
            MenuBarView()
                .environment(runtime)
                .modelContainer(sharedModelContainer)
        }
        .menuBarExtraStyle(.window)
    }
}
