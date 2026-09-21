import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Campaign.updatedAt, order: .reverse) private var campaigns: [Campaign]
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]

    private var running: [Campaign] { campaigns.filter { $0.status == .running } }
    private var pending: [Job] { jobs.filter { $0.status == .pending } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 28 * 0.34, style: .continuous))
                Text("GitGarden")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(SKTheme.inkColor(for: scheme))
                Spacer()
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SKTheme.mute)
                }
                .buttonStyle(.plain)
                .help("Open GitGarden")
            }
            if running.isEmpty {
                Text("No campaigns running")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            } else {
                ForEach(running.prefix(8)) { campaign in
                    HStack {
                        Circle().fill(SKTheme.accent).frame(width: 8, height: 8)
                        Text(campaign.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(SKTheme.inkColor(for: scheme))
                        Spacer()
                        SKTag(kind: campaign.dryRun ? .dry : .running)
                        Button("Pause") { runtime.pauseCampaign(campaign) }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(SKTheme.accent)
                    }
                }
            }
            HStack {
                Text("Queued")
                    .foregroundStyle(SKTheme.mute)
                Spacer()
                Text("\(pending.count)")
                    .fontWeight(.semibold)
                    .foregroundStyle(SKTheme.inkColor(for: scheme))
            }
            .font(.system(size: 13, design: .rounded))
            if let next = runtime.nextFire {
                Text("Next fire \(next.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
            SKPrimaryButton(title: "Process due jobs") {
                runtime.processDueJobs()
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(SKTheme.canvasColor(for: scheme))
    }
}
