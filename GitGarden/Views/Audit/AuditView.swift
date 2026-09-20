import SwiftUI
import SwiftData

struct AuditView: View {
    @Environment(\.gardenSearch) private var search
    @Query(sort: \AuditEvent.timestamp, order: .reverse) private var events: [AuditEvent]

    private var filtered: [AuditEvent] {
        guard !search.isEmpty else { return events }
        return events.filter {
            $0.path.localizedCaseInsensitiveContains(search)
            || $0.accountLogin.localizedCaseInsensitiveContains(search)
            || $0.message.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        SKBoard {
            SKKanbanColumn(title: "Calls", count: filtered.count) {
                ForEach(filtered) { event in
                    SKCard {
                        HStack {
                            Text(event.method)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            SKTag(
                                kind: event.statusCode >= 400 ? .failed : .ui,
                                label: "\(event.statusCode)"
                            )
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
            }
        }
        .overlay {
            if events.isEmpty {
                Text("No API calls yet")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
        }
    }
}
