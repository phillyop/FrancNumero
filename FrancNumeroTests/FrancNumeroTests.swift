import XCTest
@testable import FrancNumero

// Optional. To run these: File > New > Target > Unit Testing Bundle (name it
// FrancNumeroTests), then drag this file into that target.

final class FrenchNumberTests: XCTestCase {
    func testTrickyNumbers() {
        let expected: [Int: String] = [
            0: "zéro", 16: "seize", 17: "dix-sept", 21: "vingt et un",
            71: "soixante et onze", 77: "soixante-dix-sept", 80: "quatre-vingts",
            81: "quatre-vingt-un", 91: "quatre-vingt-onze",
            99: "quatre-vingt-dix-neuf", 100: "cent"
        ]
        for (number, words) in expected {
            XCTAssertEqual(FrenchNumber.words(for: number), words)
        }
    }

    func testTokensRoundTrip() {
        for n in 0...100 {
            XCTAssertEqual(FrenchNumber.join(FrenchNumber.tokens(for: n)), FrenchNumber.words(for: n))
        }
    }

    func testAnatomy() {
        XCTAssertEqual(FrenchNumber.anatomy(for: 77).equation, "60 + 17 = 77")
        XCTAssertEqual(FrenchNumber.anatomy(for: 80).equation, "4 × 20 = 80")
        XCTAssertEqual(FrenchNumber.anatomy(for: 91).equation, "80 + 11 = 91")
        XCTAssertNil(FrenchNumber.anatomy(for: 12).equation)
    }
}

final class TypedAnswerTests: XCTestCase {
    func testAcceptedSpellings() {
        XCTAssertEqual(FrenchNumber.judge(typed: "soixante-dix-sept", for: 77), .correct)
        XCTAssertEqual(FrenchNumber.judge(typed: "  Soixante dix sept ", for: 77), .correct)
        XCTAssertEqual(FrenchNumber.judge(typed: "vingt-et-un", for: 21), .correct)
        XCTAssertEqual(FrenchNumber.judge(typed: "quatre-vingts", for: 80), .correct)
    }

    func testNearMissesAreForgiven() {
        guard case .nearMiss = FrenchNumber.judge(typed: "zero", for: 0) else { return XCTFail("accent slip") }
        guard case .nearMiss = FrenchNumber.judge(typed: "quatre-vingt", for: 80) else { return XCTFail("missing s") }
        guard case .nearMiss = FrenchNumber.judge(typed: "soixante-dix-sep", for: 77) else { return XCTFail("typo") }
    }

    func testAnotherRealNumberIsNeverForgiven() {
        XCTAssertEqual(FrenchNumber.judge(typed: "dix", for: 6), .wrong)   // six vs dix is one letter apart
        XCTAssertEqual(FrenchNumber.judge(typed: "sept", for: 77), .wrong)
        XCTAssertEqual(FrenchNumber.judge(typed: "", for: 5), .wrong)
    }

    func testSlowSpeechKeepsLiaisonsWhole() {
        XCTAssertEqual(FrenchNumber.speechSegments(for: 77), ["soixante", "dix-sept"])
        XCTAssertEqual(FrenchNumber.speechSegments(for: 71), ["soixante", "et onze"])
        XCTAssertEqual(FrenchNumber.speechSegments(for: 18), ["dix-huit"])
        XCTAssertEqual(FrenchNumber.speechSegments(for: 22), ["vingt-deux"])
        XCTAssertEqual(FrenchNumber.speechSegments(for: 91), ["quatre-vingt", "onze"])
    }
}

final class LessonEngineTests: XCTestCase {
    private func readExercise(_ n: Int) -> Exercise {
        var rng = SystemRandomNumberGenerator()
        return ExerciseFactory.make(number: n, kind: .read, using: &rng)
    }

    private func wrongAnswer(for exercise: Exercise) -> Answer {
        let wrong = exercise.choices.first { $0.number != exercise.number }!
        return .choice(wrong.number)
    }

    func testFirstMissIsFreeAndSecondChanceScoresHalf() {
        var engine = LessonEngine(exercises: [readExercise(5)], mode: .standard)
        engine.submit(wrongAnswer(for: engine.current!))
        XCTAssertEqual(engine.attempt, 2)
        XCTAssertEqual(engine.ratures, 0)
        engine.submit(.choice(5))
        XCTAssertEqual(engine.step, .resolved(.second))
        XCTAssertEqual(engine.points, 5)
    }

    func testThreeRaturesTearThePage() {
        var engine = LessonEngine(exercises: (3...8).map(readExercise), mode: .standard)
        for _ in 0..<3 {
            engine.submit(wrongAnswer(for: engine.current!))
            engine.submit(wrongAnswer(for: engine.current!))
            engine.next()
        }
        XCTAssertEqual(engine.step, .torn)
        XCTAssertEqual(engine.ratures, 3)
    }

    func testGuidedPagesNeverTear() {
        var engine = LessonEngine(exercises: (3...6).map(readExercise), mode: .guided)
        for _ in 0..<4 {
            engine.submit(wrongAnswer(for: engine.current!))
            engine.submit(wrongAnswer(for: engine.current!))
            engine.next()
        }
        XCTAssertEqual(engine.step, .finished)
        XCTAssertEqual(engine.ratures, 0)
    }

    func testOneTryQuestionFailsImmediately() {
        var exercise = readExercise(5)
        exercise.tries = 1
        var engine = LessonEngine(exercises: [exercise], mode: .standard)
        engine.submit(wrongAnswer(for: exercise))
        XCTAssertEqual(engine.step, .resolved(.failed))
        XCTAssertEqual(engine.ratures, 1)
    }

    func testTestModeIsOneTryNoPoints() {
        var engine = LessonEngine(exercises: (3...12).map(readExercise), mode: .test)
        for _ in 0..<10 {
            engine.submit(wrongAnswer(for: engine.current!))
            engine.next()
        }
        XCTAssertEqual(engine.step, .finished)   // never tears
        XCTAssertEqual(engine.points, 0)
    }

    func testNearMissCostsNothing() {
        var rng = SystemRandomNumberGenerator()
        let exercise = ExerciseFactory.make(number: 0, kind: .write, using: &rng)
        var engine = LessonEngine(exercises: [exercise], mode: .standard)
        engine.submit(.text("zero"))
        XCTAssertEqual(engine.attempt, 1)
        XCTAssertNotNil(engine.nearMissNote)
        engine.submit(.text("zéro"))
        XCTAssertEqual(engine.step, .resolved(.first))
    }

    func testProgressBarIsFullOnTheLastAnswer() {
        var engine = LessonEngine(exercises: (0..<4).map(readExercise), mode: .standard)
        XCTAssertEqual(engine.progress, 0)
        for _ in 0..<4 {
            engine.submit(.choice(engine.current!.number))
            if engine.isLast { XCTAssertEqual(engine.progress, 1) }
            engine.next()
        }
        XCTAssertEqual(engine.step, .finished)
    }

    func testGradeOutOfTwenty() {
        var engine = LessonEngine(exercises: (0..<10).map(readExercise), mode: .standard)
        for i in 0..<10 {
            let ex = engine.current!
            if i < 8 {
                engine.submit(.choice(ex.number))
            } else {
                engine.submit(wrongAnswer(for: ex))
                engine.submit(.choice(ex.number))
            }
            engine.next()
        }
        XCTAssertEqual(engine.grade, 18)   // 8 x 2 + 2 x 1 marks
    }
}

final class StreakTests: XCTestCase {
    func testExcuseNoteCoversOneMissedDay() {
        var state = StreakState()
        var day = "2026-10-01"
        for _ in 0..<7 {
            state = StreakEngine.complete(state, today: day).state
            day = DayKey.adding(1, to: day)
        }
        XCTAssertEqual(state.current, 7)
        XCTAssertEqual(state.excuses, 1)

        // Skip a day, come back the next.
        let result = StreakEngine.complete(state, today: DayKey.adding(1, to: day))
        XCTAssertEqual(result.state.current, 8)
        XCTAssertEqual(result.state.excuses, 0)
        XCTAssertEqual(result.excusedDay, day)
    }

    func testTwoMissedDaysBreakTheRun() {
        var state = StreakState()
        state = StreakEngine.complete(state, today: "2026-10-01").state
        XCTAssertEqual(StreakEngine.displayStreak(state, today: "2026-10-04"), 0)
        XCTAssertEqual(StreakEngine.complete(state, today: "2026-10-04").state.current, 1)
    }
}
