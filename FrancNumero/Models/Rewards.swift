import Foundation

// MARK: - School levels

/// Lifetime "bons points" move the learner up through the French school system.
struct SchoolLevel: Equatable {
    let code: String
    let name: String
    let threshold: Int
}

enum Levels {
    static let all = [
        SchoolLevel(code: "CP", name: "Cours préparatoire", threshold: 0),
        SchoolLevel(code: "CE1", name: "Cours élémentaire 1", threshold: 200),
        SchoolLevel(code: "CE2", name: "Cours élémentaire 2", threshold: 500),
        SchoolLevel(code: "CM1", name: "Cours moyen 1", threshold: 900),
        SchoolLevel(code: "CM2", name: "Cours moyen 2", threshold: 1400),
        SchoolLevel(code: "6e", name: "Sixième", threshold: 2000),
        SchoolLevel(code: "5e", name: "Cinquième", threshold: 2800),
        SchoolLevel(code: "4e", name: "Quatrième", threshold: 3800),
        SchoolLevel(code: "3e", name: "Troisième", threshold: 5000),
        SchoolLevel(code: "Tle", name: "Terminale", threshold: 7000)
    ]

    /// "Unlock all chapters" stays hidden until the learner reaches this level.
    static let unlockAllLevel = all[4]   // CM2

    static func level(for points: Int) -> SchoolLevel {
        all.last { points >= $0.threshold } ?? all[0]
    }

    static func next(after level: SchoolLevel) -> SchoolLevel? {
        guard let i = all.firstIndex(of: level), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    /// 0...1 progress from this level toward the next. 1 at the top.
    static func progress(for points: Int) -> Double {
        let current = level(for: points)
        guard let upcoming = Levels.next(after: current) else { return 1 }
        let span = Double(upcoming.threshold - current.threshold)
        return min(1, max(0, Double(points - current.threshold) / span))
    }
}

// MARK: - Gommettes

enum GommetteTint {
    case red, yellow, blue, green, violet, orange
}

/// Gommettes are the round reward stickers French teachers hand out.
struct GommetteDef: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: GommetteTint
}

enum Gommettes {
    static let all: [GommetteDef] = {
        var list = [
            GommetteDef(id: "first", title: "First page", detail: "Finish your first page.", symbol: "pencil", tint: .blue),
            GommetteDef(id: "run3", title: "Three in a row", detail: "Write a page 3 days running.", symbol: "3.circle.fill", tint: .orange),
            GommetteDef(id: "run7", title: "A full week", detail: "7 days in a row.", symbol: "calendar", tint: .green),
            GommetteDef(id: "run14", title: "Fortnight", detail: "14 days in a row.", symbol: "star.fill", tint: .violet),
            GommetteDef(id: "run30", title: "Un mois", detail: "30 days in a row.", symbol: "crown.fill", tint: .yellow),
            GommetteDef(id: "perfect", title: "Vingt sur vingt", detail: "Score 20 out of 20.", symbol: "checkmark.seal.fill", tint: .red),
            GommetteDef(id: "rebond", title: "Rebond", detail: "Finish a page after tearing one.", symbol: "arrow.uturn.up", tint: .orange),
            GommetteDef(id: "cent", title: "Cent pour cent", detail: "Get every number to solid or better.", symbol: "percent", tint: .violet)
        ]
        let tints: [GommetteTint] = [.blue, .green, .yellow, .orange, .red, .violet, .blue]
        for chapter in Curriculum.chapters {
            list.append(GommetteDef(
                id: "chapter\(chapter.id)",
                title: chapter.nickname,
                detail: "Clear \(chapter.rangeLabel).",
                symbol: "flag.fill",
                tint: tints[chapter.id % tints.count]
            ))
        }
        return list
    }()

    static func def(for id: String) -> GommetteDef? {
        all.first { $0.id == id }
    }
}
