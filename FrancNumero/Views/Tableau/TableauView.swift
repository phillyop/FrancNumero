import SwiftUI

struct NumberSelection: Identifiable {
    let id: Int
}

struct TableauView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedNumber: NumberSelection?
    @State private var selectedChapter: Chapter?

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    chart
                    legend
                    chapterList
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selectedNumber) { selection in
            NumberDetailView(number: selection.id)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedChapter) { chapter in
            ChapterDetailView(chapter: chapter)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Le Tableau")
                .font(Typeface.numeral(40, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Text("Every number from 0 to 100. Tap one to hear it and see how it’s built.")
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(store.solidCount) of 101 numbers solid")
                .font(Typeface.ui(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 4)
        }
    }

    // MARK: Hundred chart

    private var chart: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 10),
            spacing: 4
        ) {
            ForEach(0...100, id: \.self) { n in
                tile(n)
            }
        }
    }

    private func tile(_ n: Int) -> some View {
        let level = store.level(of: n)
        let locked = Curriculum.chapter(containing: n).map { !store.isUnlocked($0) } ?? false
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)

        return Button {
            selectedNumber = NumberSelection(id: n)
        } label: {
            Text("\(n)")
                .font(Typeface.numeral(15, relativeTo: .caption))
                .foregroundStyle(level.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(level.fill, in: shape)
                .overlay(shape.strokeBorder(Palette.ink.opacity(level == .unseen ? 0.25 : 0), lineWidth: 1))
                .opacity(locked ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(n), \(FrenchNumber.words(for: n)), \(level.label)\(locked ? ", locked chapter" : "")")
    }

    private var legend: some View {
        let levels: [MasteryLevel] = [.unseen, .shaky, .learning, .solid, .mastered]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .leading)],
                         alignment: .leading, spacing: 8) {
            ForEach(levels, id: \.rawValue) { level in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(level.fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Palette.ink.opacity(0.25), lineWidth: 1)
                        )
                        .frame(width: 16, height: 16)
                    Text(level.label)
                        .font(Typeface.ui(.caption))
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Chapters

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Chapters")
                .font(Typeface.serif(.title2, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 12)
            Hairline()
            ForEach(Curriculum.chapters) { chapter in
                Button {
                    selectedChapter = chapter
                } label: {
                    chapterRow(chapter)
                }
                .buttonStyle(.plain)
                Hairline()
            }
        }
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        let unlocked = store.isUnlocked(chapter)
        let progress = store.progress(of: chapter)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(chapter.rangeLabel)
                    .font(Typeface.numeral(24, relativeTo: .title2))
                    .foregroundStyle(Palette.ink)
                Text("\(chapter.title), \(chapter.nickname.lowercased())")
                    .font(Typeface.serif(.subheadline).italic())
                    .foregroundStyle(Palette.inkMuted)
                InkProgressBar(value: progress, tint: Palette.ink)
                    .frame(maxWidth: 220)
            }
            Spacer(minLength: 8)
            Image(systemName: unlocked ? "chevron.right" : "lock.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .opacity(unlocked ? 1 : 0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chapter.rangeLabel), \(chapter.title), \(Int(progress * 100)) percent\(unlocked ? "" : ", locked")")
    }
}

// MARK: - Number detail

struct NumberDetailView: View {
    let number: Int
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let record = store.data.records[number]
        let level = record.level

        return ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("\(number)")
                        .font(Typeface.numeral(140, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(FrenchNumber.words(for: number))
                        .font(Typeface.serif(.largeTitle, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                    AnatomyView(number: number)
                    if let tip = FrenchNumber.tip(for: number) {
                        Text(tip)
                            .font(Typeface.serif(.body).italic())
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if SpeechService.shared.isAvailable {
                        SpeakerButtons(number: number)
                    } else {
                        Text("No French voice is installed. Add one in Settings, Accessibility, Spoken Content, Voices, French.")
                            .font(Typeface.ui(.footnote))
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Hairline()
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(level.fill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Palette.ink.opacity(0.25), lineWidth: 1)
                            )
                            .frame(width: 18, height: 18)
                        Text(level.label)
                            .font(Typeface.ui(.headline))
                            .foregroundStyle(Palette.ink)
                    }
                    if record.seen > 0 {
                        Text("Answered \(record.seen) \(record.seen == 1 ? "time" : "times"), \(record.misses) missed.")
                            .font(Typeface.ui(.footnote))
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Chapter detail

struct ChapterDetailView: View {
    let chapter: Chapter
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let unlocked = store.isUnlocked(chapter)
        let known = chapter.numbers.filter { store.data.records[$0].seen > 0 && store.data.records[$0].box >= 1 }.count

        return ZStack {
            PaperBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(chapter.rangeLabel)
                        .font(Typeface.numeral(44, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.ink)
                    Text("\(chapter.title), \(chapter.nickname.lowercased())")
                        .font(Typeface.serif(.title3).italic())
                        .foregroundStyle(Palette.inkMuted)
                    Text(chapter.rule)
                        .font(Typeface.serif(.body))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Writing it")
                            .font(Typeface.hand(26, relativeTo: .title3))
                            .foregroundStyle(Palette.pen)
                        Text(chapter.writing)
                            .font(Typeface.serif(.body))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Hairline()
                    ForEach(chapter.examples, id: \.self) { n in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("\(n)")
                                    .font(Typeface.numeral(36, relativeTo: .title))
                                    .foregroundStyle(Palette.ink)
                                Text(FrenchNumber.words(for: n))
                                    .font(Typeface.serif(.title3, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(2)
                            }
                            if let recipe = FrenchNumber.anatomy(for: n).equation {
                                Text(recipe)
                                    .font(Typeface.ui(.footnote))
                                    .foregroundStyle(Palette.inkMuted)
                            }
                        }
                    }

                    Hairline()
                    Text("\(known) of \(chapter.numbers.count) numbers answered correctly")
                        .font(Typeface.ui(.footnote))
                        .foregroundStyle(Palette.inkMuted)

                    if !unlocked {
                        Text("This chapter opens when you’ve answered about three quarters of the one before it, or when you test out of that one.")
                            .font(Typeface.serif(.callout).italic())
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        practise()
                    } label: {
                        Text("Practise \(chapter.rangeLabel)")
                    }
                    .buttonStyle(InkButtonStyle(kind: .primary))
                    .disabled(!unlocked)

                    testOutBlock
                }
                .padding(.leading, Metrics.pagePadding)
                .padding(.trailing, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var testOutBlock: some View {
        let status = store.testOutStatus(for: chapter)
        switch status {
        case .available:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    testOut()
                } label: {
                    Text("Test out of this chapter")
                }
                .buttonStyle(InkButtonStyle(kind: .secondary))
                Text("Already know it? Ten questions, one try each. Get \(SessionBuilder.testPassMark) right to open the next chapter. One attempt a day, and no penalty if you miss.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .triedToday:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                } label: {
                    Text("Test out of this chapter")
                }
                .buttonStyle(InkButtonStyle(kind: .secondary))
                .disabled(true)
                Text("You’ve had your attempt for today. Practise, then try again tomorrow.")
                    .font(Typeface.ui(.footnote))
                    .foregroundStyle(Palette.inkMuted)
            }
        case .alreadyCleared:
            Text("You’ve cleared this chapter.")
                .font(Typeface.ui(.footnote, weight: .semibold))
                .foregroundStyle(Palette.inkMuted)
        case .chapterLocked:
            EmptyView()
        }
    }

    /// Closes this sheet first, then opens the lesson, so the two presentations don't collide.
    private func practise() {
        launch(LessonRequest(chapter: chapter.id))
    }

    private func testOut() {
        launch(LessonRequest(testOutChapter: chapter.id))
    }

    private func launch(_ request: LessonRequest) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            store.lessonRequest = request
        }
    }
}
