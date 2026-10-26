import SwiftUI

struct CahierView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSettings = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    titleRow
                    levelBlock
                    streakBlock
                    marksBlock
                    gommettesBlock
                    nextBlock
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }

    // MARK: Title

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Mon cahier")
                .font(Typeface.numeral(40, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: Level

    private var levelBlock: some View {
        let level = store.level
        let next = Levels.next(after: level)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(level.code)
                    .font(Typeface.numeral(72, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                Text(level.name)
                    .font(Typeface.serif(.title3).italic())
                    .foregroundStyle(Palette.inkMuted)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
            InkProgressBar(value: store.levelProgress, tint: Palette.pen)
            if let next {
                Text("\(store.data.points) bons points. \(max(0, next.threshold - store.data.points)) more to reach \(next.code).")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            } else {
                Text("\(store.data.points) bons points. Top of the class.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Streak

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Hairline()
            Text("Your run")
                .font(Typeface.serif(.title2, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 6)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(store.streak)")
                    .font(Typeface.numeral(48, relativeTo: .title))
                    .foregroundStyle(Palette.ink)
                Text(store.streak == 1 ? "day" : "days")
                    .font(Typeface.serif(.title3))
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Text("Best: \(store.data.streak.best)")
                    .font(Typeface.ui(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.inkMuted)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(store.lastDays(35)) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fill(for: day))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if day.isToday {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Palette.ink, lineWidth: 1.5)
                            }
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last 35 days. \(store.lastDays(35).filter { $0.done }.count) pages written.")
            Text("The last five weeks. Today is the outlined square.")
                .font(Typeface.ui(.caption))
                .foregroundStyle(Palette.inkMuted)

            VStack(alignment: .leading, spacing: 4) {
                Text("Mots d’excuse: \(store.data.streak.excuses) of \(StreakEngine.maxExcuses)")
                    .font(Typeface.ui(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("A note from home that covers one missed day. You earn one for every 7 days in a row.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
    }

    private func fill(for day: DayCell) -> Color {
        if day.done { return Palette.pen }
        if day.excused { return Palette.marker.opacity(0.8) }
        return Palette.ink.opacity(0.08)
    }

    // MARK: Marks

    private var marksBlock: some View {
        let recent = Array(store.data.sessions.suffix(6).reversed())
        return VStack(alignment: .leading, spacing: 0) {
            Hairline()
            Text("Recent marks")
                .font(Typeface.serif(.title2, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 12)
            if recent.isEmpty {
                Text("Your marks will appear here after your first page.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            } else {
                ForEach(recent) { log in
                    HStack {
                        Text(dayLabel(log.day))
                            .font(Typeface.ui(.subheadline))
                            .foregroundStyle(Palette.inkMuted)
                        Spacer()
                        if log.torn {
                            Text("Torn page")
                                .font(Typeface.hand(22, relativeTo: .title3))
                                .foregroundStyle(Palette.pen)
                        } else {
                            if log.guided {
                                Text("guided")
                                    .font(Typeface.ui(.caption))
                                    .foregroundStyle(Palette.inkMuted)
                            }
                            Text("\(log.grade)/20")
                                .font(Typeface.numeral(26, relativeTo: .title2))
                                .foregroundStyle(Palette.pen)
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    Hairline()
                }
            }
        }
    }

    private func dayLabel(_ key: String) -> String {
        guard let date = DayKey.date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: Gommettes

    private var gommettesBlock: some View {
        let earned = store.data.gommettes.count
        return VStack(alignment: .leading, spacing: 14) {
            Hairline()
            HStack(alignment: .firstTextBaseline) {
                Text("Gommettes")
                    .font(Typeface.serif(.title2, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(earned) of \(Gommettes.all.count)")
                    .font(Typeface.ui(.subheadline))
                    .foregroundStyle(Palette.inkMuted)
            }
            .padding(.top, 6)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 18) {
                ForEach(Gommettes.all) { def in
                    let unlocked = store.data.gommettes[def.id] != nil
                    VStack(spacing: 6) {
                        GommetteBadge(def: def, unlocked: unlocked, size: 60)
                        Text(def.title)
                            .font(Typeface.ui(.caption, weight: .semibold))
                            .foregroundStyle(unlocked ? Palette.ink : Palette.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(def.detail)
                            .font(Typeface.ui(.caption2))
                            .foregroundStyle(Palette.inkMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: What's next

    private var nextBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Hairline()
            Text("À suivre")
                .font(Typeface.hand(30, relativeTo: .title2))
                .foregroundStyle(Palette.pen)
                .padding(.top, 6)
            Text("This notebook is Phase 1: counting. The next chapters are already planned.")
                .font(Typeface.ui(.footnote))
                .foregroundStyle(Palette.inkMuted)
            ForEach(upcoming, id: \.title) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Typeface.serif(.body, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(item.detail)
                        .font(Typeface.ui(.footnote))
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var upcoming: [(title: String, detail: String)] {
        [
            ("Dates and days", "Days, months, calendar dates, birthdays."),
            ("Telling the time", "Hours, minutes, quarter past, everyday phrases."),
            ("Money and years", "Prices, change, euros, and years like 1789."),
            ("Real-life scenes", "Phone numbers, addresses, shopping and train platforms.")
        ]
    }
}
