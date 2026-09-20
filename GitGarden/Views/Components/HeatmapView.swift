import SwiftUI
import SwiftData

struct HeatmapView: View {
    var days: [HeatmapDay]
    var showsPlanned: Bool = true

    private var weeks: [[HeatmapDay]] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let lookup = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        let dates = days.compactMap { formatter.date(from: $0.date) }.sorted()
        guard let first = dates.first, let last = dates.last else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var cursor = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: first)) ?? first
        var weeks: [[HeatmapDay]] = []
        while cursor <= last {
            var week: [HeatmapDay] = []
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: cursor) ?? cursor
                let key = formatter.string(from: day)
                week.append(lookup[key] ?? HeatmapDay(date: key, existing: 0, planned: 0))
            }
            weeks.append(week)
            cursor = calendar.date(byAdding: .day, value: 7, to: cursor) ?? last.addingTimeInterval(86400)
            if weeks.count > 80 { break }
        }
        return weeks
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 2) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 2) {
                        ForEach(week, id: \.date) { day in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color(for: day))
                                .frame(width: 11, height: 11)
                                .help("\(day.date): \(day.existing) existing, \(day.planned) planned")
                        }
                    }
                }
            }
            .padding(4)
        }
        .frame(minHeight: 90)
    }

    private func color(for day: HeatmapDay) -> Color {
        let value = showsPlanned ? day.total : day.existing
        switch value {
        case 0: return Color.black.opacity(0.05)
        case 1: return Color(red: 0.72, green: 0.93, blue: 0.72)
        case 2...3: return Color(red: 0.47, green: 0.84, blue: 0.55)
        case 4...6: return Color(red: 0.31, green: 0.72, blue: 0.45)
        default: return Color(red: 0.16, green: 0.55, blue: 0.32)
        }
    }
}

struct StatCard: View {
    var title: String
    var value: String
    var subtitle: String = ""

    var body: some View {
        SKCard {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(SKTheme.mute)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            }
        }
    }
}
