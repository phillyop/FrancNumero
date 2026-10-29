import Foundation

// KEEP IDENTICAL.
// This file exists twice: FrancNumero/Widgets/WidgetSnapshot.swift (the app) and
// WidgetFiles/Shared/WidgetSnapshot.swift (the widget extension). It uses Foundation only,
// so both targets can compile it. If you change one, copy it over the other
// (Tools/check_widget_files.py compares them).

// MARK: - What the app publishes

/// One number a widget can teach.
struct FocusNumber: Codable, Equatable, Identifiable {
    enum Reason: String, Codable {
        case needsWork   // answered wrong recently
        case due         // a review is due
        case new         // not met yet
        case practice    // keeping it fresh
    }

    var n: Int
    var words: String
    /// e.g. "60 + 17". Nil for numbers that are a single word.
    var recipe: String?
    var tip: String?
    var reason: Reason

    var id: Int { n }
}

/// Everything the widgets show, written by the app into the shared App Group container.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroupID = "group.com.theophilusatuahpersonalteam.FrancNumero"
    static let fileName = "widget-snapshot.json"
    static let urlScheme = "francnumero"
    /// Highest number in each chapter, in order.
    static let chapterEnds = [10, 19, 39, 69, 79, 89, 100]

    var updated = Date()
    var hasOnboarded = false

    // The run (streak)
    var streakCurrent = 0
    var streakBest = 0
    var streakLastDay: String?
    var excuses = 0
    var completedDays: [String] = []
    var excusedDays: [String] = []
    var lastGrade = 0
    var lastGradeDay: String?

    // Progress
    var points = 0
    var levelCode = "CP"
    var levelName = "Cours préparatoire"
    var levelProgress = 0.0
    var pointsToNext = 0
    var nextLevelCode: String?
    var solidCount = 0
    /// One value per number, 0 to 100: 0 unseen, 1 shaky, 2 learning, 3 solid, 4 mastered.
    var mastery: [Int] = Array(repeating: 0, count: 101)
    var unlockedUpTo = 10
    var chapterRange = "0 to 10"
    var chapterNickname = "The foundation"
    var chapterProgress = 0.0

    // Today
    var dueCount = 0
    var newCount = 0
    var focus: [FocusNumber] = []
}

// MARK: - Days

extension WidgetSnapshot {
    /// Days are "yyyy-MM-dd" strings in the user's calendar, exactly as in the app.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    static func daysBetween(_ a: String, _ b: String, calendar: Calendar = .current) -> Int {
        guard let da = date(fromKey: a, calendar: calendar),
              let db = date(fromKey: b, calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: da, to: db).day ?? 0
    }

    static func shift(_ key: String, by days: Int, calendar: Calendar = .current) -> String {
        guard let start = date(fromKey: key, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: start) else { return key }
        return dayKey(moved, calendar: calendar)
    }
}

// MARK: - The run on a given day

extension WidgetSnapshot {
    enum RunState: Equatable {
        case fresh        // nothing written yet
        case doneToday
        case waiting      // alive, today's page not written yet
        case protected    // a day was missed and a mot d'excuse will cover it
        case broken
    }

    /// Mirrors the app's streak rules, evaluated for any day, so a widget stays right after midnight
    /// without the app having to run.
    func runState(on day: String) -> RunState {
        guard let last = streakLastDay else { return .fresh }
        let gap = Self.daysBetween(last, day)
        if gap <= 0 { return .doneToday }
        if gap == 1 { return .waiting }
        if gap == 2 && excuses > 0 { return .protected }
        return .broken
    }

    func runLength(on day: String) -> Int {
        switch runState(on: day) {
        case .fresh, .broken: return 0
        case .doneToday, .waiting, .protected: return streakCurrent
        }
    }

    func pageDone(on day: String) -> Bool { completedDays.contains(day) }

    func grade(on day: String) -> Int? { lastGradeDay == day ? lastGrade : nil }

    struct WeekDay: Identifiable, Equatable {
        let id: String
        let letter: String
        let done: Bool
        let excused: Bool
        let isToday: Bool
    }

    /// The seven days ending on `day`, oldest first.
    func week(endingOn day: String, calendar: Calendar = .current) -> [WeekDay] {
        (0..<7).reversed().map { offset in
            let key = Self.shift(day, by: -offset, calendar: calendar)
            var letter = ""
            if let date = Self.date(fromKey: key, calendar: calendar) {
                let symbols = calendar.veryShortWeekdaySymbols
                let index = calendar.component(.weekday, from: date) - 1
                if symbols.indices.contains(index) { letter = symbols[index] }
            }
            return WeekDay(
                id: key,
                letter: letter,
                done: completedDays.contains(key),
                excused: excusedDays.contains(key),
                isToday: offset == 0
            )
        }
    }

    func isUnlocked(_ n: Int) -> Bool { n <= unlockedUpTo }

    func masteryLevel(of n: Int) -> Int {
        mastery.indices.contains(n) ? mastery[n] : 0
    }
}

// MARK: - Which number to show

extension FocusNumber {
    /// Shown when the app hasn't shared anything yet: the numbers French learners trip over most.
    static let starters: [FocusNumber] = [
        FocusNumber(n: 16, words: "seize", recipe: nil, tip: "Not soixante. Seize is sixteen.", reason: .practice),
        FocusNumber(n: 17, words: "dix-sept", recipe: "10 + 7", tip: "From 17, French says ten-seven.", reason: .practice),
        FocusNumber(n: 21, words: "vingt et un", recipe: "20 + 1", tip: "Numbers ending in 1 take “et”.", reason: .practice),
        FocusNumber(n: 60, words: "soixante", recipe: nil, tip: "Sixty is easy. The trouble starts at 70.", reason: .practice),
        FocusNumber(n: 70, words: "soixante-dix", recipe: "60 + 10", tip: "France has no word for 70. It says sixty-ten.", reason: .practice),
        FocusNumber(n: 71, words: "soixante et onze", recipe: "60 + 11", tip: "71 is sixty and eleven.", reason: .practice),
        FocusNumber(n: 77, words: "soixante-dix-sept", recipe: "60 + 17", tip: "Count on from 60: soixante + 17.", reason: .practice),
        FocusNumber(n: 80, words: "quatre-vingts", recipe: "4 × 20", tip: "Four twenties. The s drops when a number follows.", reason: .practice),
        FocusNumber(n: 81, words: "quatre-vingt-un", recipe: "80 + 1", tip: "81 has no “et”.", reason: .practice),
        FocusNumber(n: 91, words: "quatre-vingt-onze", recipe: "80 + 11", tip: "91 has no “et”: quatre-vingt-onze.", reason: .practice),
        FocusNumber(n: 99, words: "quatre-vingt-dix-neuf", recipe: "80 + 19", tip: "Four twenties and nineteen.", reason: .practice),
        FocusNumber(n: 100, words: "cent", recipe: nil, tip: "Just cent. Never “un cent”.", reason: .practice)
    ]
}

extension WidgetSnapshot {
    /// Picks the number for a moment in time. It changes every three hours and cycles through the pool,
    /// so a widget on the home screen quietly teaches all day. `offset` is how far the learner has
    /// tapped "next".
    func focusNumber(at date: Date,
                     reasons: Set<FocusNumber.Reason>? = nil,
                     offset: Int = 0,
                     calendar: Calendar = .current) -> FocusNumber {
        var pool = focus
        if let reasons {
            let filtered = focus.filter { reasons.contains($0.reason) }
            if !filtered.isEmpty { pool = filtered }
        }
        if pool.isEmpty { pool = FocusNumber.starters }

        let hour = calendar.component(.hour, from: date)
        let dayOrdinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let slot = dayOrdinal * 8 + hour / 3
        let count = pool.count
        let index = (((slot + offset) % count) + count) % count
        return pool[index]
    }
}

// MARK: - Saving and loading (App Group container)

extension WidgetSnapshot {
    /// Nil when the App Group isn't set up. Callers treat that as "nothing to share".
    static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL() else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

// MARK: - Deep links (widget taps)

enum WidgetLink {
    enum Target: Equatable {
        case today
        case lesson
        case tableau
        case cahier
        case number(Int)
    }

    static var today: URL { make("today") }
    static var lesson: URL { make("lesson") }
    static var tableau: URL { make("tableau") }
    static var cahier: URL { make("cahier") }
    static func number(_ n: Int) -> URL { make("number/\(n)") }

    private static func make(_ path: String) -> URL {
        URL(string: "\(WidgetSnapshot.urlScheme)://\(path)") ?? URL(fileURLWithPath: "/")
    }

    static func parse(_ url: URL) -> Target? {
        guard url.scheme == WidgetSnapshot.urlScheme else { return nil }
        switch url.host {
        case "today": return .today
        case "lesson": return .lesson
        case "tableau": return .tableau
        case "cahier": return .cahier
        case "number":
            guard let last = url.pathComponents.last, let n = Int(last), (0...100).contains(n) else { return nil }
            return .number(n)
        default:
            return nil
        }
    }
}
