import Foundation

// MARK: - Day keys

/// Days are stored as "yyyy-MM-dd" strings in the user's calendar.
/// They sort in date order and never drift with time zones.
enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    /// Whole days from `a` to `b` (positive when `b` is later).
    static func daysBetween(_ a: String, _ b: String, calendar: Calendar = .current) -> Int {
        guard let da = date(from: a, calendar: calendar),
              let db = date(from: b, calendar: calendar) else { return 0 }
        return calendar.dateComponents([.day], from: da, to: db).day ?? 0
    }

    static func adding(_ days: Int, to day: String, calendar: Calendar = .current) -> String {
        guard let start = date(from: day, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: start) else { return day }
        return Self.key(for: moved, calendar: calendar)
    }
}

// MARK: - Streak

/// A streak survives one missed day if the learner holds a "mot d'excuse"
/// (a note from home). One is earned for every 7 days in a row, up to 2 saved.
struct StreakState: Codable, Equatable {
    var current = 0
    var best = 0
    var lastDay: String?
    var excuses = 0
}

enum StreakStatus: Equatable {
    case fresh            // nothing logged yet
    case doneToday
    case waiting          // alive, today's page not written yet
    case protected        // a day was missed; an excuse note will cover it
    case broken           // run ended
}

struct StreakUpdate {
    var state: StreakState
    /// The missed day an excuse note covered, if one was used.
    var excusedDay: String?
    var excuseEarned = false
    var increased = false
}

enum StreakEngine {
    static let maxExcuses = 2

    static func status(_ s: StreakState, today: String, calendar: Calendar = .current) -> StreakStatus {
        guard let last = s.lastDay else { return .fresh }
        let gap = DayKey.daysBetween(last, today, calendar: calendar)
        if gap <= 0 { return .doneToday }
        if gap == 1 { return .waiting }
        if gap == 2 && s.excuses > 0 { return .protected }
        return .broken
    }

    /// The number to show on screen: zero once the run has ended.
    static func displayStreak(_ s: StreakState, today: String, calendar: Calendar = .current) -> Int {
        switch status(s, today: today, calendar: calendar) {
        case .fresh, .broken: return 0
        case .doneToday, .waiting, .protected: return s.current
        }
    }

    /// Call once when a page is completed on `today`.
    static func complete(_ s: StreakState, today: String, calendar: Calendar = .current) -> StreakUpdate {
        var next = s
        var update = StreakUpdate(state: s)

        guard let last = s.lastDay else {
            next.current = 1
            next.lastDay = today
            next.best = max(next.best, 1)
            update.state = next
            update.increased = true
            return update
        }

        let gap = DayKey.daysBetween(last, today, calendar: calendar)
        if gap <= 0 { return update }   // already counted today

        if gap == 1 {
            next.current += 1
            update.increased = true
        } else if gap == 2 && s.excuses > 0 {
            next.excuses -= 1
            next.current += 1
            update.excusedDay = DayKey.adding(-1, to: today, calendar: calendar)
            update.increased = true
        } else {
            next.current = 1
            update.increased = true
        }

        next.lastDay = today
        next.best = max(next.best, next.current)
        if update.increased, next.current % 7 == 0, next.excuses < maxExcuses {
            next.excuses += 1
            update.excuseEarned = true
        }
        update.state = next
        return update
    }
}
