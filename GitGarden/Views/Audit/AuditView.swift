import SwiftUI
import SwiftData

struct AuditView: View {
    @Environment(\.gardenSearch) private var search
    @Query(sort: \AuditEvent.timestamp, order: .reverse) private var events: [AuditEvent]
    @State private var page = 0

    private var filtered: [AuditEvent] {
        guard !search.isEmpty else { return events }
        return events.filter {
            $0.path.localizedCaseInsensitiveContains(search)
            || $0.accountLogin.localizedCaseInsensitiveContains(search)
            || $0.message.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        SKPage {
            Text("Flight recorder")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            if filtered.isEmpty {
                SKCard {
                    Text("No API calls yet")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Validate a token or run a campaign. Tokens are redacted here.")
                        .foregroundStyle(SKTheme.mute)
                }
            } else {
                ForEach(SKPaging.slice(filtered, page: page)) { event in
                    SKCard(padding: 14, lift: false) {
                        HStack {
                            Text(event.method)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            SKTag(kind: event.statusCode >= 400 ? .failed : .ui, label: "\(event.statusCode)")
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                        }
                        Text(event.path)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .lineLimit(2)
                        Text("\(event.accountLogin) · \(event.campaignName.isEmpty ? "—" : event.campaignName)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(SKTheme.mute)
                        if !event.message.isEmpty {
                            Text(event.message)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                                .lineLimit(2)
                        }
                    }
                }
                SKPagerBar(page: $page, total: filtered.count, noun: "events")
            }
        }
        .onChange(of: search) { _, _ in page = 0 }
    }
}
