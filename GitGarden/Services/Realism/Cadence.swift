import Foundation

nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func double() -> Double {
        Double(next() % 10_000_000) / 10_000_000.0
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(span))
    }

    mutating func pick<T>(_ items: [T]) -> T {
        precondition(!items.isEmpty, "pick from empty collection")
        return items[int(in: 0...(items.count - 1))]
    }
}

nonisolated struct CadenceSampler: Sendable {
    var calendar: Calendar

    init(timezone: String = "America/Chicago") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? .current
        self.calendar = calendar
    }

    func sampleDates(count: Int, from start: Date, to end: Date, persona: Persona, rng: inout SeededGenerator) -> [Date] {
        guard count > 0, end > start else { return [] }
        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var daySlots: [Date] = []
        while cursor <= last {
            if !isVacation(cursor, persona: persona) {
                let weekday = calendar.component(.weekday, from: cursor)
                let isWeekend = weekday == 1 || weekday == 7
                let include = !isWeekend || rng.double() < persona.weekendWeight
                if include {
                    daySlots.append(cursor)
                }
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? last.addingTimeInterval(86400)
        }
        if daySlots.isEmpty { return [] }

        var remaining = count
        var index = 0
        while remaining > 0 {
            let day = daySlots[index % daySlots.count]
            let burst: Int
            let roll = rng.double()
            if roll < 0.55 { burst = 1 }
            else if roll < 0.85 { burst = 2 }
            else { burst = rng.int(in: 3...4) }
            let take = min(burst, remaining)
            for offset in 0..<take {
                let stamped = stamp(on: day, index: offset, persona: persona, rng: &rng)
                dates.append(min(max(stamped, start), end))
            }
            remaining -= take
            index += 1
            if index > daySlots.count * 8 { break }
        }
        return dates.sorted()
    }

    func stamp(on day: Date, index: Int, persona: Persona, rng: inout SeededGenerator) -> Date {
        let hour = rng.int(in: persona.workingHours.start...max(persona.workingHours.start, persona.workingHours.end - 1))
        let minute = rng.int(in: 0...59)
        let second = rng.int(in: 0...59)
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = min(59, minute + index * 3)
        components.second = second
        return calendar.date(from: components) ?? day
    }

    func isVacation(_ day: Date, persona: Persona) -> Bool {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MM-dd"
        let stamp = formatter.string(from: day)
        for gap in persona.vacationGaps {
            if gap.start <= gap.end {
                if stamp >= gap.start && stamp <= gap.end { return true }
            } else {
                if stamp >= gap.start || stamp <= gap.end { return true }
            }
        }
        return false
    }
}

nonisolated enum MessageGenerator {
    static func fill(_ template: String, slug: String, issue: Int? = nil) -> String {
        var text = template.replacingOccurrences(of: "{slug}", with: slug)
        if let issue {
            text = text.replacingOccurrences(of: "{issue}", with: String(issue))
            text = text.replacingOccurrences(of: "#{issue}", with: "#\(issue)")
        }
        return text
    }

    static func commitMessage(persona: Persona, slug: String, rng: inout SeededGenerator) -> String {
        fill(rng.pick(persona.messages), slug: slug)
    }

    static func branchName(persona: Persona, slug: String, rng: inout SeededGenerator) -> String {
        fill(rng.pick(persona.branchPatterns), slug: slug)
    }
}

nonisolated struct HeatmapBuilder: Sendable {
    static func build(dates: [Date], existing: [HeatmapDay] = []) -> [HeatmapDay] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        var counts: [String: Int] = [:]
        for date in dates {
            let key = formatter.string(from: date)
            counts[key, default: 0] += 1
        }
        var existingMap: [String: Int] = [:]
        for day in existing {
            existingMap[day.date] = day.existing
        }
        var keys = Set(counts.keys).union(existingMap.keys)
        if keys.isEmpty {
            keys.insert(formatter.string(from: Date()))
        }
        return keys.sorted().map { key in
            HeatmapDay(date: key, existing: existingMap[key] ?? 0, planned: counts[key] ?? 0)
        }
    }
}
