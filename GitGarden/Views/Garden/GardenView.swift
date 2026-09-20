import SwiftUI
import SwiftData

struct GardenView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Query(sort: \Account.login) private var accounts: [Account]
    @Query(sort: \Campaign.updatedAt, order: .reverse) private var campaigns: [Campaign]
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]

    private var visibleAccounts: [Account] {
        guard !search.isEmpty else { return accounts }
        return accounts.filter { $0.login.localizedCaseInsensitiveContains(search) || $0.displayName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        SKBoard {
            SKKanbanColumn(title: "Pulse", count: 4) {
                SKCard {
                    Text("Accounts")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(accounts.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    SKTag(kind: .ui, label: "Connected")
                }
                SKCard {
                    Text("Campaigns")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(campaigns.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    SKTag(kind: .ux, label: "Plans")
                }
                SKCard {
                    Text("Running")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(campaigns.filter { $0.status == .running }.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    SKTag(kind: .running)
                }
                SKCard {
                    Text("Queued jobs")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("\(jobs.filter { $0.status == .pending }.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    if let next = runtime.nextFire {
                        Text("Next \(next.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                    }
                    SKTag(kind: .pending)
                }
            }

            SKKanbanColumn(title: "Accounts", count: visibleAccounts.count) {
                if visibleAccounts.isEmpty {
                    SKCard {
                        Text("Add an account")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("Paste a classic PAT with repo, user, and delete_repo.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                    }
                }
                ForEach(visibleAccounts) { account in
                    AccountGardenCard(
                        account: account,
                        campaigns: campaigns.filter { $0.involvedLogins.contains(account.login) }
                    )
                }
            }
        }
    }
}

private struct AccountGardenCard: View {
    var account: Account
    var campaigns: [Campaign]

    var body: some View {
        SKCard(rotateOnHover: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(account.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("@\(account.login)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    HStack(spacing: 6) {
                        SKTag(kind: account.isFineGrained ? .ux : .ui, label: account.isFineGrained ? "Fine-grained" : "Classic PAT")
                        SKTag(kind: .pending, label: "\(account.rateLimitRemaining) left")
                    }
                }
                Spacer()
                SKAvatar(url: account.avatarURL, name: account.login, size: 32)
            }
            if let plan = campaigns.first(where: { $0.plan != nil })?.plan {
                HeatmapView(days: plan.heatmap)
                    .padding(.top, 8)
            }
            Text("\(campaigns.filter { $0.status == .running }.count) running · \(campaigns.count) campaigns")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(SKTheme.mute)
        }
    }
}
