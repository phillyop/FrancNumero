import SwiftUI

// MARK: - Torn page

/// Three crossed-out answers tear the page. The points are lost; the learning isn't.
struct TornPageView: View {
    var onContinue: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var torn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.surface)
                    .frame(width: 150, height: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Palette.ink.opacity(0.25), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "scribble")
                            .font(.system(size: 72, weight: .bold))
                            .foregroundStyle(Palette.pen)
                    )
                    .rotationEffect(.degrees(torn ? -22 : 0))
                    .scaleEffect(torn ? 0.84 : 1)
                    .offset(x: torn ? -16 : 0, y: torn ? 20 : 0)
                    .accessibilityHidden(true)
                Spacer()
            }
            .padding(.bottom, 12)

            Text("Page torn")
                .font(Typeface.numeral(46, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Text("Three answers crossed out. The points from this page are lost, but what you missed isn’t. Read the correction, then start again on a clean page.")
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text("See the correction")
            }
            .buttonStyle(InkButtonStyle(kind: .pen))
        }
        .padding(.leading, Metrics.pagePadding)
        .padding(.trailing, 24)
        .padding(.bottom, 16)
        .onAppear {
            if reduceMotion {
                torn = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.45).delay(0.2)) {
                    torn = true
                }
            }
            // The tear sound and buzz land with the page's first movement.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                store.playEffect(.tear)
                store.playHaptic(.tear)
            }
        }
    }
}

// MARK: - Correction

struct CorrectionRow: View {
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("\(number)")
                    .font(Typeface.numeral(56, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.pen)
                Text(FrenchNumber.words(for: number))
                    .font(Typeface.serif(.title2, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button {
                    SpeechService.shared.speakNumber(number)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Listen to \(FrenchNumber.words(for: number))")
            }
            AnatomyView(number: number)
            if let tip = FrenchNumber.tip(for: number) {
                Text(tip)
                    .font(Typeface.serif(.callout).italic())
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CorrectionView: View {
    let numbers: [Int]
    let title: String
    var subtitle: String? = nil
    let buttonTitle: String
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(title)
                        .font(Typeface.numeral(40, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Typeface.serif(.body))
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(numbers, id: \.self) { n in
                        Hairline()
                        CorrectionRow(number: n)
                    }
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            Button {
                onContinue()
            } label: {
                Text(buttonTitle)
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Result

/// The mark out of 20, circled in red pen.
struct GradeMark: View {
    let grade: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(grade)")
                .font(Typeface.numeral(96, relativeTo: .largeTitle))
            Text("/20")
                .font(Typeface.numeral(40, relativeTo: .title))
        }
        .foregroundStyle(Palette.pen)
        .padding(.horizontal, 38)
        .padding(.vertical, 24)
        .overlay(
            Ellipse()
                .trim(from: 0, to: drawn)
                .stroke(Palette.pen, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-4))
        )
        .onAppear {
            if reduceMotion {
                drawn = 1
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.25)) { drawn = 1 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score: \(grade) out of 20")
    }
}

struct ResultView: View {
    let summary: LessonSummary
    var onDone: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stamped = false
    @State private var showCorrection = false

    private var remark: (french: String, english: String) { Remark.forGrade(summary.grade) }

    private var stampDate: String {
        Date().formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR")))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Spacer()
                        GradeMark(grade: summary.grade)
                        Spacer()
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(remark.french)
                            .font(Typeface.hand(44, relativeTo: .largeTitle))
                            .foregroundStyle(Palette.pen)
                        Text(remark.english)
                            .font(Typeface.serif(.body).italic())
                            .foregroundStyle(Palette.inkMuted)
                    }

                    HStack(alignment: .center, spacing: 20) {
                        DateStamp(word: "Vu", date: stampDate)
                            .scaleEffect(stamped ? 1 : 1.9)
                            .opacity(stamped ? 1 : 0)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("+\(summary.pointsEarned) bons points")
                                .font(Typeface.numeral(26, relativeTo: .title2))
                                .foregroundStyle(Palette.ink)
                            if summary.guided {
                                Text("Guided page: half points.")
                                    .font(Typeface.ui(.footnote))
                                    .foregroundStyle(Palette.inkMuted)
                            } else if !summary.isDailyPage {
                                Text("Bonus page: half points.")
                                    .font(Typeface.ui(.footnote))
                                    .foregroundStyle(Palette.inkMuted)
                            }
                            Text(summary.streak == 1 ? "Day 1 of your run" : "Day \(summary.streak) in a row")
                                .font(Typeface.serif(.body, weight: .medium))
                                .foregroundStyle(Palette.ink)
                        }
                    }

                    if summary.excuseUsed {
                        note("A mot d’excuse covered the day you missed, so your run survived.")
                    }
                    if summary.excuseEarned {
                        note("You earned a mot d’excuse. It covers one missed day.")
                    }

                    if let level = summary.leveledUpTo {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passage en \(level.code) !")
                                .font(Typeface.hand(34, relativeTo: .title))
                                .foregroundStyle(Palette.pen)
                            Text("You moved up to \(level.name).")
                                .font(Typeface.serif(.body))
                                .foregroundStyle(Palette.ink)
                        }
                    }

                    if !summary.newGommettes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Hairline()
                            Text(summary.newGommettes.count == 1 ? "New gommette" : "New gommettes")
                                .font(Typeface.serif(.title3, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            ForEach(summary.newGommettes) { def in
                                HStack(spacing: 14) {
                                    GommetteBadge(def: def, unlocked: true, size: 48)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def.title)
                                            .font(Typeface.ui(.headline))
                                            .foregroundStyle(Palette.ink)
                                        Text(def.detail)
                                            .font(Typeface.ui(.footnote))
                                            .foregroundStyle(Palette.inkMuted)
                                    }
                                }
                            }
                        }
                    }

                    if !summary.failed.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Hairline()
                            Text("To review")
                                .font(Typeface.serif(.title3, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("These will come back first on your next page.")
                                .font(Typeface.ui(.footnote))
                                .foregroundStyle(Palette.inkMuted)
                            HStack(spacing: 10) {
                                ForEach(summary.failed.prefix(6), id: \.self) { n in
                                    Text("\(n)")
                                        .font(Typeface.numeral(22, relativeTo: .title3))
                                        .foregroundStyle(Palette.pen)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .strokeBorder(Palette.pen, lineWidth: 1.5)
                                        )
                                }
                            }
                            Button {
                                showCorrection = true
                            } label: {
                                Text("See the correction")
                                    .font(Typeface.ui(.subheadline, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .underline()
                            }
                            .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            Button {
                onDone()
            } label: {
                Text("Back to Today")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .onAppear { playCeremony() }
        .sheet(isPresented: $showCorrection) {
            ZStack {
                PaperBackground()
                CorrectionView(
                    numbers: summary.failed,
                    title: "The correction",
                    buttonTitle: "Done",
                    onContinue: { showCorrection = false }
                )
            }
        }
    }

    /// The mark's little ceremony, in order: the pen circles the mark (sound and a soft swell),
    /// then the date stamp lands (thump). An excellent mark ends with a celebratory buzz.
    private func playCeremony() {
        if reduceMotion { stamped = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)      // the circle starts drawing
            store.playEffect(.circle)
            store.playHaptic(.circling)
            try? await Task.sleep(nanoseconds: 850_000_000)      // ...and has just finished
            if !reduceMotion {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stamped = true }
            }
            store.playEffect(.stamp)
            store.playHaptic(summary.grade >= Remark.excellentFrom ? .excellent : .stamp)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typeface.serif(.callout).italic())
            .foregroundStyle(Palette.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Test-out result

struct TestOutResultView: View {
    let summary: TestOutSummary
    var onDone: () -> Void

    @EnvironmentObject private var store: AppStore
    @State private var showCorrection = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(summary.passed ? "Réussi !" : "Pas encore")
                        .font(Typeface.hand(46, relativeTo: .largeTitle))
                        .foregroundStyle(summary.passed ? Palette.leaf : Palette.pen)
                        .padding(.top, 24)

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(summary.correct)")
                            .font(Typeface.numeral(96, relativeTo: .largeTitle))
                        Text("/\(summary.total)")
                            .font(Typeface.numeral(40, relativeTo: .title))
                    }
                    .foregroundStyle(Palette.ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(summary.correct) out of \(summary.total)")

                    if summary.passed {
                        Text("You tested out of \(summary.chapter.rangeLabel).")
                            .font(Typeface.serif(.title3, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        if let next = summary.unlocked {
                            Text("\(next.rangeLabel), \(next.nickname.lowercased()), is now open.")
                                .font(Typeface.serif(.body))
                                .foregroundStyle(Palette.ink)
                        }
                        Text("The numbers you skipped come back in your reviews, so nothing slips.")
                            .font(Typeface.serif(.callout).italic())
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("You needed \(SessionBuilder.testPassMark) out of \(summary.total). Practise this chapter and try again tomorrow. No penalty, and your streak and points are untouched.")
                            .font(Typeface.serif(.body))
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !summary.failed.isEmpty {
                        Hairline()
                        Text("Missed")
                            .font(Typeface.serif(.title3, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        HStack(spacing: 10) {
                            ForEach(summary.failed.prefix(6), id: \.self) { n in
                                Text("\(n)")
                                    .font(Typeface.numeral(22, relativeTo: .title3))
                                    .foregroundStyle(Palette.pen)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Palette.pen, lineWidth: 1.5)
                                    )
                            }
                        }
                        Button {
                            showCorrection = true
                        } label: {
                            Text("See the correction")
                                .font(Typeface.ui(.subheadline, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .underline()
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            Button {
                onDone()
            } label: {
                Text("Back to Tableau")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .onAppear {
            if summary.passed {
                store.playEffect(.stamp)
                store.playHaptic(.stamp)
            }
        }
        .sheet(isPresented: $showCorrection) {
            ZStack {
                PaperBackground()
                CorrectionView(
                    numbers: summary.failed,
                    title: "The correction",
                    buttonTitle: "Done",
                    onContinue: { showCorrection = false }
                )
            }
        }
    }
}
