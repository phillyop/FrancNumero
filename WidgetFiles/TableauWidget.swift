import SwiftUI
import WidgetKit

// MARK: - Timeline

struct TableauEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// The chart itself only changes when the app writes new data, but the run on the ribbon changes at
/// midnight, so a few midnights are scheduled ahead.
struct TableauProvider: TimelineProvider {
    func placeholder(in context: Context) -> TableauEntry {
        TableauEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TableauEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.sample : (WidgetSnapshot.load() ?? WidgetSnapshot())
        completion(TableauEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TableauEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? WidgetSnapshot()
        let calendar = Calendar.current
        let now = Date()
        var dates: [Date] = [now]
        for dayOffset in 1...3 {
            if let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) {
                dates.append(day)
            }
        }
        completion(Timeline(entries: dates.map { TableauEntry(date: $0, snapshot: snapshot) }, policy: .atEnd))
    }
}

// MARK: - Shared pieces

private struct TableauLegend: View {
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(WMastery.fill(level))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(WPalette.ink.opacity(level == 0 ? 0.22 : 0), lineWidth: 0.6)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LevelBlock: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.levelCode)
                .font(WFont.numeral(26))
                .foregroundStyle(WPalette.ink)
            WidgetBar(value: snapshot.levelProgress, tint: WPalette.pen)
            Text(snapshot.nextLevelCode.map { "\(snapshot.pointsToNext) to \($0)" } ?? "Top of the class")
                .font(WFont.ui(9.5))
                .foregroundStyle(WPalette.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct SolidBlock: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(snapshot.solidCount)")
                .font(WFont.numeral(22))
                .foregroundStyle(WPalette.ink)
                .widgetAccentable()
            Text("of 101 solid")
                .font(WFont.ui(9.5))
                .foregroundStyle(WPalette.inkMuted)
        }
    }
}

// MARK: - Large

struct TableauLargeView: View {
    let entry: TableauEntry

    var body: some View {
        let s = entry.snapshot
        let run = s.runLength(on: WidgetSnapshot.dayKey(entry.date))

        GeometryReader { geo in
            let gap: CGFloat = 3
            let headerHeight: CGFloat = 26
            let footerHeight: CGFloat = 34
            let sideWidth: CGFloat = 76
            let spacing: CGFloat = 12
            let byWidth = (geo.size.width - sideWidth - spacing - gap * 9) / 10
            let byHeight = (geo.size.height - headerHeight - footerHeight - 12 - gap * 10) / 11
            let tile = max(8, floor(min(byWidth, byHeight)))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Le Tableau")
                        .font(WFont.numeral(20))
                        .foregroundStyle(WPalette.ink)
                    Spacer(minLength: 0)
                    TableauLegend()
                }
                .frame(height: headerHeight)

                HStack(alignment: .top, spacing: spacing) {
                    MasteryGrid(snapshot: s, tile: tile, gap: gap, showNumbers: true, includeCent: true)
                    VStack(alignment: .leading, spacing: 10) {
                        RunRibbon(count: run, active: run > 0, height: 52)
                        LevelBlock(snapshot: s)
                        SolidBlock(snapshot: s)
                    }
                    .frame(width: sideWidth, alignment: .leading)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Working on \(s.chapterRange)")
                            .font(WFont.serif(12, weight: .semibold))
                            .foregroundStyle(WPalette.ink)
                        Text(s.chapterNickname.lowercased())
                            .font(WFont.serif(12).italic())
                            .foregroundStyle(WPalette.inkMuted)
                        Spacer(minLength: 0)
                        Text("\(Int((s.chapterProgress * 100).rounded()))%")
                            .font(WFont.ui(11, weight: .semibold))
                            .foregroundStyle(WPalette.inkMuted)
                    }
                    WidgetBar(value: s.chapterProgress, tint: WPalette.ink, height: 6)
                }
                .frame(height: footerHeight)
            }
        }
    }
}

// MARK: - Medium

struct TableauMediumView: View {
    let entry: TableauEntry

    var body: some View {
        let s = entry.snapshot
        let run = s.runLength(on: WidgetSnapshot.dayKey(entry.date))

        GeometryReader { geo in
            let gap: CGFloat = 2
            let tile = max(6, floor((geo.size.height - gap * 9) / 10))

            HStack(alignment: .top, spacing: 14) {
                MasteryGrid(snapshot: s, tile: tile, gap: gap, showNumbers: false, includeCent: false)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Le Tableau")
                                .font(WFont.numeral(17))
                                .foregroundStyle(WPalette.ink)
                            Text("\(s.solidCount) of 101 solid")
                                .font(WFont.ui(10.5))
                                .foregroundStyle(WPalette.inkMuted)
                        }
                        Spacer(minLength: 0)
                        RunRibbon(count: run, active: run > 0, height: 40)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        Text(s.levelCode)
                            .font(WFont.numeral(18))
                            .foregroundStyle(WPalette.ink)
                        WidgetBar(value: s.levelProgress, tint: WPalette.pen)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Working on \(s.chapterRange)")
                            .font(WFont.serif(11, weight: .semibold))
                            .foregroundStyle(WPalette.ink)
                        WidgetBar(value: s.chapterProgress, tint: WPalette.ink, height: 4)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Entry view and widget

struct TableauEntryView: View {
    let entry: TableauEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemLarge:
            TableauLargeView(entry: entry)
                .widgetURL(WidgetLink.tableau)
                .paperWidgetBackground()
        default:
            TableauMediumView(entry: entry)
                .widgetURL(WidgetLink.tableau)
                .paperWidgetBackground()
        }
    }
}

struct TableauWidget: Widget {
    static let kind = "FrancNumeroTableau"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TableauProvider()) { entry in
            TableauEntryView(entry: entry)
        }
        .configurationDisplayName("Le Tableau")
        .description("All 101 numbers, coloured by how well you know them, with your level and your run.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Large", as: .systemLarge) {
    TableauWidget()
} timeline: {
    TableauEntry(date: Date(), snapshot: .sample)
    TableauEntry(date: Date(), snapshot: .sampleFresh)
}

#Preview("Medium", as: .systemMedium) {
    TableauWidget()
} timeline: {
    TableauEntry(date: Date(), snapshot: .sample)
}
