import SwiftUI

// MARK: - Buttons

struct InkButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, pen }
    var kind: Kind = .primary

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
        return configuration.label
            .font(Typeface.ui(.headline, weight: .semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: Metrics.tapHeight)
            .background(fillColor, in: shape)
            .overlay(shape.strokeBorder(strokeColor, lineWidth: 1.5))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return Palette.onInk
        case .secondary: return Palette.ink
        case .pen: return Color.white
        }
    }

    private var fillColor: Color {
        switch kind {
        case .primary: return Palette.ink
        case .secondary: return Color.clear
        case .pen: return Palette.pen
        }
    }

    private var strokeColor: Color {
        switch kind {
        case .primary: return Palette.ink
        case .secondary: return Palette.ink.opacity(0.4)
        case .pen: return Palette.pen
        }
    }
}

// MARK: - Small pieces

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Palette.ink.opacity(0.14))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct InkProgressBar: View {
    let value: Double
    var tint: Color = Palette.ink

    var body: some View {
        let clamped = min(1, max(0, value))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.ink.opacity(0.12))
                if clamped > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, geo.size.width * CGFloat(clamped)))
                }
            }
            .animation(.easeOut(duration: 0.45), value: clamped)
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text("\(Int(clamped * 100)) percent"))
    }
}

/// The date stamp teachers press on a finished page.
struct DateStamp: View {
    let word: String
    let date: String

    var body: some View {
        VStack(spacing: 2) {
            Text(word)
                .font(Typeface.numeral(28, relativeTo: .title))
            Rectangle()
                .fill(Palette.pen)
                .frame(height: 1.5)
                .padding(.horizontal, 16)
            Text(date)
                .font(Typeface.ui(.caption, weight: .bold))
        }
        .foregroundStyle(Palette.pen)
        .frame(width: 108, height: 108)
        .overlay(Circle().strokeBorder(Palette.pen, lineWidth: 3))
        .overlay(Circle().strokeBorder(Palette.pen.opacity(0.6), lineWidth: 1).padding(7))
        .rotationEffect(.degrees(-10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page stamped \(date)")
    }
}

/// A round reward sticker, like the ones teachers hand out.
struct GommetteBadge: View {
    let def: GommetteDef
    let unlocked: Bool
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(unlocked ? def.tint.color : Palette.ink.opacity(0.08))
            if unlocked {
                Circle().fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            }
            Image(systemName: unlocked ? def.symbol : "lock.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(unlocked ? Color.white : Palette.inkMuted.opacity(0.6))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "\(def.title), earned" : "\(def.title), locked")
    }
}

// MARK: - Anatomy of a number

/// Shows how a French number is built: 77 = soixante (60) + dix-sept (17).
struct AnatomyView: View {
    let number: Int
    var showEquation = true

    var body: some View {
        let anatomy = FrenchNumber.anatomy(for: number)
        let separator = (anatomy.equation ?? "").contains("×") ? "×" : "+"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                ForEach(Array(anatomy.parts.enumerated()), id: \.offset) { index, part in
                    if part.role == .connector {
                        Text(part.text)
                            .font(Typeface.serif(.title3, weight: .regular).italic())
                            .foregroundStyle(Palette.inkMuted)
                    } else {
                        if index > 0 && anatomy.parts[index - 1].role != .connector {
                            Text(separator)
                                .font(Typeface.ui(.title3, weight: .medium))
                                .foregroundStyle(Palette.inkMuted)
                        }
                        chip(part)
                    }
                }
            }
            if showEquation, let equation = anatomy.equation {
                Text(equation)
                    .font(Typeface.numeral(28, relativeTo: .title2))
                    .foregroundStyle(Palette.ink)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(anatomy))
    }

    private func chip(_ part: NumberPart) -> some View {
        VStack(spacing: 2) {
            Text(part.text)
                .font(Typeface.serif(.title3, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let value = part.value {
                Text("\(value)")
                    .font(Typeface.ui(.caption, weight: .medium))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            (part.role == .base ? Palette.marker.opacity(0.55) : Palette.sky.opacity(0.6)),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    private func accessibilityText(_ anatomy: NumberAnatomy) -> String {
        if let equation = anatomy.equation {
            return "\(FrenchNumber.words(for: number)). \(equation)"
        }
        return FrenchNumber.words(for: number)
    }
}

// MARK: - Speaker

struct SpeakerButtons: View {
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            Button {
                SpeechService.shared.speakNumber(number)
            } label: {
                Label("Listen", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .accessibilityHint("Plays the number in French")

            Button {
                SpeechService.shared.speakNumber(number, slow: true)
            } label: {
                Label("Slower", systemImage: "tortoise.fill")
            }
            .buttonStyle(InkButtonStyle(kind: .secondary))
            .accessibilityHint("Plays the number more slowly")
        }
    }
}
