import Foundation

/// Fake learners for the widget gallery and for Xcode previews. Not used on a real Home Screen.
extension WidgetSnapshot {
    /// Five days in a row, today's page not written yet.
    static var sample: WidgetSnapshot { make(doneToday: false) }

    /// Today's page written, 17 out of 20.
    static var sampleDone: WidgetSnapshot { make(doneToday: true) }

    /// A brand-new learner.
    static var sampleFresh: WidgetSnapshot {
        var s = WidgetSnapshot()
        s.hasOnboarded = true
        s.newCount = 4
        s.focus = FocusNumber.starters.prefix(4).map { starter -> FocusNumber in
            var f = starter
            f.reason = .new
            return f
        }
        return s
    }

    private static func make(doneToday: Bool) -> WidgetSnapshot {
        var s = WidgetSnapshot()
        let today = dayKey(Date())
        let first = doneToday ? 0 : 1

        s.hasOnboarded = true
        s.streakCurrent = 5
        s.streakBest = 12
        s.streakLastDay = shift(today, by: -first)
        s.completedDays = (first..<(first + 5)).map { shift(today, by: -$0) }
        s.excuses = 1
        s.lastGrade = 17
        s.lastGradeDay = shift(today, by: -first)

        s.points = 340
        s.levelCode = "CE1"
        s.levelName = "Cours élémentaire 1"
        s.levelProgress = 0.28
        s.pointsToNext = 160
        s.nextLevelCode = "CE2"

        s.mastery = (0...100).map { n -> Int in
            if n < 28 { return 4 }
            if n < 52 { return (n % 7 == 0) ? 2 : 3 }
            if n < 70 { return (n % 5 == 0) ? 1 : 2 }
            if n < 78 { return (n % 3 == 0) ? 1 : 2 }
            return 0
        }
        s.solidCount = s.mastery.filter { $0 >= 3 }.count
        s.unlockedUpTo = 79
        s.chapterRange = "70 to 79"
        s.chapterNickname = "Sixty-ten"
        s.chapterProgress = 0.6
        s.dueCount = 6
        s.newCount = 4

        let reasons: [FocusNumber.Reason] = [.needsWork, .due, .new, .practice]
        s.focus = FocusNumber.starters.prefix(8).enumerated().map { pair -> FocusNumber in
            var f = pair.element
            f.reason = reasons[pair.offset % reasons.count]
            return f
        }
        return s
    }
}
