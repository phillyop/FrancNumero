import Foundation

// MARK: - Mastery

enum Outcome: String, Codable {
    case first    // right on the first try
    case second   // right after a hint
    case failed   // wrong on the last try
}

enum MasteryLevel: Int {
    case unseen, shaky, learning, solid, mastered
}

/// What the app remembers about one number.
struct MasteryRecord: Codable, Equatable {
    var seen = 0
    var correct = 0
    var misses = 0
    /// Leitner box. 0 = needs work, 5 = mastered.
    var box = 0
    var due: String?
    var lastSeen: String?

    var level: MasteryLevel {
        if seen == 0 { return .unseen }
        switch box {
        case 0: return .shaky
        case 1, 2: return .learning
        case 3, 4: return .solid
        default: return .mastered
        }
    }

    /// Days until the number should come back, by box.
    static let intervals = [0, 1, 2, 4, 8, 16]

    mutating func apply(_ outcome: Outcome, today: String) {
        seen += 1
        lastSeen = today
        switch outcome {
        case .first:
            correct += 1
            box = min(5, box + 1)
            due = DayKey.adding(Self.intervals[box], to: today)
        case .second:
            correct += 1
            box = max(1, box)
            due = DayKey.adding(1, to: today)
        case .failed:
            misses += 1
            box = 0
            due = today
        }
    }

    func isDue(today: String) -> Bool {
        guard seen > 0 else { return false }
        return box == 0 || (due ?? today) <= today
    }
}

// MARK: - Chapters

struct Chapter: Identifiable, Hashable {
    let id: Int
    let range: ClosedRange<Int>
    let title: String
    let nickname: String
    let rule: String
    let writing: String

    var numbers: [Int] { Array(range) }
    var rangeLabel: String { "\(range.lowerBound) to \(range.upperBound)" }
    /// A few numbers that show the pattern off.
    var examples: [Int] {
        let all = numbers
        if all.count <= 4 { return all }
        return [all[0], all[1], all[all.count / 2], all[all.count - 1]]
    }
}

struct StartOption: Identifiable {
    let id: Int
    let title: String
    let detail: String
    /// How many chapters start unlocked.
    let unlockedCount: Int
}

enum Curriculum {
    static let chapters: [Chapter] = [
        Chapter(
            id: 0, range: 0...10,
            title: "First steps", nickname: "The foundation",
            rule: "Zéro to dix are the bricks everything else is built from. Learn them by heart and by ear.",
            writing: "Zéro has an accent. The rest are short and plain: un, deux, trois, quatre, cinq, six, sept, huit, neuf, dix."
        ),
        Chapter(
            id: 1, range: 11...19,
            title: "The teens", nickname: "Odd ones out",
            rule: "Onze, douze, treize, quatorze, quinze and seize are one-off words. From 17 on, French simply says ten-seven, ten-eight, ten-nine.",
            writing: "Watch quatorze, quinze and seize. From 17, hyphens join the words: dix-sept, dix-huit, dix-neuf."
        ),
        Chapter(
            id: 2, range: 20...39,
            title: "Vingt and trente", nickname: "Tens and units",
            rule: "Say the tens, then the unit: vingt-deux, trente-cinq. When the unit is 1, add “et”: vingt et un, trente et un.",
            writing: "Hyphens join tens and units: vingt-deux, trente-cinq. The one exception is “et”, written alone: vingt et un, trente et un."
        ),
        Chapter(
            id: 3, range: 40...69,
            title: "Quarante to soixante", nickname: "Same pattern",
            rule: "Quarante, cinquante and soixante work like vingt and trente, including “et un” for 41, 51 and 61.",
            writing: "Same hyphens, same “et”: quarante-deux, cinquante et un, soixante-neuf. Quarante and cinquante are the ones to watch."
        ),
        Chapter(
            id: 4, range: 70...79,
            title: "Seventies", nickname: "Sixty-ten",
            rule: "France has no word for 70. It counts on from 60: soixante-dix (60 + 10), soixante et onze (60 + 11), soixante-douze… Belgium and Switzerland say septante.",
            writing: "Hyphens all the way: soixante-dix-sept. Only 71 takes “et”: soixante et onze."
        ),
        Chapter(
            id: 5, range: 80...89,
            title: "Eighties", nickname: "Four twenties",
            rule: "80 is quatre-vingts: four twenties. Add the unit after it: quatre-vingt-un, quatre-vingt-deux. The s on vingts drops once a number follows, and 81 takes no “et”.",
            writing: "Quatre-vingts has an s only on its own. After it, hyphens and no s: quatre-vingt-trois. And 81 takes no “et”: quatre-vingt-un."
        ),
        Chapter(
            id: 6, range: 90...100,
            title: "Nineties and cent", nickname: "Four twenties and ten",
            rule: "Keep counting from 80: quatre-vingt-dix (80 + 10), quatre-vingt-onze (80 + 11)… up to quatre-vingt-dix-neuf. Then cent. Belgium and Switzerland say nonante.",
            writing: "Quatre-vingt-dix-neuf is four words joined by hyphens, with no s on vingt. And 100 is just cent."
        )
    ]

    static let startOptions = [
        StartOption(id: 0, title: "Brand new", detail: "Start from zéro", unlockedCount: 1),
        StartOption(id: 1, title: "I can count to 19", detail: "Start at vingt", unlockedCount: 3),
        StartOption(id: 2, title: "I can count to 69", detail: "Start with the tricky ones, 70 and up", unlockedCount: 5)
    ]

    /// All numbers in the first `unlockedCount` chapters.
    static func numbers(unlockedCount: Int) -> [Int] {
        chapters.prefix(max(1, unlockedCount)).flatMap { $0.numbers }
    }

    static func chapter(containing n: Int) -> Chapter? {
        chapters.first { $0.range.contains(n) }
    }

    /// Share of the chapter answered correctly since its last miss.
    static func progress(of chapter: Chapter, records: [MasteryRecord]) -> Double {
        let numbers = chapter.numbers
        guard !numbers.isEmpty else { return 0 }
        let known = numbers.filter { records[$0].seen > 0 && records[$0].box >= 1 }.count
        return Double(known) / Double(numbers.count)
    }

    static let clearThreshold = 0.75

    static func isCleared(_ chapter: Chapter, records: [MasteryRecord]) -> Bool {
        progress(of: chapter, records: records) >= clearThreshold
    }
}
