import SwiftUI

nonisolated struct HeatmapYearGroup: Identifiable, Hashable, Sendable {
    var year: Int
    var days: [HeatmapDay]
    var total: Int
    var id: Int { year }
}

nonisolated enum HeatmapYears {
    static func groups(from days: [HeatmapDay]) -> [HeatmapYearGroup] {
        var buckets: [Int: [HeatmapDay]] = [:]
        for day in days {
            guard let year = Int(day.date.prefix(4)) else { continue }
            buckets[year, default: []].append(day)
        }
        return buckets.keys.sorted(by: >).map { year in
            let slice = (buckets[year] ?? []).sorted { $0.date < $1.date }
            return HeatmapYearGroup(
                year: year,
                days: slice,
                total: slice.reduce(0) { $0 + $1.existing }
            )
        }
    }
}

struct HeatmapView: View {
    var days: [HeatmapDay]
    var showsPlanned: Bool = true
    var cell: CGFloat = 11

    private var weeks: [[HeatmapDay]] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let lookup = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { _, last in last })
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
            if weeks.count > 62 { break }
        }
        return weeks
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: max(2, cell * 0.18)) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: max(2, cell * 0.18)) {
                        ForEach(week, id: \.date) { day in
                            RoundedRectangle(cornerRadius: max(2, cell * 0.22), style: .continuous)
                                .fill(color(for: day))
                                .frame(width: cell, height: cell)
                                .help("\(day.date): \(day.existing) existing, \(day.planned) planned")
                        }
                    }
                }
            }
            .padding(4)
        }
        .frame(minHeight: cell * 7 + 16)
    }

    private func color(for day: HeatmapDay) -> Color {
        let value = showsPlanned ? day.total : day.existing
        switch value {
        case 0: return Color.primary.opacity(0.06)
        case 1: return Color(red: 0.72, green: 0.93, blue: 0.72)
        case 2...3: return Color(red: 0.47, green: 0.84, blue: 0.55)
        case 4...6: return Color(red: 0.31, green: 0.72, blue: 0.45)
        default: return Color(red: 0.16, green: 0.55, blue: 0.32)
        }
    }
}

struct ContributionHistoryView: View {
    var days: [HeatmapDay]
    var showsPlanned: Bool = false
    var cell: CGFloat = 11

    private var groups: [HeatmapYearGroup] {
        HeatmapYears.groups(from: days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if groups.isEmpty {
                Text("No contribution calendar yet")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            } else {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(group.total) contributions in \(group.year)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            Spacer()
                            Text(String(group.year))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                        }
                        HStack(alignment: .center, spacing: 8) {
                            HeatmapView(days: group.days, showsPlanned: showsPlanned, cell: cell)
                            Text(String(group.year))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(SKTheme.mute)
                                .frame(width: 36, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}
