import SwiftUI
import WidgetKit

// MARK: - The run, as a bookmark ribbon

struct RunRibbon: View {
    let count: Int
    let active: Bool
    var height: CGFloat = 54

    var body: some View {
        ZStack(alignment: .top) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: height))
                .foregroundStyle(active ? WPalette.pen : WPalette.ink.opacity(0.16))
                .widgetAccentable(active)
            VStack(spacing: -2) {
                Text("\(count)")
                    .font(WFont.numeral(height * 0.36))
                Text(count == 1 ? "day" : "days")
                    .font(WFont.ui(height * 0.13, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : WPalette.inkMuted)
            .padding(.top, height * 0.12)
        }
        .frame(width: height * 0.78)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) day run")
    }
}

// MARK: - The week, as hand-stamped circles

struct WeekStamps: View {
    let days: [WidgetSnapshot.WeekDay]
    var size: CGFloat = 22
    var showsLetters = true

    var body: some View {
        HStack(spacing: size * 0.28) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                ringColor(day),
                                style: StrokeStyle(
                                    lineWidth: day.done ? 2 : 1.2,
                                    dash: (day.done || day.excused || day.isToday) ? [] : [2.5, 2.5]
                                )
                            )
                        if day.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: size * 0.42, weight: .heavy))
                                .foregroundStyle(WPalette.pen)
                                .widgetAccentable()
                        } else if day.excused {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: size * 0.36))
                                .foregroundStyle(WPalette.inkMuted)
                        }
                    }
                    .frame(width: size, height: size)

                    if showsLetters {
                        Text(day.letter)
                            .font(WFont.ui(size * 0.42, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? WPalette.ink : WPalette.inkMuted)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days.filter { $0.done }.count) of the last 7 days written")
    }

    private func ringColor(_ day: WidgetSnapshot.WeekDay) -> Color {
        if day.done { return WPalette.pen }
        return WPalette.ink.opacity(day.isToday ? 0.7 : 0.28)
    }
}

// MARK: - The "Vu" date stamp

struct StampBadge: View {
    let word: String
    let detail: String
    var size: CGFloat = 70

    var body: some View {
        VStack(spacing: 1) {
            Text(word)
                .font(WFont.numeral(size * 0.28))
            Rectangle()
                .fill(WPalette.pen)
                .frame(height: 1)
                .padding(.horizontal, size * 0.16)
            Text(detail)
                .font(WFont.ui(size * 0.13, weight: .bold))
        }
        .foregroundStyle(WPalette.pen)
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(WPalette.pen, lineWidth: 2.2))
        .overlay(Circle().strokeBorder(WPalette.pen.opacity(0.55), lineWidth: 0.8).padding(size * 0.065))
        .rotationEffect(.degrees(-10))
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page stamped \(detail)")
    }
}

// MARK: - Small progress bar

struct WidgetBar: View {
    let value: Double
    var tint: Color = WPalette.ink
    var height: CGFloat = 5

    var body: some View {
        let clamped = min(1, max(0, value))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(WPalette.ink.opacity(0.12))
                if clamped > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, geo.size.width * CGFloat(clamped)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Lock Screen: week ring and dots

/// Seven arcs around a circle, one per day, ending at the top with today.
/// Lock Screen widgets are drawn in a single tint, so this only uses opacity to tell days apart.
struct WeekRing: View {
    let days: [WidgetSnapshot.WeekDay]
    var lineWidth: CGFloat = 4.5

    var body: some View {
        ZStack {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                Circle()
                    .trim(from: start(index), to: end(index))
                    .stroke(
                        Color.primary,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .opacity(day.done || day.excused ? 1 : 0.25)
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    private func start(_ index: Int) -> CGFloat { CGFloat(index) / 7 + 0.014 }
    private func end(_ index: Int) -> CGFloat { CGFloat(index + 1) / 7 - 0.014 }
}

struct AccessoryDots: View {
    let days: [WidgetSnapshot.WeekDay]
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                if day.done || day.excused {
                    Circle().fill(Color.primary).frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(Color.primary.opacity(day.isToday ? 1 : 0.4), lineWidth: 1.2)
                        .frame(width: size, height: size)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - The hundred chart

/// Every number from 0 to 100, coloured by how well it is known. Locked chapters are dimmed.
struct MasteryGrid: View {
    let snapshot: WidgetSnapshot
    let tile: CGFloat
    let gap: CGFloat
    var showNumbers = false
    var includeCent = false

    var body: some View {
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<10, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<10, id: \.self) { col in
                        cell(row * 10 + col)
                    }
                }
            }
            if includeCent {
                HStack(spacing: gap) {
                    cell(100)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.solidCount) of 101 numbers solid")
    }

    private func cell(_ n: Int) -> some View {
        let level = snapshot.masteryLevel(of: n)
        let shape = RoundedRectangle(cornerRadius: max(2, tile * 0.2), style: .continuous)
        return shape
            .fill(WMastery.fill(level))
            .overlay(shape.strokeBorder(WPalette.ink.opacity(level == 0 ? 0.22 : 0), lineWidth: 0.6))
            .frame(width: tile, height: tile)
            .overlay {
                if showNumbers {
                    Text("\(n)")
                        .font(WFont.numeral(tile * (n == 100 ? 0.34 : 0.44)))
                        .foregroundStyle(WMastery.text(level))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .opacity(snapshot.isUnlocked(n) ? 1 : 0.35)
            .widgetAccentable(level >= 3)
    }
}
