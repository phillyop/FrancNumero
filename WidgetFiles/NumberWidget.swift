import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Settings the learner can choose

enum NumberFocus: String, AppEnum {
    case needsWork
    case newOnes
    case mixed

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Number focus")

    static var caseDisplayRepresentations: [NumberFocus: DisplayRepresentation] = [
        .needsWork: DisplayRepresentation(title: "Numbers that need work"),
        .newOnes: DisplayRepresentation(title: "New numbers"),
        .mixed: DisplayRepresentation(title: "A bit of everything")
    ]

    /// Which of the app's numbers this choice draws from. Nil means all of them.
    var reasons: Set<FocusNumber.Reason>? {
        switch self {
        case .needsWork: return [.needsWork, .due]
        case .newOnes: return [.new]
        case .mixed: return nil
        }
    }
}

struct NumberFocusIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Number focus"
    static var description = IntentDescription("Choose which numbers this widget teaches you.")

    @Parameter(title: "Show me", default: .needsWork)
    var focus: NumberFocus
}

/// The little arrow on the widget: show another number without opening the app.
struct NextNumberIntent: AppIntent {
    static var title: LocalizedStringResource = "Next number"
    static var description = IntentDescription("Shows another number on the widget.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: NumberStore.offsetKey) + 1, forKey: NumberStore.offsetKey)
        WidgetCenter.shared.reloadTimelines(ofKind: NumberWidget.kind)
        return .result()
    }
}

enum NumberStore {
    /// How many times the learner has tapped "next". It shifts the rotation.
    static let offsetKey = "numberWidget.offset"
}

extension FocusNumber.Reason {
    var french: String {
        switch self {
        case .needsWork: return "À revoir"
        case .due: return "À réviser"
        case .new: return "Nouveau"
        case .practice: return "Au programme"
        }
    }

    var english: String {
        switch self {
        case .needsWork: return "needs work"
        case .due: return "due for review"
        case .new: return "new"
        case .practice: return "keeping it fresh"
        }
    }
}

// MARK: - Timeline

struct NumberEntry: TimelineEntry {
    let date: Date
    let number: FocusNumber
    let hasData: Bool
}

/// A new number every three hours, for the next day: the Home Screen teaches quietly all day.
struct NumberProvider: AppIntentTimelineProvider {
    typealias Entry = NumberEntry
    typealias Intent = NumberFocusIntent

    func placeholder(in context: Context) -> NumberEntry {
        NumberEntry(date: Date(), number: FocusNumber.starters[6], hasData: true)
    }

    func snapshot(for configuration: NumberFocusIntent, in context: Context) async -> NumberEntry {
        makeEntry(at: Date(), configuration: configuration, preview: context.isPreview)
    }

    func timeline(for configuration: NumberFocusIntent, in context: Context) async -> Timeline<NumberEntry> {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let slotStart = calendar.date(bySettingHour: (hour / 3) * 3, minute: 0, second: 0, of: now) ?? now

        var entries: [NumberEntry] = []
        for step in 0..<8 {
            guard let slot = calendar.date(byAdding: .hour, value: 3 * step, to: slotStart) else { continue }
            entries.append(makeEntry(at: step == 0 ? now : slot, configuration: configuration, preview: false))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func makeEntry(at date: Date, configuration: NumberFocusIntent, preview: Bool) -> NumberEntry {
        let snapshot = preview ? WidgetSnapshot.sample : WidgetSnapshot.load()
        let offset = UserDefaults.standard.integer(forKey: NumberStore.offsetKey)
        let number = (snapshot ?? WidgetSnapshot()).focusNumber(
            at: date,
            reasons: configuration.focus.reasons,
            offset: offset
        )
        return NumberEntry(date: date, number: number, hasData: snapshot?.hasOnboarded ?? false)
    }
}

// MARK: - Views

struct NextNumberButton: View {
    var body: some View {
        Button(intent: NextNumberIntent()) {
            Image(systemName: "arrow.2.squarepath")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(WPalette.inkMuted)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next number")
    }
}

struct RecipeChip: View {
    let text: String
    var size: CGFloat = 10.5

    var body: some View {
        Text(text)
            .font(WFont.ui(size, weight: .semibold))
            .foregroundStyle(WPalette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(WPalette.marker.opacity(0.6), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct NumberSmallView: View {
    let entry: NumberEntry

    var body: some View {
        let number = entry.number
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(number.reason.french)
                    .font(WFont.hand(17))
                    .foregroundStyle(WPalette.pen)
                    .widgetAccentable()
                Spacer(minLength: 0)
                NextNumberButton()
                    .padding(.trailing, -6)
            }
            Spacer(minLength: 0)
            Text("\(number.n)")
                .font(WFont.numeral(54))
                .foregroundStyle(WPalette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(number.words)
                .font(WFont.serif(14, weight: .semibold))
                .foregroundStyle(WPalette.ink)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
            if let recipe = number.recipe {
                RecipeChip(text: recipe)
                    .padding(.top, 4)
            }
        }
    }
}

struct NumberMediumView: View {
    let entry: NumberEntry

    var body: some View {
        let number = entry.number
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(number.reason.french)
                    .font(WFont.hand(19))
                    .foregroundStyle(WPalette.pen)
                    .widgetAccentable()
                Text("\(number.n)")
                    .font(WFont.numeral(68))
                    .foregroundStyle(WPalette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(number.words)
                    .font(WFont.serif(16, weight: .semibold))
                    .foregroundStyle(WPalette.ink)
                    .minimumScaleFactor(0.65)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(number.reason.english)
                        .font(WFont.ui(11))
                        .foregroundStyle(WPalette.inkMuted)
                    Spacer(minLength: 0)
                    NextNumberButton()
                        .padding(.trailing, -6)
                }
                if let recipe = number.recipe {
                    Text("\(recipe) = \(number.n)")
                        .font(WFont.numeral(22))
                        .foregroundStyle(WPalette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WPalette.marker.opacity(0.6), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                if let tip = number.tip {
                    Text(tip)
                        .font(WFont.serif(12).italic())
                        .foregroundStyle(WPalette.inkMuted)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Label("Hear it in the app", systemImage: "speaker.wave.2.fill")
                    .font(WFont.ui(10, weight: .semibold))
                    .foregroundStyle(WPalette.inkMuted)
            }
            .frame(width: 150, alignment: .leading)
        }
    }
}

struct NumberCircularView: View {
    let entry: NumberEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text("\(entry.number.n)")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .minimumScaleFactor(0.5)
                .padding(6)
        }
        .widgetAccentable()
    }
}

struct NumberRectangularView: View {
    let entry: NumberEntry

    var body: some View {
        let number = entry.number
        HStack(spacing: 8) {
            Text("\(number.n)")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(number.words)
                    .font(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(number.recipe ?? number.reason.english)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NumberInlineView: View {
    let entry: NumberEntry

    var body: some View {
        Label("\(entry.number.n) · \(entry.number.words)", systemImage: "textformat.123")
    }
}

struct NumberEntryView: View {
    let entry: NumberEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            NumberMediumView(entry: entry)
                .widgetURL(WidgetLink.number(entry.number.n))
                .paperWidgetBackground()
        case .accessoryCircular:
            NumberCircularView(entry: entry)
                .widgetURL(WidgetLink.number(entry.number.n))
                .clearWidgetBackground()
        case .accessoryRectangular:
            NumberRectangularView(entry: entry)
                .widgetURL(WidgetLink.number(entry.number.n))
                .clearWidgetBackground()
        case .accessoryInline:
            NumberInlineView(entry: entry)
                .widgetURL(WidgetLink.number(entry.number.n))
                .clearWidgetBackground()
        default:
            NumberSmallView(entry: entry)
                .widgetURL(WidgetLink.number(entry.number.n))
                .paperWidgetBackground()
        }
    }
}

struct NumberWidget: Widget {
    static let kind = "FrancNumeroNumber"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NumberFocusIntent.self, provider: NumberProvider()) { entry in
            NumberEntryView(entry: entry)
        }
        .configurationDisplayName("Un nombre")
        .description("A French number every three hours, picked from the ones you need most. Tap the arrow for another, or tap the number to open it in the app.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NumberWidget()
} timeline: {
    NumberEntry(date: Date(), number: FocusNumber.starters[6], hasData: true)
    NumberEntry(date: Date(), number: FocusNumber.starters[7], hasData: true)
    NumberEntry(date: Date(), number: FocusNumber.starters[0], hasData: true)
}

#Preview("Medium", as: .systemMedium) {
    NumberWidget()
} timeline: {
    NumberEntry(date: Date(), number: FocusNumber.starters[6], hasData: true)
    NumberEntry(date: Date(), number: FocusNumber.starters[3], hasData: true)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NumberWidget()
} timeline: {
    NumberEntry(date: Date(), number: FocusNumber.starters[6], hasData: true)
}

#Preview("Circular", as: .accessoryCircular) {
    NumberWidget()
} timeline: {
    NumberEntry(date: Date(), number: FocusNumber.starters[10], hasData: true)
}

#Preview("Inline", as: .accessoryInline) {
    NumberWidget()
} timeline: {
    NumberEntry(date: Date(), number: FocusNumber.starters[6], hasData: true)
}
