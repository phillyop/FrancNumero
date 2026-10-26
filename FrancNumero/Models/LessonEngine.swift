import Foundation

struct ExerciseResult: Equatable {
    let number: Int
    let kind: ExerciseKind
    let outcome: Outcome
}

/// The rules of one lesson page, with no UI in it.
///
/// - Each question has a number of tries (see `SessionBuilder.tries`). With two tries, the first
///   miss is free: a hint appears and the learner tries again for half points.
/// - The last miss crosses the answer out in red pen (a "rature") and reveals it.
/// - Third rature: the page is torn. Its points are lost and a fresh page starts after a short
///   correction. After two torn pages in a day, pages become "guided" (two tries everywhere, hints
///   up front, no tearing) so the learner can always finish and keep their streak.
/// - A chapter test-out is "test" mode: one try, no hints, no points, no tearing.
/// - An accent or one-letter slip in a typed answer is a near miss: it costs nothing.
struct LessonEngine {
    enum Mode { case standard, guided, test }

    enum Step: Equatable {
        case answering
        case resolved(Outcome)
        case torn
        case finished
    }

    static let maxRatures = 3
    static let maxNearMisses = 2

    let exercises: [Exercise]
    let mode: Mode

    private(set) var index = 0
    private(set) var step: Step = .answering
    private(set) var attempt = 1
    private(set) var struckChoices: Set<Int> = []
    private(set) var results: [ExerciseResult] = []
    private(set) var ratures = 0
    private(set) var points = 0
    private(set) var nearMisses = 0
    private(set) var nearMissNote: String?
    /// Counters the UI uses to trigger haptics and sounds.
    private(set) var correctTicks = 0
    private(set) var missTicks = 0
    private(set) var nearMissTicks = 0

    init(exercises: [Exercise], mode: Mode) {
        self.exercises = exercises
        self.mode = mode
        // An empty page is already over.
        if exercises.isEmpty { step = .finished }
    }

    // MARK: Reading state

    var current: Exercise? {
        exercises.indices.contains(index) ? exercises[index] : nil
    }

    /// Exercises that are graded (everything except teaching cards).
    var gradedCount: Int { exercises.filter { !$0.kind.isCard }.count }

    var isCard: Bool { current?.kind.isCard ?? false }

    var isLast: Bool { index == exercises.count - 1 }

    /// How far through the page the learner is. It counts exercises that are *finished*, so the
    /// bar is empty at the start and reaches 100% on the last answer, before the mark appears.
    var progress: Double {
        guard !exercises.isEmpty else { return 1 }
        if step == .finished { return 1 }
        var done = index
        if case .resolved = step { done += 1 }
        return min(1, Double(done) / Double(exercises.count))
    }

    /// Tries allowed for a given question in this mode.
    func tries(for exercise: Exercise) -> Int {
        switch mode {
        case .test: return 1
        case .guided: return max(2, exercise.tries)
        case .standard: return max(1, exercise.tries)
        }
    }

    var currentTries: Int { current.map { tries(for: $0) } ?? 1 }

    /// A short label for the learner: how many tries this question has.
    var triesLabel: String? {
        guard let ex = current, !ex.kind.isCard, step == .answering else { return nil }
        if mode == .test { return "Test: one try" }
        if currentTries == 1 { return "One try. You know this one." }
        return attempt >= 2 ? "Last try" : "Two tries"
    }

    /// A hint is shown after a miss, and up front in guided mode.
    var visibleHint: String? {
        guard let ex = current, !ex.kind.isCard, step == .answering, mode != .test else { return nil }
        if attempt >= 2 || mode == .guided { return FrenchNumber.hint(for: ex.number) }
        return nil
    }

    var failedNumbers: [Int] {
        var seen = Set<Int>()
        return results.filter { $0.outcome == .failed }.map { $0.number }.filter { seen.insert($0).inserted }
    }

    var correctCount: Int { results.filter { $0.outcome != .failed }.count }

    /// Two marks for a clean answer, one after a hint, none when missed.
    var marks: Int {
        results.reduce(0) { total, r in
            switch r.outcome {
            case .first: return total + 2
            case .second: return total + 1
            case .failed: return total
            }
        }
    }

    /// The school-style mark out of 20.
    var grade: Int {
        let possible = gradedCount * 2
        guard possible > 0 else { return 0 }
        return Int((Double(marks) / Double(possible) * 20).rounded())
    }

    var ratureWarning: Bool { mode == .standard && ratures == Self.maxRatures - 1 }

    func pointValue(for outcome: Outcome) -> Int {
        switch (mode, outcome) {
        case (_, .failed), (.test, _): return 0
        case (.standard, .first): return 10
        case (.standard, .second): return 5
        case (.guided, .first): return 5
        case (.guided, .second): return 2
        }
    }

    // MARK: Actions

    /// Move past a teaching card.
    mutating func acknowledgeCard() {
        guard step == .answering, isCard else { return }
        advance()
    }

    mutating func submit(_ answer: Answer) {
        guard step == .answering, let ex = current, !ex.kind.isCard else { return }

        let verdict = ex.judge(answer)
        if verdict == .correct {
            nearMissNote = nil
            resolve(attempt == 1 ? .first : .second, number: ex.number, kind: ex.kind)
            return
        }

        // A near miss costs nothing, a couple of times per question.
        if case .nearMiss(let note) = verdict, nearMisses < Self.maxNearMisses {
            nearMisses += 1
            nearMissNote = note
            nearMissTicks += 1
            return
        }

        registerMiss(answer, for: ex)
    }

    /// Continue after the feedback for an answer.
    mutating func next() {
        guard case .resolved(let outcome) = step else { return }
        if outcome == .failed && mode == .standard && ratures >= Self.maxRatures {
            step = .torn
            return
        }
        advance()
    }

    // MARK: Private

    private mutating func registerMiss(_ answer: Answer, for ex: Exercise) {
        missTicks += 1
        nearMissNote = nil
        if case .choice(let n) = answer { struckChoices.insert(n) }

        if attempt < tries(for: ex) {
            attempt += 1
        } else {
            resolve(.failed, number: ex.number, kind: ex.kind)
        }
    }

    private mutating func resolve(_ outcome: Outcome, number: Int, kind: ExerciseKind) {
        results.append(ExerciseResult(number: number, kind: kind, outcome: outcome))
        points += pointValue(for: outcome)
        if outcome == .failed {
            if mode == .standard { ratures += 1 }
        } else {
            correctTicks += 1
        }
        step = .resolved(outcome)
    }

    private mutating func advance() {
        nearMisses = 0
        nearMissNote = nil
        if index + 1 < exercises.count {
            index += 1
            attempt = 1
            struckChoices = []
            step = .answering
        } else {
            step = .finished
        }
    }
}

/// The teacher's remark for a mark out of 20, in French with an English gloss.
enum Remark {
    static func forGrade(_ grade: Int) -> (french: String, english: String) {
        switch grade {
        case 20: return ("Parfait !", "Perfect.")
        case 18...19: return ("Excellent !", "Excellent.")
        case 16...17: return ("Très bien", "Very good.")
        case 14...15: return ("Bien", "Good.")
        case 12...13: return ("Assez bien", "Fairly good.")
        case 10...11: return ("Peut mieux faire", "Could do better. You’re close.")
        default: return ("Courage !", "Keep going. Every page helps.")
        }
    }

    /// Marks at or above this are "excellent": the page gets a celebratory buzz.
    static let excellentFrom = 18

    static let praise = ["Bravo !", "Exact !", "Très bien !", "Parfait !", "Bien joué !"]
    static let secondChance = ["Cette fois, oui !", "Voilà !", "Ça y est !"]
    static let nearMiss = ["Presque !", "Pas tout à fait.", "Encore un essai."]
}
