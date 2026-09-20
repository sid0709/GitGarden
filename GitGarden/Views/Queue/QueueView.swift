import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(GardenRuntime.self) private var runtime
    @Environment(\.gardenSearch) private var search
    @Query(sort: \Job.orderIndex) private var jobs: [Job]
    @Query(sort: \Account.login) private var accounts: [Account]
    @State private var errorMessage: String?

    private var filtered: [Job] {
        let sorted = jobs.sorted { lhs, rhs in
            if lhs.scheduledAt != rhs.scheduledAt { return lhs.scheduledAt < rhs.scheduledAt }
            return lhs.orderIndex < rhs.orderIndex
        }
        guard !search.isEmpty else { return sorted }
        return sorted.filter {
            $0.summary.localizedCaseInsensitiveContains(search)
            || $0.accountLogin.localizedCaseInsensitiveContains(search)
            || ($0.campaign?.name ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    private var nowIndex: Int? {
        filtered.firstIndex { $0.status == .running } ?? filtered.firstIndex { $0.status == .pending }
    }

    var body: some View {
        SKPage {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sequencer")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SKTheme.mute)
                    Text("Jobs in time, not columns")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
                if let next = runtime.nextFire {
                    SKTag(kind: .pending, label: "Next \(next.formatted(date: .omitted, time: .shortened))")
                }
                SKQuietButton(title: "Process due") { runtime.processDueJobs() }
            }

            if filtered.isEmpty {
                SKCard {
                    Text("The tape is blank")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Generate a campaign plan. Jobs land here as a single score you can skip, retry, or let drip.")
                        .foregroundStyle(SKTheme.mute)
                }
            } else {
                ForEach(Array(filtered.enumerated()), id: \.element.persistentModelID) { index, job in
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(StatusTint.color(for: job.status))
                                .frame(width: index == nowIndex ? 12 : 8, height: index == nowIndex ? 12 : 8)
                                .shadow(color: index == nowIndex ? SKTheme.accent.opacity(0.6) : .clear, radius: 8)
                            if index < filtered.count - 1 {
                                Rectangle()
                                    .fill(SKTheme.hairline)
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 16)
                        SKCard(padding: 14, rotateOnHover: job.status == .running) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(job.summary)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    HStack(spacing: 6) {
                                        SKTag(kind: job.tagKind)
                                        if job.attempt > 1 { SKTag(kind: .ux, label: "Retry \(job.attempt)") }
                                        if job.status == .running { SKTag(kind: .running) }
                                    }
                                    Text("\(job.campaign?.name ?? "—") · \(job.accountLogin) · \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(SKTheme.mute)
                                    if !job.lastError.isEmpty {
                                        Text(job.lastError)
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(SKTheme.coral)
                                    }
                                }
                                Spacer()
                                if let account = accounts.first(where: { $0.login == job.accountLogin }) {
                                    SKAvatar(url: account.avatarURL, name: account.login)
                                }
                            }
                            HStack {
                                if job.status == .failed {
                                    SKQuietButton(title: "Retry") {
                                        do { try runtime.retryJob(job) }
                                        catch { errorMessage = error.localizedDescription }
                                    }
                                }
                                if job.status == .pending {
                                    SKQuietButton(title: "Skip") { runtime.skipJob(job) }
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .alert("Queue error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

extension Job {
    var tagKind: SKTagKind {
        switch kind {
        case .createIssue, .commentIssue, .closeIssue: return .issue
        case .createPR, .reviewPR, .mergePR: return .pull
        case .commit, .push, .createRepo, .createBranch, .createRelease: return .history
        case .follow, .star: return .social
        case .patchProfile: return .profile
        case .inviteCollaborator: return .ux
        }
    }
}
