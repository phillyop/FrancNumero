import Foundation
import SwiftUI

/// A request to open the lesson screen.
struct LessonRequest: Identifiable {
    let id = UUID()
    /// Practise one chapter only. Nil builds the adaptive daily page.
    var chapter: Int? = nil
    /// Numbers that must appear first (used after a torn page).
    var forced: [Int] = []
    /// Take the test-out for this chapter instead of a normal page.
    var testOutChapter: Int? = nil
}

struct LessonSummary {
    let grade: Int
    let pointsEarned: Int
    let streak: Int
    let isDailyPage: Bool
    let guided: Bool
    let newGommettes: [GommetteDef]
    let leveledUpTo: SchoolLevel?
    let excuseEarned: Bool
    let excuseUsed: Bool
    let failed: [Int]
}

/// The result of a chapter test-out.
struct TestOutSummary {
    let chapter: Chapter
    let passed: Bool
    let correct: Int
    let total: Int
    /// The chapter this pass opened, if any.
    let unlocked: Chapter?
    let failed: [Int]
}

enum TestOutStatus {
    case available
    case chapterLocked
    case alreadyCleared
    case triedToday
}

enum ReminderResult { case on, off, denied }

struct DayCell: Identifiable {
    let id: String
    let date: Date?
    let done: Bool
    let excused: Bool
    let isToday: Bool
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published private(set) var todayKey: String
    @Published var lessonRequest: LessonRequest?

    private static let storageKey = "francnumero.appdata.v1"

    init() {
        data = Self.load()
        todayKey = DayKey.key(for: Date())
    }

    // MARK: Persistence

    private static func load() -> AppData {
        guard let raw = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AppData.self, from: raw) else {
            return AppData()
        }
        return decoded
    }

    private func mutate(_ change: (inout AppData) -> Void) {
        var copy = data
        change(&copy)
        data = copy
        if let raw = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(raw, forKey: Self.storageKey)
        }
    }

    func refreshDay() {
        let now = DayKey.key(for: Date())
        if now != todayKey { todayKey = now }
    }

    // MARK: Derived state

    var streak: Int { StreakEngine.displayStreak(data.streak, today: todayKey) }
    var streakStatus: StreakStatus { StreakEngine.status(data.streak, today: todayKey) }
    var completedToday: Bool { data.completedDays.contains(todayKey) }

    var tornToday: Int { data.tornDay == todayKey ? data.tornCount : 0 }
    var lessonMode: LessonEngine.Mode { tornToday >= 2 ? .guided : .standard }

    var level: SchoolLevel { Levels.level(for: data.points) }
    var levelProgress: Double { Levels.progress(for: data.points) }

    var unlockedNumbers: [Int] { Curriculum.numbers(unlockedCount: data.unlockedCount) }

    var dueCount: Int {
        unlockedNumbers.filter { data.records[$0].isDue(today: todayKey) }.count
    }

    var newCount: Int {
        min(SessionBuilder.maxNew, unlockedNumbers.filter { data.records[$0].seen == 0 }.count)
    }

    var solidCount: Int {
        data.records.filter { $0.level == .solid || $0.level == .mastered }.count
    }

    func isUnlocked(_ chapter: Chapter) -> Bool { chapter.id < data.unlockedCount }

    func progress(of chapter: Chapter) -> Double {
        Curriculum.progress(of: chapter, records: data.records)
    }

    func level(of number: Int) -> MasteryLevel {
        data.records.indices.contains(number) ? data.records[number].level : .unseen
    }

    /// The most recent days, oldest first, ending today.
    func lastDays(_ count: Int) -> [DayCell] {
        (0..<count).reversed().map { offset in
            let key = DayKey.adding(-offset, to: todayKey)
            return DayCell(
                id: key,
                date: DayKey.date(from: key),
                done: data.completedDays.contains(key),
                excused: data.excusedDays.contains(key),
                isToday: offset == 0
            )
        }
    }

    // MARK: Building lessons

    func makeLesson(for request: LessonRequest) -> LessonEngine {
        var rng = SystemRandomNumberGenerator()
        let audio = SpeechService.shared.isAvailable

        if let c = request.testOutChapter, Curriculum.chapters.indices.contains(c) {
            let exercises = SessionBuilder.buildTest(
                pool: Curriculum.chapters[c].numbers,
                audioAvailable: audio,
                using: &rng
            )
            return LessonEngine(exercises: exercises, mode: .test)
        }

        let pool: [Int]
        if let c = request.chapter, Curriculum.chapters.indices.contains(c) {
            pool = Curriculum.chapters[c].numbers
        } else {
            pool = unlockedNumbers
        }
        let exercises = SessionBuilder.build(
            pool: pool,
            records: data.records,
            today: todayKey,
            forced: request.forced,
            audioAvailable: audio,
            needsSpellingCard: !data.hasSeenSpellingRules,
            using: &rng
        )
        if exercises.contains(where: { $0.kind == .spelling }) {
            mutate { $0.hasSeenSpellingRules = true }
        }
        return LessonEngine(exercises: exercises, mode: lessonMode)
    }

    // MARK: Test-out

    func testOutStatus(for chapter: Chapter) -> TestOutStatus {
        if !isUnlocked(chapter) { return .chapterLocked }
        if Curriculum.isCleared(chapter, records: data.records) { return .alreadyCleared }
        if data.testOutDay[String(chapter.id)] == todayKey { return .triedToday }
        return .available
    }

    /// Scores a test-out. Passing counts the chapter's untouched numbers as known (they come back in
    /// reviews) and opens the next chapter. A test-out is not a lesson: no points, no streak.
    func completeTestOut(_ engine: LessonEngine, chapterID: Int) -> TestOutSummary {
        let chapter = Curriculum.chapters[min(max(0, chapterID), Curriculum.chapters.count - 1)]
        let correct = engine.correctCount
        let total = engine.gradedCount
        let passed = correct >= SessionBuilder.testPassMark
        let today = todayKey
        let unlockedBefore = data.unlockedCount
        let missedNow = Set(engine.failedNumbers)

        mutate { d in
            d.testOutDay[String(chapter.id)] = today
            guard passed else { return }
            // Passing says "you know this chapter": numbers the test didn't contradict count as known
            // (they still come back in reviews). Only the ones just missed stay marked as shaky.
            for n in chapter.numbers where !missedNow.contains(n) {
                if d.records[n].seen == 0 || d.records[n].box == 0 {
                    d.records[n].seen = max(1, d.records[n].seen)
                    d.records[n].box = 1
                    d.records[n].due = DayKey.adding(2, to: today)
                    d.records[n].lastSeen = today
                }
            }
            Self.advanceUnlocks(&d)
        }

        let opened: Chapter? = (passed && data.unlockedCount > unlockedBefore)
            ? Curriculum.chapters[unlockedBefore]
            : nil
        return TestOutSummary(
            chapter: chapter,
            passed: passed,
            correct: correct,
            total: total,
            unlocked: opened,
            failed: engine.failedNumbers
        )
    }

    // MARK: Recording progress

    /// Called after every graded answer so partial pages still teach the app something.
    func record(_ result: ExerciseResult) {
        let today = todayKey
        mutate { d in
            d.records[result.number].apply(result.outcome, today: today)
            Self.advanceUnlocks(&d)
        }
    }

    func registerTear() {
        let today = todayKey
        mutate { d in
            if d.tornDay == today { d.tornCount += 1 } else { d.tornDay = today; d.tornCount = 1 }
            d.sessions.append(SessionLog(day: today, grade: 0, points: 0, torn: true, guided: false))
            Self.trim(&d)
        }
    }

    /// Banks a finished page: points, streak, log, stickers.
    func completeLesson(_ engine: LessonEngine) -> LessonSummary {
        let today = todayKey
        let isDaily = !completedToday
        let earned = Int((Double(engine.points) * (isDaily ? 1.0 : 0.5)).rounded())
        let levelBefore = Levels.level(for: data.points)
        let rebound = tornToday > 0
        let guided = engine.mode == .guided
        let grade = engine.grade

        var update = StreakUpdate(state: data.streak)
        var stickers: [String] = []

        mutate { d in
            d.points += earned
            update = StreakEngine.complete(d.streak, today: today)
            d.streak = update.state
            if let day = update.excusedDay, !d.excusedDays.contains(day) { d.excusedDays.append(day) }
            if !d.completedDays.contains(today) { d.completedDays.append(today) }
            d.sessions.append(SessionLog(day: today, grade: grade, points: earned, torn: false, guided: guided))
            Self.trim(&d)
            stickers = Self.awardGommettes(&d, today: today, grade: grade, rebound: rebound)
        }

        let levelAfter = Levels.level(for: data.points)
        scheduleNotifications()

        return LessonSummary(
            grade: grade,
            pointsEarned: earned,
            streak: data.streak.current,
            isDailyPage: isDaily,
            guided: guided,
            newGommettes: stickers.compactMap { Gommettes.def(for: $0) },
            leveledUpTo: levelAfter != levelBefore ? levelAfter : nil,
            excuseEarned: update.excuseEarned,
            excuseUsed: update.excusedDay != nil,
            failed: engine.failedNumbers
        )
    }

    private static func advanceUnlocks(_ d: inout AppData) {
        while d.unlockedCount < Curriculum.chapters.count,
              Curriculum.isCleared(Curriculum.chapters[d.unlockedCount - 1], records: d.records) {
            d.unlockedCount += 1
        }
    }

    private static func trim(_ d: inout AppData) {
        if d.sessions.count > 60 { d.sessions.removeFirst(d.sessions.count - 60) }
        if d.completedDays.count > 400 { d.completedDays.removeFirst(d.completedDays.count - 400) }
        if d.excusedDays.count > 100 { d.excusedDays.removeFirst(d.excusedDays.count - 100) }
    }

    private static func awardGommettes(_ d: inout AppData, today: String, grade: Int, rebound: Bool) -> [String] {
        var earned: [String] = []
        func award(_ id: String) {
            if d.gommettes[id] == nil {
                d.gommettes[id] = today
                earned.append(id)
            }
        }

        award("first")
        if d.streak.best >= 3 { award("run3") }
        if d.streak.best >= 7 { award("run7") }
        if d.streak.best >= 14 { award("run14") }
        if d.streak.best >= 30 { award("run30") }
        if grade == 20 { award("perfect") }
        if rebound { award("rebond") }

        for chapter in Curriculum.chapters {
            let answered = chapter.numbers.filter { d.records[$0].correct > 0 }.count
            let genuine = answered * 4 >= chapter.numbers.count * 3
            if genuine && Curriculum.isCleared(chapter, records: d.records) {
                award("chapter\(chapter.id)")
            }
        }
        if d.records.allSatisfy({ $0.box >= 3 }) { award("cent") }
        return earned
    }

    // MARK: Onboarding & settings

    func completeOnboarding(startIndex: Int) {
        let option = Curriculum.startOptions[min(max(0, startIndex), Curriculum.startOptions.count - 1)]
        let today = todayKey
        mutate { d in
            d.hasOnboarded = true
            d.unlockedCount = option.unlockedCount
            // Chapters before the starting point are assumed known and get checked in reviews.
            for chapter in Curriculum.chapters where chapter.id < option.unlockedCount - 1 {
                for n in chapter.numbers {
                    d.records[n].seen = 1
                    d.records[n].box = 1
                    d.records[n].due = today
                    d.records[n].lastSeen = today
                }
            }
        }
    }

    func setAutoPlay(_ on: Bool) {
        mutate { $0.autoPlayAudio = on }
    }

    /// "Unlock all" is for learners who have progressed well beyond the beginner levels.
    var canUnlockAll: Bool { data.points >= Levels.unlockAllLevel.threshold }

    func unlockAllChapters() {
        guard canUnlockAll else { return }
        mutate { $0.unlockedCount = Curriculum.chapters.count }
    }

    func setSoundEffects(_ on: Bool) {
        mutate { $0.soundEffects = on }
    }

    func setHaptics(_ on: Bool) {
        mutate { $0.haptics = on }
    }

    func playEffect(_ effect: SoundEffect) {
        if data.soundEffects { SoundEffects.shared.play(effect) }
    }

    func playHaptic(_ pattern: HapticPattern) {
        if data.haptics { HapticsService.shared.play(pattern) }
    }

    func resetEverything() {
        mutate { $0 = AppData() }
        Task { await NotificationManager.refresh(enabled: false, hour: 19, minute: 0, streak: 0, doneToday: false) }
    }

    // MARK: Reminders

    func setReminder(enabled: Bool, hour: Int, minute: Int) async -> ReminderResult {
        if enabled {
            let granted = await NotificationManager.requestAuthorizationIfNeeded()
            if !granted {
                mutate { $0.reminder.enabled = false }
                await syncNotifications()
                return .denied
            }
        }
        mutate { $0.reminder = ReminderSettings(enabled: enabled, hour: hour, minute: minute) }
        await syncNotifications()
        return enabled ? .on : .off
    }

    func syncNotifications() async {
        await NotificationManager.refresh(
            enabled: data.reminder.enabled,
            hour: data.reminder.hour,
            minute: data.reminder.minute,
            streak: streak,
            doneToday: completedToday
        )
    }

    func scheduleNotifications() {
        Task { await syncNotifications() }
    }
}
