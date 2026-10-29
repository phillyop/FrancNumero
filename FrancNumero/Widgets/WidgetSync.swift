import Foundation
import WidgetKit

/// Publishes what the home-screen and lock-screen widgets show.
///
/// The app writes a small JSON snapshot into the shared App Group container and asks WidgetKit to
/// redraw. If the App Group isn't set up (see WIDGETS.md) nothing is written and the app carries on:
/// the widgets simply fall back to their "open FrancNumero" state.
@MainActor
enum WidgetSync {
    static func snapshot(from store: AppStore) -> WidgetSnapshot {
        let data = store.data
        let level = store.level
        let next = Levels.next(after: level)

        var s = WidgetSnapshot()
        s.updated = Date()
        s.hasOnboarded = data.hasOnboarded

        s.streakCurrent = data.streak.current
        s.streakBest = data.streak.best
        s.streakLastDay = data.streak.lastDay
        s.excuses = data.streak.excuses
        s.completedDays = Array(data.completedDays.suffix(21))
        s.excusedDays = Array(data.excusedDays.suffix(21))
        if let last = data.sessions.last(where: { !$0.torn }) {
            s.lastGrade = last.grade
            s.lastGradeDay = last.day
        }

        s.points = data.points
        s.levelCode = level.code
        s.levelName = level.name
        s.levelProgress = store.levelProgress
        s.pointsToNext = next.map { max(0, $0.threshold - data.points) } ?? 0
        s.nextLevelCode = next?.code
        s.solidCount = store.solidCount
        s.mastery = data.records.map { $0.level.rawValue }

        let unlockedIndex = min(max(1, data.unlockedCount), Curriculum.chapters.count) - 1
        s.unlockedUpTo = Curriculum.chapters[unlockedIndex].range.upperBound

        let unlocked = Curriculum.chapters.filter { store.isUnlocked($0) }
        let working = unlocked.first { !Curriculum.isCleared($0, records: data.records) }
            ?? unlocked.last
            ?? Curriculum.chapters[0]
        s.chapterRange = working.rangeLabel
        s.chapterNickname = working.nickname
        s.chapterProgress = store.progress(of: working)

        s.dueCount = store.dueCount
        s.newCount = store.newCount
        s.focus = focusList(store)
        return s
    }

    /// The numbers a widget rotates through: what needs work first, then reviews, new numbers,
    /// and finally the weakest of the rest.
    private static func focusList(_ store: AppStore) -> [FocusNumber] {
        let records = store.data.records
        let today = store.todayKey
        let pool = store.unlockedNumbers
        var list: [FocusNumber] = []
        var used = Set<Int>()

        func add(_ n: Int, _ reason: FocusNumber.Reason) {
            guard !used.contains(n), list.count < 20 else { return }
            used.insert(n)
            list.append(FocusNumber(
                n: n,
                words: FrenchNumber.words(for: n),
                recipe: FrenchNumber.anatomy(for: n).recipe,
                tip: FrenchNumber.tip(for: n),
                reason: reason
            ))
        }

        let shaky = pool.filter { records[$0].seen > 0 && records[$0].box == 0 }
        for n in shaky.prefix(6) { add(n, .needsWork) }

        let due = pool
            .filter { records[$0].isDue(today: today) && !used.contains($0) }
            .sorted { (records[$0].due ?? "") < (records[$1].due ?? "") }
        for n in due.prefix(6) { add(n, .due) }

        let fresh = pool.filter { records[$0].seen == 0 }
        for n in fresh.prefix(4) { add(n, .new) }

        let rest = pool
            .filter { records[$0].seen > 0 && !used.contains($0) }
            .sorted { records[$0].box < records[$1].box }
        for n in rest {
            if list.count >= 12 { break }
            add(n, .practice)
        }

        if list.isEmpty {
            for n in pool.prefix(8) { add(n, .new) }
        }
        return list
    }

    /// Writes the snapshot. Cheap, so it runs after every change.
    static func write(_ store: AppStore) {
        snapshot(from: store).save()
    }

    /// Asks WidgetKit to redraw. Reserved for moments that matter (a finished page, a new day),
    /// because the system budgets how often widgets may refresh.
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
