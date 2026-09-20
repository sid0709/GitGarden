import SwiftUI
import AppKit

struct AccountProfileFacts: View {
    var account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !account.bio.isEmpty {
                Text(account.bio)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
            FlowFacts(items: facts)
        }
    }

    private var facts: [String] {
        var items: [String] = []
        if let created = account.githubCreatedAt {
            items.append("Joined \(created.formatted(.dateTime.month(.abbreviated).year()))")
        }
        if !account.location.isEmpty { items.append(account.location) }
        if !account.company.isEmpty { items.append(account.company) }
        if !account.email.isEmpty { items.append(account.email) }
        if !account.blog.isEmpty { items.append(account.blog) }
        if !account.twitter.isEmpty { items.append("@\(account.twitter)") }
        if !account.planName.isEmpty { items.append("Plan \(account.planName)") }
        if !account.accountType.isEmpty { items.append(account.accountType) }
        if account.twoFactorEnabled { items.append("2FA on") }
        if account.hireable { items.append("Hireable") }
        if account.githubID > 0 { items.append("ID \(account.githubID)") }
        return items
    }
}

private struct FlowFacts: View {
    var items: [String]

    var body: some View {
        FlexibleFactRow(items: items)
    }
}

private struct FlexibleFactRow: View {
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.chunked(into: 3).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SKTheme.accentSoft, in: Capsule())
                    }
                }
            }
        }
    }
}

struct AccountStatGrid: View {
    var account: Account
    var days: [HeatmapDay]
    var repos: [GitHubRepo]

    private var contributions: Int {
        let live = days.reduce(0) { $0 + $1.existing }
        return live > 0 ? live : account.contributionTotal
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            SKMetricChip(title: "Repos", value: "\(max(account.totalRepoCount, repos.count))", kind: .history)
            SKMetricChip(title: "Followers", value: "\(account.followers)", kind: .social)
            SKMetricChip(title: "Following", value: "\(account.following)", kind: .profile)
            SKMetricChip(title: "Contributions", value: "\(contributions)", kind: .ui)
        }
    }
}

struct RepoListView: View {
    var repos: [GitHubRepo]
    var query: String = ""
    @Environment(\.colorScheme) private var scheme
    @State private var page = 0

    private var filtered: [GitHubRepo] {
        let sorted = repos.sorted { $0.sortDate > $1.sortDate }
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.fullName.localizedCaseInsensitiveContains(query)
            || ($0.description ?? "").localizedCaseInsensitiveContains(query)
            || ($0.language ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    private var visible: [GitHubRepo] {
        SKPaging.slice(filtered, page: page, pageSize: 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Repositories")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                Spacer()
                Text("\(filtered.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
            if filtered.isEmpty {
                Text("No repositories visible to this token")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            } else {
                ForEach(visible, id: \.id) { repo in
                    Button {
                        if let url = URL(string: repo.htmlUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        SKFilmRow(selected: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(repo.fullName)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SKTheme.inkColor(for: scheme))
                                    if repo.private {
                                        SKTag(kind: .pending, label: "Private")
                                    }
                                    if repo.fork == true {
                                        SKTag(kind: .ux, label: "Fork")
                                    }
                                    if repo.archived == true {
                                        SKTag(kind: .failed, label: "Archived")
                                    }
                                    Spacer()
                                }
                                if let description = repo.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(SKTheme.mute)
                                        .lineLimit(2)
                                }
                                HStack(spacing: 12) {
                                    if let language = repo.language, !language.isEmpty {
                                        Text(language)
                                    }
                                    Text("★ \(repo.stars)")
                                    if let forks = repo.forksCount {
                                        Text("Forks \(forks)")
                                    }
                                    if let pushed = GitHubDate.parse(repo.pushedAt) {
                                        Text("Pushed \(pushed.formatted(.dateTime.month(.abbreviated).day().year()))")
                                    }
                                }
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                SKPagerBar(page: $page, total: filtered.count, pageSize: 12, noun: "repos")
            }
        }
    }
}

struct OrgListView: View {
    var orgs: [GitHubOrg]

    var body: some View {
        if !orgs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Organizations")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                    ForEach(orgs, id: \.id) { org in
                        SKFilmRow(selected: false) {
                            HStack(spacing: 10) {
                                SKAvatar(url: org.avatarUrl ?? "", name: org.login, size: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(org.login)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    if let description = org.description, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(SKTheme.mute)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
