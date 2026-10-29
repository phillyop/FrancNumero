import SwiftUI
import WidgetKit

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// The widget's story changes through the day, not just when the app runs: at midnight a new page is
/// due, at 18:00 a run in danger gets a nudge, at 21:00 a last call. Those moments are scheduled as
/// timeline entries, so the widget is right even if the app hasn't been opened.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        let snapshot = context.isPreview ? WidgetSnapshot.sample : (WidgetSnapshot.load() ?? WidgetSnapshot())
        completion(TodayEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? WidgetSnapshot()
        let calendar = Calendar.current
        let now = Date()

        var dates: [Date] = [now]
        for dayOffset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            for hour in [0, 18, 21] {
                if let moment = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day), moment > now {
                    dates.append(moment)
                }
            }
        }
        let entries = dates.sorted().map { TodayEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - What the widget has to say

struct TodayState {
    let date: Date
    let run: Int
    let status: WidgetSnapshot.RunState
    let done: Bool
    let grade: Int?
    let week: [WidgetSnapshot.WeekDay]
    let hour: Int
    let hasData: Bool
    let newCount: Int
    let dueCount: Int
    let excuses: Int
    let levelCode: String
    let levelProgress: Double
    let nextLevelCode: String?
    let pointsToNext: Int

    init(entry: TodayEntry) {
        let s = entry.snapshot
        let calendar = Calendar.current
        let key = WidgetSnapshot.dayKey(entry.date, calendar: calendar)

        date = entry.date
        run = s.runLength(on: key)
        status = s.runState(on: key)
        done = s.pageDone(on: key)
        grade = s.grade(on: key)
        week = s.week(endingOn: key, calendar: calendar)
        hour = calendar.component(.hour, from: entry.date)
        hasData = s.hasOnboarded
        newCount = s.newCount
        dueCount = s.dueCount
        excuses = s.excuses
        levelCode = s.levelCode
        levelProgress = s.levelProgress
        nextLevelCode = s.nextLevelCode
        pointsToNext = s.pointsToNext
    }

    /// A run is on the line this evening.
    var atRisk: Bool { !done && run > 0 && hour >= 18 }
    var urgent: Bool { !done && run > 0 && hour >= 21 }

    var weekday: String {
        date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR")))
    }

    var dayMonth: String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    var stampDate: String { dayMonth }

    /// The big line.
    var headline: String {
        if !hasData { return "Open your cahier" }
        if done { return "Page done" }
        if urgent { return "Last call !" }
        switch status {
        case .fresh: return "Your first page"
        case .broken: return "Start a new run"
        default: return "Today’s page"
        }
    }

    /// The line under it.
    var detail: String {
        if !hasData { return "Open FrancNumero once to begin." }
        if done { return grade.map { "\($0) out of 20. Back tomorrow." } ?? "Back tomorrow." }
        if urgent { return "Your \(run)-day run ends tonight." }
        if atRisk { return "Your \(run)-day run needs today’s page." }
        switch status {
        case .fresh: return "Three minutes. Tap to start."
        case .broken: return "One page restarts it."
        case .protected: return "A mot d’excuse will cover yesterday."
        default:
            var pieces: [String] = []
            if newCount > 0 { pieces.append("\(newCount) new") }
            if dueCount > 0 { pieces.append("\(dueCount) to review") }
            return pieces.isEmpty ? "Tap to write it." : pieces.joined(separator: ", ")
        }
    }

    /// The headline is the teacher's red pen when something needs doing tonight.
    var headlineIsUrgent: Bool { urgent }

    var link: URL {
        (!hasData || done) ? WidgetLink.today : WidgetLink.lesson
    }

    /// Short text for the Lock Screen's inline slot.
    var inlineText: String {
        if !hasData { return "Open FrancNumero" }
        if done { return run > 0 ? "\(run) days · page done" : "Page done" }
        if urgent { return "Run of \(run) ends tonight" }
        if run == 0 { return "Write your first page" }
        return "\(run) days · page due"
    }
}

// MARK: - Home Screen: small

struct TodaySmallView: View {
    let state: TodayState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.weekday)
                        .font(WFont.serif(12).italic())
                        .foregroundStyle(WPalette.inkMuted)
                    Text(state.dayMonth)
                        .font(WFont.numeral(15))
                        .foregroundStyle(WPalette.ink)
                }
                Spacer(minLength: 0)
                RunRibbon(count: state.run, active: state.run > 0, height: 46)
            }

            Spacer(minLength: 0)

            if state.done {
                HStack(spacing: 8) {
                    StampBadge(word: "Vu", detail: state.stampDate, size: 46)
                    if let grade = state.grade {
                        Text("\(grade)/20")
                            .font(WFont.hand(22))
                            .foregroundStyle(WPalette.pen)
                            .widgetAccentable()
                    }
                }
            } else {
                Text(state.headline)
                    .font(state.headlineIsUrgent ? WFont.hand(21) : WFont.numeral(17))
                    .foregroundStyle(state.headlineIsUrgent ? WPalette.pen : WPalette.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(state.detail)
                    .font(WFont.ui(10.5))
                    .foregroundStyle(WPalette.inkMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            WeekStamps(days: state.week, size: 13, showsLetters: false)
                .padding(.top, 2)
        }
    }
}

// MARK: - Home Screen: medium

struct TodayMediumView: View {
    let state: TodayState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.weekday)
                    .font(WFont.serif(13).italic())
                    .foregroundStyle(WPalette.inkMuted)
                Text(state.dayMonth)
                    .font(WFont.numeral(20))
                    .foregroundStyle(WPalette.ink)
                Spacer(minLength: 0)
                if state.done {
                    HStack(spacing: 8) {
                        StampBadge(word: "Vu", detail: state.stampDate, size: 50)
                        if let grade = state.grade {
                            Text("\(grade)/20")
                                .font(WFont.hand(24))
                                .foregroundStyle(WPalette.pen)
                                .widgetAccentable()
                        }
                    }
                } else {
                    Text(state.headline)
                        .font(state.headlineIsUrgent ? WFont.hand(24) : WFont.numeral(19))
                        .foregroundStyle(state.headlineIsUrgent ? WPalette.pen : WPalette.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(state.detail)
                        .font(WFont.ui(11))
                        .foregroundStyle(WPalette.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 8) {
                RunRibbon(count: state.run, active: state.run > 0, height: 50)
                WeekStamps(days: state.week, size: 18, showsLetters: true)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(state.levelCode)
                        .font(WFont.numeral(15))
                        .foregroundStyle(WPalette.ink)
                    WidgetBar(value: state.levelProgress, tint: WPalette.pen)
                        .frame(width: 70)
                    if state.excuses > 0 {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(WPalette.inkMuted)
                    }
                }
            }
            .frame(width: 168, alignment: .trailing)
        }
    }
}

// MARK: - Lock Screen

struct TodayCircularView: View {
    let state: TodayState

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            WeekRing(days: state.week)
                .padding(4)
            VStack(spacing: 0) {
                Image(systemName: state.done ? "checkmark" : "bookmark.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(state.run)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetAccentable()
    }
}

struct TodayRectangularView: View {
    let state: TodayState

    private var title: String {
        state.run == 0 ? "FrancNumero" : "\(state.run)-day run"
    }

    private var line: String {
        if !state.hasData { return "Open the app to begin" }
        if state.done { return state.grade.map { "Page done · \($0)/20" } ?? "Page done" }
        if state.urgent { return "Ends tonight. Write today’s page" }
        if state.atRisk { return "Today’s page keeps it going" }
        return "Today’s page is waiting"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 11))
                Text(title)
                    .font(.headline)
                    .widgetAccentable()
            }
            Text(line)
                .font(.caption)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            AccessoryDots(days: state.week)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TodayInlineView: View {
    let state: TodayState

    var body: some View {
        Label(state.inlineText, systemImage: "bookmark.fill")
    }
}

// MARK: - Entry view and widget

struct TodayEntryView: View {
    let entry: TodayEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        let state = TodayState(entry: entry)
        switch family {
        case .systemMedium:
            TodayMediumView(state: state)
                .widgetURL(state.link)
                .paperWidgetBackground()
        case .accessoryCircular:
            TodayCircularView(state: state)
                .widgetURL(state.link)
                .clearWidgetBackground()
        case .accessoryRectangular:
            TodayRectangularView(state: state)
                .widgetURL(state.link)
                .clearWidgetBackground()
        case .accessoryInline:
            TodayInlineView(state: state)
                .widgetURL(state.link)
                .clearWidgetBackground()
        default:
            TodaySmallView(state: state)
                .widgetURL(state.link)
                .paperWidgetBackground()
        }
    }
}

struct TodayPageWidget: Widget {
    static let kind = "FrancNumeroToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TodayProvider()) { entry in
            TodayEntryView(entry: entry)
        }
        .configurationDisplayName("Today’s page")
        .description("Your run, your week, and whether today’s page is written. It gets louder in the evening if your run is at risk.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    TodayPageWidget()
} timeline: {
    TodayEntry(date: Date(), snapshot: .sample)
    TodayEntry(date: Date(), snapshot: .sampleDone)
    TodayEntry(date: Date(), snapshot: .sampleFresh)
}

#Preview("Medium", as: .systemMedium) {
    TodayPageWidget()
} timeline: {
    TodayEntry(date: Date(), snapshot: .sample)
    TodayEntry(date: Date(), snapshot: .sampleDone)
}

#Preview("Circular", as: .accessoryCircular) {
    TodayPageWidget()
} timeline: {
    TodayEntry(date: Date(), snapshot: .sample)
    TodayEntry(date: Date(), snapshot: .sampleDone)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TodayPageWidget()
} timeline: {
    TodayEntry(date: Date(), snapshot: .sample)
    TodayEntry(date: Date(), snapshot: .sampleDone)
}

#Preview("Inline", as: .accessoryInline) {
    TodayPageWidget()
} timeline: {
    TodayEntry(date: Date(), snapshot: .sample)
}
