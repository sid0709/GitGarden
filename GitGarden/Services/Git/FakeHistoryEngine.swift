import Foundation

nonisolated enum InnoHistory {
    static let fileName = "hello.txt"
    static let pressure = 300
    static let density = 2

    static func commitDates(from start: Date, to end: Date, maxCommits: Int, seed: UInt64) -> [Date] {
        var rng = SeededGenerator(seed: seed)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: min(end, Date()))
        var dates: [Date] = []
        while cursor <= last {
            let weekday = calendar.component(.weekday, from: cursor)
            let isWeekday = weekday >= 2 && weekday <= 6
            var count = commitsOnDay(isWeekday: isWeekday, rng: &rng)
            for offset in 0..<count {
                dates.append(cursor.addingTimeInterval(TimeInterval(10 * 3600 + offset)))
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? last.addingTimeInterval(86400)
            if dates.count > 20_000 { break }
        }
        let cap = max(maxCommits, 1)
        if dates.count <= cap { return dates }
        let step = Double(dates.count) / Double(cap)
        return (0..<cap).map { dates[min(Int(Double($0) * step), dates.count - 1)] }
    }

    static func commitsOnDay(isWeekday: Bool, rng: inout SeededGenerator) -> Int {
        if isWeekday {
            var count = gitBlockCount(rng: &rng) * density
            if count > 0 {
                count -= rng.int(in: 0...(density - 1))
            }
            return max(0, count)
        }
        if rng.int(in: 0...9) == 0 {
            return rng.int(in: 0...3)
        }
        return 0
    }

    static func gitBlockCount(rng: inout SeededGenerator) -> Int {
        let v0 = pressure
        let v1 = 100
        let v2 = 100
        let v3 = 50
        let v4 = 25
        let ran = rng.int(in: 0...(v0 + v1 + v2 + v3 + v4 - 1))
        if ran < v0 { return 0 }
        if ran < v0 + v1 { return 1 }
        if ran < v0 + v1 + v2 { return 2 }
        if ran < v0 + v1 + v2 + v3 { return 3 }
        return 4
    }
}

nonisolated struct FakeHistoryEngine: Sendable {
    var git: any GitRunning
    var fileManager: FileManager = .default

    init(git: any GitRunning = GitProcess()) {
        self.git = git
    }

    func apply(dates: [Date], at url: URL, name: String, email: String) throws {
        let engine = BackdatedCommitEngine(git: git)
        let file = url.appendingPathComponent(InnoHistory.fileName)
        var ticks = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        for date in dates {
            ticks.append("a")
            try ticks.write(to: file, atomically: true, encoding: .utf8)
            try engine.commit(at: url, message: "chore: tick", date: date, name: name, email: email)
        }
    }
}
