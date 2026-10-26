import Foundation

/// One piece of a French number, e.g. "soixante" (60) in soixante-dix-sept.
struct NumberPart: Hashable {
    enum Role { case base, remainder, connector }
    let text: String
    let value: Int?
    let role: Role
}

/// How a number is built: the pieces and the sum behind them.
struct NumberAnatomy {
    let parts: [NumberPart]
    /// e.g. "60 + 17 = 77". Nil for numbers that are a single word.
    let equation: String?
    var isComposite: Bool { equation != nil }
    /// The equation without its result, e.g. "60 + 17".
    var recipe: String? { equation?.components(separatedBy: " = ").first }
}

/// Everything the app knows about how French spells the numbers 0–100.
enum FrenchNumber {
    static let range = 0...100

    private static let units = [
        "zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf",
        "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize"
    ]
    private static let tensWords = ["", "", "vingt", "trente", "quarante", "cinquante", "soixante"]

    // MARK: Spelling

    static func words(for n: Int) -> String {
        guard range.contains(n) else { return "" }
        if n <= 16 { return units[n] }
        if n <= 19 { return "dix-" + units[n - 10] }
        if n == 100 { return "cent" }
        if n == 80 { return "quatre-vingts" }
        if n > 80 { return "quatre-vingt-" + words(for: n - 80) }
        if n >= 70 {
            let rest = n - 60
            return rest == 11 ? "soixante et onze" : "soixante-" + words(for: rest)
        }
        let tens = tensWords[n / 10]
        switch n % 10 {
        case 0: return tens
        case 1: return tens + " et un"
        default: return tens + "-" + units[n % 10]
        }
    }

    /// The words of a number as separate tiles: "quatre", "vingt", "dix", "sept".
    static func tokens(for n: Int) -> [String] {
        words(for: n)
            .split(whereSeparator: { $0 == "-" || $0 == " " })
            .map { String($0) }
    }

    /// Joins tiles the way French writes them: hyphens everywhere, spaces around "et".
    static func join(_ tokens: [String]) -> String {
        var out = ""
        for (i, token) in tokens.enumerated() {
            if i > 0 {
                out += (token == "et" || tokens[i - 1] == "et") ? " " : "-"
            }
            out += token
        }
        return out
    }

    // MARK: Anatomy

    static func anatomy(for n: Int) -> NumberAnatomy {
        guard range.contains(n) else { return NumberAnatomy(parts: [], equation: nil) }

        let single = NumberAnatomy(
            parts: [NumberPart(text: words(for: n), value: n, role: .base)],
            equation: nil
        )
        if n <= 16 || n == 100 { return single }

        if n <= 19 {
            return NumberAnatomy(
                parts: [
                    NumberPart(text: "dix", value: 10, role: .base),
                    NumberPart(text: units[n - 10], value: n - 10, role: .remainder)
                ],
                equation: "10 + \(n - 10) = \(n)"
            )
        }
        if n == 80 {
            return NumberAnatomy(
                parts: [
                    NumberPart(text: "quatre", value: 4, role: .base),
                    NumberPart(text: "vingts", value: 20, role: .remainder)
                ],
                equation: "4 × 20 = 80"
            )
        }
        if n > 80 { return composite(base: "quatre-vingt", baseValue: 80, rest: n - 80, total: n) }
        if n >= 70 { return composite(base: "soixante", baseValue: 60, rest: n - 60, total: n) }
        if n % 10 == 0 { return single }
        return composite(base: tensWords[n / 10], baseValue: (n / 10) * 10, rest: n % 10, total: n)
    }

    private static func composite(base: String, baseValue: Int, rest: Int, total: Int) -> NumberAnatomy {
        var parts = [NumberPart(text: base, value: baseValue, role: .base)]
        if words(for: total).contains(" et ") {
            parts.append(NumberPart(text: "et", value: nil, role: .connector))
        }
        parts.append(NumberPart(text: words(for: rest), value: rest, role: .remainder))
        return NumberAnatomy(parts: parts, equation: "\(baseValue) + \(rest) = \(total)")
    }

    // MARK: Teaching copy

    /// A nudge shown after a first wrong answer.
    static func hint(for n: Int) -> String {
        if let recipe = anatomy(for: n).recipe {
            return "Break it down: \(recipe)"
        }
        let first = words(for: n).prefix(1)
        return "It starts with “\(first)”."
    }

    /// A one-line explanation of what is special about this number, if anything.
    static func tip(for n: Int) -> String? {
        switch n {
        case 11...16: return "Eleven to sixteen are one-off words. Learn them by heart."
        case 17...19: return "From 17, French says ten-seven, ten-eight, ten-nine."
        case 21, 31, 41, 51, 61: return "Numbers ending in 1 take “et”: \(words(for: n))."
        case 70: return "France has no word for 70. It says sixty-ten."
        case 71: return "71 is sixty and eleven. “et” shows up here, but not in 72 to 79."
        case 72...79: return "Count on from 60: soixante + \(n - 60)."
        case 80: return "Four twenties. The s on vingts drops when another number follows."
        case 81: return "81 has no “et”, unlike 21, 31, 41, 51, 61 and 71."
        case 82...89: return "Count on from 80: quatre-vingt + \(n - 80). No s on vingt."
        case 90: return "Four twenties and ten."
        case 91: return "91 has no “et”: quatre-vingt-onze."
        case 92...99: return "Count on from 80: quatre-vingt + \(n - 80)."
        case 100: return "Just cent. Never “un cent”."
        default: return nil
        }
    }

    // MARK: Slow speech

    /// Where to pause when speaking a number slowly, at the joints French itself has.
    ///
    /// Numbers up to 29 (and 100) stay whole on purpose: splitting dix-huit or vingt-deux would
    /// drop the liaison, and the voice would pronounce "dix" and "vingt" the wrong way.
    static func speechSegments(for n: Int) -> [String] {
        guard range.contains(n) else { return [] }
        let whole = [words(for: n)]
        if n <= 29 || n == 100 { return whole }
        if n == 80 { return ["quatre", "vingts"] }
        if n > 80 { return ["quatre-vingt", words(for: n - 80)] }
        if n >= 70 { return ["soixante", n == 71 ? "et onze" : words(for: n - 60)] }
        let tens = tensWords[n / 10]
        switch n % 10 {
        case 0: return whole
        case 1: return [tens, "et un"]
        default: return [tens, units[n % 10]]
        }
    }

    // MARK: Typed answers

    /// Splits what the learner typed into lowercase words. Hyphens, dashes and spaces all separate words,
    /// so "vingt et un" and "vingt-et-un" (allowed since the 1990 reform) are both fine.
    static func normalizedTokens(_ raw: String) -> [String] {
        raw.lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == "–" || $0 == "—" || $0 == " " || $0 == "\n" || $0 == "\t" })
            .map { String($0) }
    }

    /// Every valid spelling, so a different real number is never mistaken for a typo.
    private static let spellingIndex: [String: Int] = {
        var index: [String: Int] = [:]
        for n in FrenchNumber.range {
            index[FrenchNumber.tokens(for: n).joined(separator: " ")] = n
        }
        return index
    }()

    /// Judges a typed answer. Accent slips and one-letter typos are "near misses": they cost nothing.
    static func judge(typed raw: String, for n: Int) -> Verdict {
        let typed = normalizedTokens(raw)
        guard !typed.isEmpty else { return .wrong }
        let target = tokens(for: n)
        if typed == target { return .correct }

        // A real spelling of a different number is simply wrong (six vs dix is not a typo).
        if let other = spellingIndex[typed.joined(separator: " ")], other != n { return .wrong }

        if typed.map(fold) == target.map(fold) {
            return .nearMiss("Check the accents. Hold a letter on the keyboard to see them.")
        }
        let typedJoined = typed.joined()
        let targetJoined = target.joined()
        if n == 80 && typedJoined == "quatrevingt" {
            return .nearMiss("Quatre-vingts takes an s when nothing follows it.")
        }
        if editDistance(typedJoined, targetJoined) <= 1 {
            return .nearMiss("So close. Check the spelling.")
        }
        return .wrong
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
    }

    private static func editDistance(_ first: String, _ second: String) -> Int {
        let a = Array(first)
        let b = Array(second)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }

    /// The rules shown on the one-time "Writing numbers" card.
    static let spellingRules: [(title: String, detail: String)] = [
        ("Hyphens join the words", "vingt-deux, soixante-dix-sept, quatre-vingt-dix-neuf. In this app spaces work too, and so does vingt-et-un."),
        ("“et” stands alone", "Only 21, 31, 41, 51, 61 and 71 take it: vingt et un, soixante et onze."),
        ("The s on quatre-vingts", "It appears only when nothing follows: quatre-vingts, but quatre-vingt-trois."),
        ("Zéro has an accent", "On the first e. Hold the e on your keyboard to find é."),
        ("Cent", "100 is just cent. No “un” in front, no s.")
    ]

    /// Short facts for the home screen. Picked by day so they rotate.
    static let facts = [
        "France says soixante-dix (sixty-ten) for 70. Belgium and Switzerland say septante.",
        "Quatre-vingts (80) literally means four twenties, a leftover from an old base-20 counting system.",
        "In some Swiss cantons, 80 is huitante and 90 is nonante.",
        "Only 21, 31, 41, 51, 61 and 71 take “et”. 81 and 91 do not.",
        "Cent (100) never takes “un” in front of it.",
        "The s on quatre-vingts vanishes as soon as another number follows: quatre-vingt-trois.",
        "Treize, quatorze, quinze and seize sound a lot like trente, quarante, cinquante and soixante. Listen to the endings."
    ]
}
