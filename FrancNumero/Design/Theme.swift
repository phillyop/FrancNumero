import SwiftUI

/// FrancNumero looks like a French school exercise book (un cahier).
/// Light mode is Seyès grid paper and blue ink. Dark mode is a chalkboard (un tableau noir).
/// All colours live in Assets.xcassets so each has a light and a dark value.
enum Palette {
    static let paper = Color("Paper")        // page
    static let surface = Color("Surface")    // raised paper: keys, tiles
    static let grid = Color("Grid")          // Seyès rules
    static let ink = Color("Ink")            // primary text, blue ink / chalk
    static let inkMuted = Color("InkMuted")  // secondary text
    static let onInk = Color("OnInk")        // text on ink-filled buttons
    static let pen = Color("Pen")            // the teacher's red pen
    static let marker = Color("Marker")      // highlighter yellow
    static let sky = Color("Sky")            // pale blue
    static let leaf = Color("Leaf")          // tick green
}

enum Typeface {
    /// Didot: the French typeface. Used big, for numerals and headlines.
    static func numeral(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("Didot-Bold", size: size, relativeTo: style)
    }

    /// Snell Roundhand: the teacher's cursive, for remarks and corrections.
    static func hand(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("SnellRoundhand-Bold", size: size, relativeTo: style)
    }

    /// New York serif, for French words in answers.
    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// SF Pro, for interface text.
    static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }
}

enum Metrics {
    static let pagePadding: CGFloat = 28
    static let radius: CGFloat = 8
    static let tapHeight: CGFloat = 52
}

extension GommetteTint {
    var color: Color {
        switch self {
        case .red: return Color(red: 0.90, green: 0.28, blue: 0.30)
        case .yellow: return Color(red: 0.96, green: 0.77, blue: 0.09)
        case .blue: return Color(red: 0.24, green: 0.39, blue: 0.87)
        case .green: return Color(red: 0.19, green: 0.64, blue: 0.42)
        case .violet: return Color(red: 0.56, green: 0.31, blue: 0.78)
        case .orange: return Color(red: 0.97, green: 0.42, blue: 0.08)
        }
    }
}

extension MasteryLevel {
    var label: String {
        switch self {
        case .unseen: return "Not met yet"
        case .shaky: return "Needs work"
        case .learning: return "Learning"
        case .solid: return "Solid"
        case .mastered: return "Mastered"
        }
    }

    var fill: Color {
        switch self {
        case .unseen: return Palette.surface
        case .shaky: return Palette.pen.opacity(0.22)
        case .learning: return Palette.marker.opacity(0.55)
        case .solid: return Palette.sky.opacity(0.65)
        case .mastered: return Palette.ink
        }
    }

    var textColor: Color {
        self == .mastered ? Palette.onInk : Palette.ink
    }
}
