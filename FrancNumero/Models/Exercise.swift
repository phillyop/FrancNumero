import Foundation

// MARK: - Model

enum ExerciseKind: String, Codable {
    case intro       // teaching card for a brand-new number
    case spelling    // one-time teaching card: the rules for writing numbers
    case read        // see digits, pick the French words
    case decode      // see French words, pick the digits (the silent twin of listen)
    case listen      // hear French, pick the digits
    case build       // see digits, assemble the French from tiles
    case dictation   // hear French, type the digits
    case write       // see digits, type the French words
    case transcribe  // hear French, type the French words

    var usesAudio: Bool {
        self == .listen || self == .dictation || self == .intro || self == .transcribe
    }

    /// Teaching cards are not graded and have no answer.
    var isCard: Bool { self == .intro || self == .spelling }

    /// Exercises where the learner types French words.
    var typesWords: Bool { self == .write || self == .transcribe }
}

struct Choice: Identifiable, Hashable {
    let number: Int
    let label: String
    var id: Int { number }
}

enum Answer {
    case choice(Int)
    case tokens([String])
    case typed(Int)
    case text(String)
}

/// How an answer was judged. A near miss (an accent or one-letter slip) costs nothing.
enum Verdict: Equatable {
    case correct
    case nearMiss(String)
    case wrong
}

struct Exercise: Identifiable {
    let id = UUID()
    let number: Int
    let kind: ExerciseKind
    var choices: [Choice] = []
    var bank: [String] = []
    /// How many tries this question allows. The engine can raise or lower it by mode.
    var tries = 2

    func judge(_ answer: Answer) -> Verdict {
        switch answer {
        case .choice(let n), .typed(let n):
            return n == number ? .correct : .wrong
        case .tokens(let t):
            return t == FrenchNumber.tokens(for: number) ? .correct : .wrong
        case .text(let s):
            return FrenchNumber.judge(typed: s, for: number)
        }
    }

    func isCorrect(_ answer: Answer) -> Bool { judge(answer) == .correct }
}

// MARK: - Distractors

/// Picks wrong answers that real learners actually confuse:
/// 16 vs 60, 17 vs 71, 77 vs 97, 77 vs 67.
enum Distractors {
    static func pick<G: RandomNumberGenerator>(for n: Int, count: Int = 3, using rng: inout G) -> [Int] {
        func valid(_ x: Int) -> Bool { FrenchNumber.range.contains(x) && x != n }

        var strong: [Int] = []
        if n >= 10 && n < 100 {
            let swapped = (n % 10) * 10 + n / 10          // 17 <-> 71, 16 <-> 61
            strong.append(swapped)
        }
        if (13...16).contains(n) { strong.append((n - 10) * 10) }          // treize / trente
        if [30, 40, 50, 60].contains(n) { strong.append(n / 10 + 10) }     // trente / treize
        strong.append(contentsOf: [n + 10, n - 10])
        if n >= 40 { strong.append(contentsOf: [n + 20, n - 20]) }          // 77 vs 97

        let medium = [n + 1, n - 1]
        let weak = [n + 2, n - 2, n + 3, n - 3, n + 5, n - 5]

        var picked: [Int] = []
        func take(from list: [Int], max limit: Int) {
            var added = 0
            for x in list.shuffled(using: &rng) where valid(x) && !picked.contains(x) {
                if picked.count >= count || added >= limit { return }
                picked.append(x)
                added += 1
            }
        }
        take(from: strong, max: 2)
        take(from: medium, max: 2)
        take(from: weak, max: count)

        var guardCount = 0
        while picked.count < count && guardCount < 500 {
            guardCount += 1
            let x = Int.random(in: 0...100, using: &rng)
            if valid(x) && !picked.contains(x) { picked.append(x) }
        }
        return picked
    }
}

// MARK: - Factory

enum ExerciseFactory {
    static func make<G: RandomNumberGenerator>(number: Int, kind: ExerciseKind, using rng: inout G) -> Exercise {
        var exercise = Exercise(number: number, kind: kind)

        switch kind {
        case .intro, .spelling, .dictation, .write, .transcribe:
            break

        case .read, .listen, .decode:
            let numbers = ([number] + Distractors.pick(for: number, using: &rng)).shuffled(using: &rng)
            exercise.choices = numbers.map { n in
                Choice(number: n, label: kind == .read ? FrenchNumber.words(for: n) : String(n))
            }

        case .build:
            let answer = FrenchNumber.tokens(for: number)
            let answerSet = Set(answer)
            var pool: [String] = []
            for other in Distractors.pick(for: number, count: 4, using: &rng) {
                for token in FrenchNumber.tokens(for: other) where !answerSet.contains(token) && !pool.contains(token) {
                    pool.append(token)
                }
            }
            if !answerSet.contains("et") && number >= 21 && !pool.contains("et") && Bool.random(using: &rng) {
                pool.insert("et", at: 0)
            }
            for filler in ["deux", "cinq", "huit", "dix", "vingt"] where pool.count < 3 {
                if !answerSet.contains(filler) && !pool.contains(filler) { pool.append(filler) }
            }
            let extras = Array(pool.shuffled(using: &rng).prefix(3))
            exercise.bank = (answer + extras).shuffled(using: &rng)
        }
        return exercise
    }
}

// MARK: - Session builder

/// Builds one "page": new numbers get a teaching card first, then everything
/// is tested, with weak and overdue numbers coming back before fresh ones.
enum SessionBuilder {
    static let pageSize = 10
    static let maxNew = 4
    static let maxReview = 5
    /// Typed-in-words exercises per page. Typing on a phone is slow, so keep it to a couple.
    static let maxWritten = 2
    /// Correct answers needed (out of 10) to test out of a chapter.
    static let testPassMark = 8

    /// How many tries a question gets.
    /// - Typed or built answers always get two: a second attempt is a real second attempt.
    /// - Multiple choice gets two while a number is new or shaky, but only one once it is solid,
    ///   because a second pick among three remaining options is mostly a guess.
    static func tries(for kind: ExerciseKind, box: Int) -> Int {
        switch kind {
        case .intro, .spelling: return 0
        case .build, .dictation, .write, .transcribe: return 2
        case .read, .decode, .listen: return box >= 3 ? 1 : 2
        }
    }

    static func build<G: RandomNumberGenerator>(
        pool: [Int],
        records: [MasteryRecord],
        today: String,
        forced: [Int] = [],
        audioAvailable: Bool,
        needsSpellingCard: Bool = false,
        using rng: inout G
    ) -> [Exercise] {
        guard !pool.isEmpty else { return [] }

        var tested: [Int] = []
        func add(_ n: Int, to list: inout [Int]) {
            if list.count < pageSize && !list.contains(n) { list.append(n) }
        }

        // 1. Numbers the learner just failed come first.
        for n in forced { add(n, to: &tested) }

        // 2. Weak or overdue numbers, weakest first.
        let due = pool
            .filter { records[$0].isDue(today: today) }
            .sorted {
                let a = records[$0], b = records[$1]
                if a.box != b.box { return a.box < b.box }
                return (a.due ?? "") < (b.due ?? "")
            }
        var reviewCount = 0
        for n in due where reviewCount < maxReview && tested.count < pageSize {
            if !tested.contains(n) { tested.append(n); reviewCount += 1 }
        }

        // 3. New numbers, in curriculum order.
        let fresh = pool.filter { records[$0].seen == 0 && !tested.contains($0) }
        var introduced = Array(fresh.prefix(maxNew))
        for n in introduced { add(n, to: &tested) }

        // 4. Fill with the weakest remaining numbers the learner has already met.
        let known = pool
            .filter { records[$0].seen > 0 && !tested.contains($0) }
            .map { (n: $0, box: records[$0].box, roll: Int.random(in: 0..<1000, using: &rng)) }
            .sorted { ($0.box, $0.roll) < ($1.box, $1.roll) }
        for item in known { add(item.n, to: &tested) }

        // 5. A brand-new learner has little to review, so bring in up to two more
        //    new numbers, then repeat numbers in a different format to fill the page.
        if tested.count < pageSize {
            let extra = pool.filter { records[$0].seen == 0 && !tested.contains($0) }.prefix(2)
            for n in extra {
                introduced.append(n)
                add(n, to: &tested)
            }
        }
        let base = tested
        var spins = 0
        while tested.count < pageSize && !base.isEmpty && spins < 50 {
            tested.append(base[spins % base.count])
            spins += 1
        }

        // Order: forced numbers first, the rest shuffled.
        let lead = tested.filter { forced.contains($0) }
        let rest = tested.filter { !forced.contains($0) }.shuffled(using: &rng)
        let order = lead + rest

        // Assign an exercise type to each slot.
        var kinds: [ExerciseKind] = []
        var seenOnce = Set<Int>()
        var writtenCount = 0
        for n in order {
            let record = records[n]
            let isNew = record.seen == 0 && introduced.contains(n) && !seenOnce.contains(n)
            let repeatVisit = seenOnce.contains(n)
            seenOnce.insert(n)
            // Only numbers the learner has already answered correctly get typed in words.
            let allowWritten = writtenCount < maxWritten && record.seen > 0 && record.box >= 1 && !isNew
            let kind = pickKind(number: n, box: record.box, isNew: isNew, repeatVisit: repeatVisit,
                                audio: audioAvailable, allowWritten: allowWritten,
                                previous: kinds.suffix(2), using: &rng)
            if kind.typesWords { writtenCount += 1 }
            kinds.append(kind)
        }

        var tests: [Exercise] = []
        for (n, kind) in zip(order, kinds) {
            var exercise = ExerciseFactory.make(number: n, kind: kind, using: &rng)
            exercise.tries = tries(for: kind, box: records[n].box)
            tests.append(exercise)
        }

        // The spelling rules appear once, right before the first typed-in-words exercise.
        if needsSpellingCard, let first = tests.firstIndex(where: { $0.kind.typesWords }) {
            tests.insert(ExerciseFactory.make(number: 0, kind: .spelling, using: &rng), at: first)
        }

        // Teaching cards for new numbers go first.
        var exercises: [Exercise] = []
        for n in introduced where tested.contains(n) {
            exercises.append(ExerciseFactory.make(number: n, kind: .intro, using: &rng))
        }
        return exercises + tests
    }

    /// A chapter test-out: ten questions on one chapter's numbers, one try each, no hints.
    static func buildTest<G: RandomNumberGenerator>(
        pool: [Int],
        audioAvailable: Bool,
        using rng: inout G
    ) -> [Exercise] {
        var numbers = Array(pool.shuffled(using: &rng).prefix(pageSize))
        // A chapter with fewer than ten numbers (the teens have nine) repeats one in another format,
        // so every test has ten questions and the pass mark means the same thing everywhere.
        var spins = 0
        while numbers.count < pageSize && !pool.isEmpty && spins < 20 {
            numbers.append(pool[Int.random(in: 0..<pool.count, using: &rng)])
            spins += 1
        }
        numbers.shuffle(using: &rng)
        let table: [(ExerciseKind, Int)] = [
            (.decode, 20), (.listen, 25), (.build, 25), (.dictation, 25),
            (.write, 20), (.transcribe, 15), (.read, 10)
        ]
        var kinds: [ExerciseKind] = []
        var writtenCount = 0
        for n in numbers {
            let kind = choose(from: table, number: n, audio: audioAvailable,
                              allowWritten: writtenCount < 3, previous: kinds.suffix(2), using: &rng)
            if kind.typesWords { writtenCount += 1 }
            kinds.append(kind)
        }
        var exercises: [Exercise] = []
        for (n, kind) in zip(numbers, kinds) {
            exercises.append(ExerciseFactory.make(number: n, kind: kind, using: &rng))
        }
        return exercises
    }

    private static func pickKind<G: RandomNumberGenerator>(
        number: Int, box: Int, isNew: Bool, repeatVisit: Bool, audio: Bool, allowWritten: Bool,
        previous: ArraySlice<ExerciseKind>, using rng: inout G
    ) -> ExerciseKind {
        let table: [(ExerciseKind, Int)]
        if isNew || (box == 0 && !repeatVisit) {
            table = [(.read, 35), (.decode, 25), (.listen, 40)]
        } else if repeatVisit {
            table = [(.listen, 30), (.decode, 20), (.build, 25), (.dictation, 25), (.read, 15)]
        } else if box <= 2 {
            table = [(.read, 20), (.decode, 15), (.listen, 25), (.build, 20), (.dictation, 20),
                     (.write, 15), (.transcribe, 10)]
        } else {
            table = [(.build, 30), (.dictation, 30), (.listen, 15), (.decode, 15), (.read, 10),
                     (.write, 20), (.transcribe, 15)]
        }
        return choose(from: table, number: number, audio: audio, allowWritten: allowWritten,
                      previous: previous, using: &rng)
    }

    private static func choose<G: RandomNumberGenerator>(
        from input: [(ExerciseKind, Int)], number: Int, audio: Bool, allowWritten: Bool,
        previous: ArraySlice<ExerciseKind>, using rng: inout G
    ) -> ExerciseKind {
        var table = input.filter { entry in
            if !audio && entry.0.usesAudio { return false }
            if entry.0 == .build && FrenchNumber.tokens(for: number).count < 2 { return false }
            if entry.0.typesWords && !allowWritten { return false }
            return true
        }
        if table.isEmpty { table = [(.read, 1)] }

        // Never three of the same kind in a row.
        if previous.count == 2, let a = previous.first, let b = previous.last, a == b {
            let varied = table.filter { $0.0 != a }
            if !varied.isEmpty { table = varied }
        }

        let total = table.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 0..<total, using: &rng)
        for (kind, weight) in table {
            if roll < weight { return kind }
            roll -= weight
        }
        return table[0].0
    }
}
