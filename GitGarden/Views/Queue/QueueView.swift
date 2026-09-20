import SwiftUI
import SwiftData

struct QueueView: View {
    @Environment(\.gardenSearch) private var search
    @Query(sort: \Job.scheduledAt) private var jobs: [Job]
    @Query(sort: \Account.login) private var accounts: [Account]

    private var filtered: [Job] {
        guard !search.isEmpty else { return jobs }
        return jobs.filter {
            $0.summary.localizedCaseInsensitiveContains(search)
            || $0.accountLogin.localizedCaseInsensitiveContains(search)
            || ($0.campaign?.name ?? "").localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        SKBoard {
            column("Queue", statuses: [.pending, .skipped])
            column("In Progress", statuses: [.running])
            column("Done", statuses: [.completed])
            column("Blocked", statuses: [.failed, .cancelled])
        }
        .overlay {
            if jobs.isEmpty {
                VStack(spacing: 8) {
                    Text("No jobs yet")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Text("Generate a campaign plan to fill the board.")
                        .foregroundStyle(SKTheme.mute)
                }
            }
        }
    }

    private func column(_ title: String, statuses: [JobStatus]) -> some View {
        let items = filtered.filter { statuses.contains($0.status) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        return SKKanbanColumn(title: title, count: items.count) {
            ForEach(items) { job in
                JobBoardCard(job: job, account: accounts.first { $0.login == job.accountLogin })
            }
        }
    }
}

private struct JobBoardCard: View {
    var job: Job
    var account: Account?

    var body: some View {
        SKCard(rotateOnHover: true) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(job.summary)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(3)
                    HStack(spacing: 6) {
                        SKTag(kind: tagKind)
                        if job.attempt > 1 {
                            SKTag(kind: .ux, label: "Retry \(job.attempt)")
                        }
                    }
                }
                Spacer(minLength: 8)
                if let account {
                    SKAvatar(url: account.avatarURL, name: account.login)
                }
            }
            Text("\(job.kind.title) · \(job.scheduledAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            if !job.lastError.isEmpty {
                Text(job.lastError)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(SKTheme.coral)
                    .lineLimit(2)
            }
        }
    }

    private var tagKind: SKTagKind {
        switch job.kind {
        case .createIssue, .commentIssue, .closeIssue: return .issue
        case .createPR, .reviewPR, .mergePR: return .pull
        case .commit, .push, .createRepo, .createBranch, .createRelease: return .history
        case .follow, .star: return .social
        case .patchProfile: return .profile
        case .inviteCollaborator: return .ux
        }
    }
}
