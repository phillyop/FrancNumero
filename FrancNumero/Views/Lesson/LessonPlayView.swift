import SwiftUI

struct LessonPlayView: View {
    @Binding var engine: LessonEngine
    var onClose: () -> Void

    @EnvironmentObject private var store: AppStore

    @State private var typed = ""            // digits, for dictation
    @State private var placed: [Int] = []    // tiles, for build
    @State private var written = ""          // words, for write and transcribe
    @State private var confirmLeave = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if let exercise = engine.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        switch exercise.kind {
                        case .intro:
                            introCard(exercise)
                        case .spelling:
                            SpellingCardView()
                        default:
                            prompt(exercise)
                            exerciseBody(exercise)
                            feedback(exercise)
                        }
                    }
                    .padding(.leading, Metrics.pagePadding)
                    .padding(.trailing, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            } else {
                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sensoryFeedback(trigger: engine.correctTicks) { _, _ in haptic(.success) }
        .sensoryFeedback(trigger: engine.missTicks) { _, _ in haptic(.warning) }
        .sensoryFeedback(trigger: engine.nearMissTicks) { _, _ in haptic(.selection) }
        .onAppear { autoplayPrompt() }
        .onChange(of: engine.index) { _, _ in
            resetDrafts()
            autoplayPrompt()
        }
        .onChange(of: engine.attempt) { _, attempt in
            // After a miss the digits and tiles reset; typed words stay so they can be corrected.
            typed = ""
            placed = []
            if attempt == 2, let ex = engine.current, ex.kind.usesAudio, store.data.autoPlayAudio {
                SpeechService.shared.speakNumber(ex.number, slow: true)
            }
        }
        .onChange(of: engine.missTicks) { _, _ in
            store.playEffect(.strike)
        }
        .onChange(of: engine.step) { _, step in
            if case .resolved(let outcome) = step { speakAnswer(outcome) }
        }
        .confirmationDialog("Leave this page?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave page", role: .destructive) { onClose() }
            Button("Keep writing", role: .cancel) {}
        } message: {
            Text("Points for this page won’t be saved. What you’ve answered so far still counts toward your progress.")
        }
    }

    private func haptic(_ kind: SensoryFeedback) -> SensoryFeedback? {
        store.data.haptics ? kind : nil
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                confirmLeave = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Leave page")

            InkProgressBar(value: engine.progress)

            ratureMeter
        }
        .padding(.leading, 22)
        .padding(.trailing, 22)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var ratureMeter: some View {
        switch engine.mode {
        case .guided:
            Text("Guided")
                .font(Typeface.hand(20, relativeTo: .callout))
                .foregroundStyle(Palette.inkMuted)
        case .test:
            Text("Test")
                .font(Typeface.hand(20, relativeTo: .callout))
                .foregroundStyle(Palette.pen)
        case .standard:
            HStack(spacing: 4) {
                ForEach(0..<LessonEngine.maxRatures, id: \.self) { i in
                    Image(systemName: i < engine.ratures ? "drop.fill" : "drop")
                        .font(.system(size: 15))
                        .foregroundStyle(i < engine.ratures ? Palette.pen : Palette.ink.opacity(0.3))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(engine.ratures) of \(LessonEngine.maxRatures) answers crossed out")
        }
    }

    // MARK: Prompt

    private func heading(for kind: ExerciseKind) -> (french: String, english: String) {
        switch kind {
        case .read: return ("Lire", "Pick the French words for this number.")
        case .decode: return ("Déchiffrer", "Which number is this?")
        case .listen: return ("Écouter", "Which number do you hear?")
        case .build: return ("Construire", "Build the number from its words.")
        case .dictation: return ("Dictée", "Type the number you hear.")
        case .write: return ("Écrire", "Type this number in French words.")
        case .transcribe: return ("Transcrire", "Type what you hear, in French words.")
        case .intro: return ("Nouveau", "A new number.")
        case .spelling: return ("Orthographe", "Writing numbers.")
        }
    }

    private func prompt(_ ex: Exercise) -> some View {
        let text = heading(for: ex.kind)
        let numeralSize: CGFloat = ex.kind == .write ? 84 : 120
        return VStack(alignment: .leading, spacing: 10) {
            Text(text.french)
                .font(Typeface.hand(28, relativeTo: .title2))
                .foregroundStyle(Palette.pen)
            Text(text.english)
                .font(Typeface.serif(.title3))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let label = engine.triesLabel {
                Text(label)
                    .font(Typeface.ui(.footnote, weight: .semibold))
                    .foregroundStyle(engine.currentTries == 1 || engine.attempt >= 2 ? Palette.pen : Palette.inkMuted)
            }

            if ex.kind == .read || ex.kind == .build || ex.kind == .write {
                Text("\(ex.number)")
                    .font(Typeface.numeral(numeralSize, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)
                    .accessibilityLabel("Number \(ex.number)")
            } else if ex.kind == .decode {
                Text(FrenchNumber.words(for: ex.number))
                    .font(Typeface.numeral(44, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .padding(.top, 4)
            } else {
                SpeakerButtons(number: ex.number)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: Exercise body

    @ViewBuilder
    private func exerciseBody(_ ex: Exercise) -> some View {
        let outcome = resolvedOutcome()
        switch ex.kind {
        case .read:
            ChoiceListView(choices: ex.choices, struck: engine.struckChoices, correct: ex.number,
                           resolved: outcome) { picked in
                engine.submit(.choice(picked))
            }
        case .listen, .decode:
            DigitGridView(choices: ex.choices, struck: engine.struckChoices, correct: ex.number,
                          resolved: outcome) { picked in
                engine.submit(.choice(picked))
            }
        case .build:
            BuildAreaView(bank: ex.bank, placed: $placed, locked: engine.step != .answering)
        case .dictation:
            DictationAreaView(typed: $typed, locked: engine.step != .answering)
        case .write, .transcribe:
            WriteAreaView(text: $written, locked: engine.step != .answering, onSubmit: submitWritten)
        case .intro, .spelling:
            EmptyView()
        }
    }

    private func resolvedOutcome() -> Outcome? {
        if case .resolved(let outcome) = engine.step { return outcome }
        return nil
    }

    private func submitWritten() {
        if !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            engine.submit(.text(written))
        }
    }

    // MARK: Teaching card

    private func introCard(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A new number")
                .font(Typeface.hand(30, relativeTo: .title2))
                .foregroundStyle(Palette.pen)
            Text("\(ex.number)")
                .font(Typeface.numeral(140, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(FrenchNumber.words(for: ex.number))
                .font(Typeface.serif(.largeTitle, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            AnatomyView(number: ex.number)
            if let tip = FrenchNumber.tip(for: ex.number) {
                Text(tip)
                    .font(Typeface.serif(.body).italic())
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if SpeechService.shared.isAvailable {
                SpeakerButtons(number: ex.number)
            }
        }
    }

    // MARK: Feedback

    @ViewBuilder
    private func feedback(_ ex: Exercise) -> some View {
        switch engine.step {
        case .answering:
            answeringFeedback
        case .resolved(let outcome):
            resolvedFeedback(ex, outcome)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var answeringFeedback: some View {
        let hint = engine.visibleHint
        let note = engine.nearMissNote
        if hint != nil || note != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let note {
                    Text("Presque !")
                        .font(Typeface.hand(28, relativeTo: .title2))
                        .foregroundStyle(Palette.pen)
                    Text(note)
                        .font(Typeface.serif(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("No penalty. Fix it and check again.")
                        .font(Typeface.ui(.footnote))
                        .foregroundStyle(Palette.inkMuted)
                }
                if let hint {
                    if engine.attempt >= 2 && note == nil {
                        Text(Remark.nearMiss[engine.missTicks % Remark.nearMiss.count])
                            .font(Typeface.hand(28, relativeTo: .title2))
                            .foregroundStyle(Palette.pen)
                        Text("No penalty. Try once more for half points.")
                            .font(Typeface.ui(.footnote))
                            .foregroundStyle(Palette.inkMuted)
                    }
                    Text(hint)
                        .font(Typeface.serif(.body, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func resolvedFeedback(_ ex: Exercise, _ outcome: Outcome) -> some View {
        let words = FrenchNumber.words(for: ex.number)
        switch outcome {
        case .first, .second:
            let remarks = outcome == .first ? Remark.praise : Remark.secondChance
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Palette.leaf)
                    Text(remarks[engine.results.count % remarks.count])
                        .font(Typeface.hand(30, relativeTo: .title2))
                        .foregroundStyle(Palette.leaf)
                    Spacer()
                    if engine.mode != .test {
                        Text("+\(engine.pointValue(for: outcome))")
                            .font(Typeface.ui(.headline, weight: .bold))
                            .foregroundStyle(Palette.leaf)
                    }
                }
                Text(correctLine(ex, words: words))
                    .font(Typeface.serif(.body))
                    .foregroundStyle(Palette.inkMuted)
            }
        case .failed:
            VStack(alignment: .leading, spacing: 12) {
                Text("La correction")
                    .font(Typeface.hand(30, relativeTo: .title2))
                    .foregroundStyle(Palette.pen)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(ex.number)")
                        .font(Typeface.numeral(48, relativeTo: .title))
                        .foregroundStyle(Palette.pen)
                    Text(words)
                        .font(Typeface.serif(.title2, weight: .semibold))
                        .foregroundStyle(Palette.pen)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)
                }
                AnatomyView(number: ex.number)
                if let tip = FrenchNumber.tip(for: ex.number) {
                    Text(tip)
                        .font(Typeface.serif(.callout).italic())
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if engine.mode == .standard {
                    Text(ratureNote)
                        .font(Typeface.ui(.footnote, weight: .semibold))
                        .foregroundStyle(Palette.pen)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func correctLine(_ ex: Exercise, words: String) -> String {
        if let recipe = FrenchNumber.anatomy(for: ex.number).recipe {
            return "\(words) is \(recipe)"
        }
        return "\(ex.number) is \(words)"
    }

    private var ratureNote: String {
        switch engine.ratures {
        case 1: return "That’s 1 answer crossed out. Three tears the page."
        case 2: return "That’s 2. One more and the page is torn."
        default: return "That’s three. The page will be torn."
        }
    }

    // MARK: Bottom bar

    private func continueTitle(_ outcome: Outcome) -> String {
        let willTear = outcome == .failed && engine.mode == .standard
            && engine.ratures >= LessonEngine.maxRatures
        if engine.isLast && !willTear {
            return engine.mode == .test ? "See my result" : "See my mark"
        }
        return "Continue"
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let ex = engine.current {
            VStack(spacing: 0) {
                switch engine.step {
                case .answering:
                    answeringButton(ex)
                case .resolved(let outcome):
                    Button {
                        engine.next()
                    } label: {
                        Text(continueTitle(outcome))
                    }
                    .buttonStyle(InkButtonStyle(kind: outcome == .failed ? .pen : .primary))
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, engine.step == .answering && (ex.kind == .read || ex.kind == .listen || ex.kind == .decode) ? 0 : 12)
            .background(Palette.paper.opacity(0.96))
        }
    }

    @ViewBuilder
    private func answeringButton(_ ex: Exercise) -> some View {
        switch ex.kind {
        case .intro, .spelling:
            Button {
                engine.acknowledgeCard()
            } label: {
                Text("Got it")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
        case .build:
            Button {
                let tokens = placed.compactMap { ex.bank.indices.contains($0) ? ex.bank[$0] : nil }
                engine.submit(.tokens(tokens))
            } label: {
                Text("Check")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .disabled(placed.isEmpty)
        case .dictation:
            Button {
                if let n = Int(typed) { engine.submit(.typed(n)) }
            } label: {
                Text("Check")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .disabled(typed.isEmpty)
        case .write, .transcribe:
            Button {
                submitWritten()
            } label: {
                Text("Check")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .disabled(written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .read, .listen, .decode:
            EmptyView()
        }
    }

    // MARK: Helpers

    private func resetDrafts() {
        typed = ""
        placed = []
        written = ""
    }

    private func autoplayPrompt() {
        guard store.data.autoPlayAudio,
              let ex = engine.current,
              ex.kind.usesAudio,
              engine.step == .answering else { return }
        SpeechService.shared.speakNumber(ex.number)
    }

    private func speakAnswer(_ outcome: Outcome) {
        guard store.data.autoPlayAudio, let ex = engine.current else { return }
        if !ex.kind.usesAudio || outcome == .failed {
            SpeechService.shared.speakNumber(ex.number)
        }
    }
}
