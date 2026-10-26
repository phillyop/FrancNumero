import SwiftUI

/// Seyès paper: fine horizontal rules, bolder squares every fourth line,
/// and the red margin French exercise books have down the left edge.
struct PaperBackground: View {
    var showsMargin = true

    var body: some View {
        let paper = Palette.paper
        let grid = Palette.grid
        let margin = Palette.pen
        let drawMargin = showsMargin

        ZStack {
            paper
            Canvas { context, size in
                let unit: CGFloat = 8
                var minor = Path()
                var major = Path()

                var y: CGFloat = 0
                var row = 0
                while y <= size.height {
                    if row % 4 == 0 {
                        major.move(to: CGPoint(x: 0, y: y))
                        major.addLine(to: CGPoint(x: size.width, y: y))
                    } else {
                        minor.move(to: CGPoint(x: 0, y: y))
                        minor.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    y += unit
                    row += 1
                }

                var x: CGFloat = 0
                while x <= size.width {
                    major.move(to: CGPoint(x: x, y: 0))
                    major.addLine(to: CGPoint(x: x, y: size.height))
                    x += unit * 4
                }

                context.stroke(minor, with: .color(grid.opacity(0.22)), lineWidth: 0.5)
                context.stroke(major, with: .color(grid.opacity(0.5)), lineWidth: 0.6)

                if drawMargin {
                    var line = Path()
                    line.move(to: CGPoint(x: 16, y: 0))
                    line.addLine(to: CGPoint(x: 16, y: size.height))
                    context.stroke(line, with: .color(margin.opacity(0.55)), lineWidth: 1.2)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
