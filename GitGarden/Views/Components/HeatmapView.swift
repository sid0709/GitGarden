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
                total: slice.reduce(0) { $0 + $1.total }
            )
        }
    }

    static func weeks(from days: [HeatmapDay]) -> [[HeatmapDay]] {
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
}

struct HeatmapView: View {
    var days: [HeatmapDay]
    var showsPlanned: Bool = true

    var body: some View {
        Canvas { context, size in
            let weeks = HeatmapYears.weeks(from: days)
            guard !weeks.isEmpty else { return }
            let gap = max(1.5, min(3, size.width / 220))
            let cell = min(14, max(5, (size.width - gap * CGFloat(weeks.count + 1)) / CGFloat(weeks.count)))
            let graphHeight = cell * 7 + gap * 6
            let originY = max(0, (size.height - graphHeight) / 2)
            var x = gap
            for week in weeks {
                var y = originY
                for day in week {
                    let rect = CGRect(x: x, y: y, width: cell, height: cell)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: max(1.5, cell * 0.22)),
                        with: .color(color(for: day))
                    )
                    y += cell + gap
                }
                x += cell + gap
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 84, idealHeight: 104, maxHeight: 120)
        .accessibilityLabel("Contribution heatmap")
    }

    private func color(for day: HeatmapDay) -> Color {
        let value = showsPlanned ? day.total : day.existing
        switch value {
        case 0: return Color.primary.opacity(0.08)
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
    @State private var selectedYear: Int?

    private var groups: [HeatmapYearGroup] {
        HeatmapYears.groups(from: days)
    }

    private var selected: HeatmapYearGroup? {
        groups.first { $0.year == selectedYear } ?? groups.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if groups.isEmpty {
                Text("No contribution calendar yet")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(SKTheme.mute)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(groups) { group in
                            Button {
                                selectedYear = group.year
                            } label: {
                                Text(String(group.year))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(selected?.year == group.year ? Color.white : SKTheme.mute)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        selected?.year == group.year ? SKTheme.accent : SKTheme.accentSoft,
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.visible, axes: .horizontal)
                if let selected {
                    HStack {
                        Text("\(selected.total) contributions in \(selected.year)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                    }
                    HeatmapView(days: selected.days, showsPlanned: showsPlanned)
                }
            }
        }
        .onAppear { selectedYear = selectedYear ?? groups.first?.year }
        .onChange(of: groups.map(\.year)) { _, years in
            if selectedYear == nil || !(years.contains(selectedYear ?? 0)) {
                selectedYear = years.first
            }
        }
    }
}
