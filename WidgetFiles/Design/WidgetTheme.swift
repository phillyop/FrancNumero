import SwiftUI
import WidgetKit

/// The same notebook look as the app: Seyès paper, blue ink, a red pen.
/// The colours live in this target's Assets.xcassets (a copy of the app's), so each has a dark value too.
enum WPalette {
    static let paper = Color("Paper")
    static let surface = Color("Surface")
    static let grid = Color("Grid")
    static let ink = Color("Ink")
    static let inkMuted = Color("InkMuted")
    static let onInk = Color("OnInk")
    static let pen = Color("Pen")
    static let marker = Color("Marker")
    static let sky = Color("Sky")
    static let leaf = Color("Leaf")
}

enum WFont {
    /// Didot, the French typeface, for numerals.
    static func numeral(_ size: CGFloat) -> Font {
        .custom("Didot-Bold", size: size)
    }

    /// Snell Roundhand, the teacher's cursive.
    static func hand(_ size: CGFloat) -> Font {
        .custom("SnellRoundhand-Bold", size: size)
    }

    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

/// Fine horizontal rules with a bolder vertical every fourth step, like Seyès paper.
struct GridLines: Shape {
    var spacing: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing * 4
        }
        return path
    }
}

/// The widget's page. On a tinted or clear Home Screen (iOS 18 and later) the system takes over the
/// background, so this draws nothing there and the content does the talking.
struct PaperBackdrop: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .fullColor {
            ZStack(alignment: .leading) {
                WPalette.paper
                GridLines()
                    .stroke(WPalette.grid.opacity(0.28), lineWidth: 0.5)
                Rectangle()
                    .fill(WPalette.pen.opacity(0.45))
                    .frame(width: 1)
                    .padding(.leading, 9)
            }
        } else {
            Color.clear
        }
    }
}

extension View {
    /// Home Screen widgets: the notebook page.
    func paperWidgetBackground() -> some View {
        containerBackground(for: .widget) { PaperBackdrop() }
    }

    /// Lock Screen widgets: the system draws its own backing.
    func clearWidgetBackground() -> some View {
        containerBackground(for: .widget) { Color.clear }
    }
}

/// How well a number is known, as a colour. Same ramp as the app's Tableau.
enum WMastery {
    static func fill(_ level: Int) -> Color {
        switch level {
        case 1: return WPalette.pen.opacity(0.22)
        case 2: return WPalette.marker.opacity(0.55)
        case 3: return WPalette.sky.opacity(0.65)
        case 4: return WPalette.ink
        default: return WPalette.surface
        }
    }

    static func text(_ level: Int) -> Color {
        level == 4 ? WPalette.onInk : WPalette.ink
    }
}
