import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    var openTableau: () -> Void = {}

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header
                    todayBlock
                    weekBlock
                    focusBlock
                    factBlock
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Header

    private var dateLines: (weekday: String, french: String, english: String) {
        let now = Date()
        let fr = Locale(identifier: "fr_FR")
        let weekday = now.formatted(.dateTime.weekday(.wide).locale(fr))
        let month = now.formatted(.dateTime.month(.wide).locale(fr))
        let dayNumber = Calendar.current.component(.day, from: now)
        let dayWords = dayNumber == 1 ? "premier" : FrenchNumber.words(for: dayNumber)
        let english = now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return (weekday, "\(dayWords) \(month)", english)
    }

    private var header: some View {
        let lines = dateLines
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lines.weekday)
                    .font(Typeface.serif(.title3, weight: .regular).italic())
                    .foregroundStyle(Palette.inkMuted)
                Text(lines.french)
                    .font(Typeface.numeral(40, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(lines.english)
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 12)
            ribbon
        }
        .accessibilityElement(children: .combine)
    }

    /// The streak hangs from the top of the page like a notebook's bookmark ribbon.
    private var ribbon: some View {
        let active = store.streak > 0
        return ZStack(alignment: .top) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 78))
                .foregroundStyle(active ? Palette.pen : Palette.ink.opacity(0.16))
            VStack(spacing: 0) {
                Text("\(store.streak)")
                    .font(Typeface.numeral(26, relativeTo: .title))
                Text(store.streak == 1 ? "day" : "days")
                    .font(Typeface.ui(.caption2, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : Palette.inkMuted)
            .padding(.top, 10)
        }
        .frame(width: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(store.streak) day streak")
    }

    // MARK: Today

    private var stampDate: String {
        Date().formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    private var todaysGrade: Int? {
        store.data.sessions.last { $0.day == store.todayKey && !$0.torn }?.grade
    }

    @ViewBuilder
    private var todayBlock: some View {
        if store.completedToday {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 18) {
                    DateStamp(word: "Vu", date: stampDate)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today’s page is done.")
                            .font(Typeface.numeral(26, relativeTo: .title2))
                            .foregroundStyle(Palette.ink)
                        if let grade = todaysGrade {
                            Text("You scored \(grade) out of 20.")
                                .font(Typeface.ui(.subheadline))
                                .foregroundStyle(Palette.inkMuted)
                        }
                    }
                }
                Button {
                    store.lessonRequest = LessonRequest()
                } label: {
                    Text("Write a bonus page")
                }
                .buttonStyle(InkButtonStyle(kind: .secondary))
                Text("Bonus pages earn half points and keep what you know fresh.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today’s page")
                    .font(Typeface.numeral(34, relativeTo: .title))
                    .foregroundStyle(Palette.ink)
                Text(planLine)
                    .font(Typeface.ui(.body))
                    .foregroundStyle(Palette.inkMuted)
                if let note = statusNote {
                    Text(note)
                        .font(Typeface.hand(22, relativeTo: .title3))
                        .foregroundStyle(Palette.pen)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    store.lessonRequest = LessonRequest()
                } label: {
                    Text("Write today’s page")
                }
                .buttonStyle(InkButtonStyle(kind: .primary))
                .padding(.top, 4)
            }
        }
    }

    private var planLine: String {
        var pieces: [String] = []
        if store.newCount > 0 { pieces.append("\(store.newCount) new \(store.newCount == 1 ? "number" : "numbers")") }
        if store.dueCount > 0 { pieces.append("\(store.dueCount) to review") }
        let about = "10 exercises, about 4 minutes."
        if pieces.isEmpty { return about }
        return pieces.joined(separator: " and ").capitalizedFirst + ". " + about
    }

    private var statusNote: String? {
        if store.lessonMode == .guided {
            return "A gentler page today: hints on, no tearing."
        }
        switch store.streakStatus {
        case .protected:
            return "A mot d’excuse will cover yesterday."
        case .broken where store.data.streak.current > 0:
            return "Your run ended. Start a new one today."
        default:
            return nil
        }
    }

    // MARK: Week

    private var weekBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("This week")
                .font(Typeface.serif(.title3, weight: .semibold))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 0) {
                ForEach(store.lastDays(7)) { day in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    day.done ? Palette.pen : Palette.ink.opacity(0.25),
                                    style: StrokeStyle(lineWidth: day.done ? 2.5 : 1.5,
                                                       dash: (day.done || day.excused) ? [] : [3, 3])
                                )
                            if day.done {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Palette.pen)
                            } else if day.excused {
                                Image(systemName: "envelope.fill")
                                    .font(.caption)
                                    .foregroundStyle(Palette.inkMuted)
                            }
                        }
                        .frame(width: 36, height: 36)
                        Text(weekdayLetter(day.date))
                            .font(Typeface.ui(.caption2, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? Palette.ink : Palette.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: day))
                }
            }
        }
    }

    private func weekdayLetter(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.weekday(.narrow))
    }

    private func accessibilityLabel(for day: DayCell) -> String {
        let name = day.date?.formatted(.dateTime.weekday(.wide)) ?? ""
        if day.done { return "\(name), page written" }
        if day.excused { return "\(name), covered by a mot d’excuse" }
        return day.isToday ? "\(name), today, not written yet" : "\(name), missed"
    }

    // MARK: Focus

    private var frontier: Chapter {
        let unlocked = Curriculum.chapters.filter { store.isUnlocked($0) }
        return unlocked.first { !Curriculum.isCleared($0, records: store.data.records) }
            ?? unlocked.last
            ?? Curriculum.chapters[0]
    }

    private var focusBlock: some View {
        let chapter = frontier
        return VStack(alignment: .leading, spacing: 10) {
            Hairline()
            Text("Working on")
                .font(Typeface.ui(.footnote))
                .foregroundStyle(Palette.inkMuted)
                .padding(.top, 6)
            HStack(alignment: .firstTextBaseline) {
                Text(chapter.rangeLabel)
                    .font(Typeface.numeral(26, relativeTo: .title2))
                    .foregroundStyle(Palette.ink)
                Text(chapter.nickname)
                    .font(Typeface.serif(.body).italic())
                    .foregroundStyle(Palette.inkMuted)
            }
            InkProgressBar(value: store.progress(of: chapter))
            Button {
                openTableau()
            } label: {
                Text("See the rule on the Tableau")
                    .font(Typeface.ui(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .underline()
            }
            .frame(minHeight: 44, alignment: .leading)
        }
    }

    // MARK: Fact

    private var factBlock: some View {
        let ordinal = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let fact = FrenchNumber.facts[ordinal % FrenchNumber.facts.count]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Le saviez-vous ?")
                .font(Typeface.hand(24, relativeTo: .title3))
                .foregroundStyle(Palette.pen)
            Text(fact)
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
