import SwiftUI

// MARK: - Read: pick the French words (rows on ruled lines)

struct ChoiceListView: View {
    let choices: [Choice]
    let struck: Set<Int>
    let correct: Int
    let resolved: Outcome?
    let onPick: (Int) -> Void

    private let letters = ["A", "B", "C", "D", "E", "F"]

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                Button {
                    onPick(choice.number)
                } label: {
                    row(index: index, choice: choice)
                }
                .buttonStyle(.plain)
                .disabled(resolved != nil || struck.contains(choice.number))
                .accessibilityLabel(struck.contains(choice.number) ? "\(choice.label), crossed out" : choice.label)
                Hairline()
            }
        }
    }

    private func row(index: Int, choice: Choice) -> some View {
        let isStruck = struck.contains(choice.number)
        let isRight = resolved != nil && choice.number == correct
        let circledByTeacher = resolved == .failed && isRight
        let tickedGreen = (resolved == .first || resolved == .second) && isRight

        return HStack(spacing: 14) {
            Text(letters[min(index, letters.count - 1)])
                .font(Typeface.ui(.footnote, weight: .bold))
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(Palette.ink.opacity(0.35), lineWidth: 1.2))
            Text(choice.label)
                .font(Typeface.serif(.title3, weight: .medium))
                .foregroundStyle(isStruck ? Palette.inkMuted : (tickedGreen ? Palette.leaf : Palette.ink))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            if tickedGreen {
                Image(systemName: "checkmark")
                    .font(.body.weight(.heavy))
                    .foregroundStyle(Palette.leaf)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .frame(minHeight: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Palette.pen, lineWidth: 2)
                .opacity(circledByTeacher ? 1 : 0)
        )
        .overlay(
            Rectangle()
                .fill(Palette.pen)
                .frame(height: 3)
                .rotationEffect(.degrees(-1.5))
                .scaleEffect(x: isStruck ? 1 : 0, y: 1, anchor: .leading)
                .animation(.easeOut(duration: 0.3), value: isStruck)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Listen: pick the digits

struct DigitGridView: View {
    let choices: [Choice]
    let struck: Set<Int>
    let correct: Int
    let resolved: Outcome?
    let onPick: (Int) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(choices) { choice in
                tile(choice)
            }
        }
    }

    private func tile(_ choice: Choice) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
        let isStruck = struck.contains(choice.number)
        let isRight = resolved != nil && choice.number == correct
        let circled = resolved == .failed && isRight
        let ticked = (resolved == .first || resolved == .second) && isRight

        return Button {
            onPick(choice.number)
        } label: {
            Text(choice.label)
                .font(Typeface.numeral(48, relativeTo: .largeTitle))
                .foregroundStyle(isStruck ? Palette.inkMuted : (ticked ? Palette.leaf : Palette.ink))
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Palette.surface, in: shape)
                .overlay(
                    shape.strokeBorder(
                        circled ? Palette.pen : (ticked ? Palette.leaf : Palette.ink.opacity(0.3)),
                        lineWidth: (circled || ticked) ? 3 : 1.5
                    )
                )
                .overlay(
                    Rectangle()
                        .fill(Palette.pen)
                        .frame(height: 3)
                        .rotationEffect(.degrees(-24))
                        .padding(.horizontal, 12)
                        .scaleEffect(x: isStruck ? 1 : 0, y: 1, anchor: .leading)
                        .animation(.easeOut(duration: 0.3), value: isStruck)
                )
        }
        .buttonStyle(.plain)
        .disabled(resolved != nil || isStruck)
        .accessibilityLabel(isStruck ? "\(choice.label), crossed out" : choice.label)
    }
}

// MARK: - Build: assemble the French from word tiles

struct BuildAreaView: View {
    let bank: [String]
    @Binding var placed: [Int]
    let locked: Bool

    private var builtText: String {
        FrenchNumber.join(placed.compactMap { bank.indices.contains($0) ? bank[$0] : nil })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(builtText.isEmpty ? " " : builtText)
                    .font(Typeface.numeral(32, relativeTo: .title))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottomLeading)
                Rectangle()
                    .fill(Palette.ink.opacity(0.5))
                    .frame(height: 1.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(builtText.isEmpty ? "Your answer is empty" : "Your answer: \(builtText)")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(Array(bank.enumerated()), id: \.offset) { index, token in
                    let used = placed.contains(index)
                    Button {
                        if !used && !locked { placed.append(index) }
                    } label: {
                        Text(token)
                            .font(Typeface.serif(.title3, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Palette.ink.opacity(0.3), lineWidth: 1.5)
                            )
                            .opacity(used ? 0.25 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(used || locked)
                    .accessibilityLabel(token)
                }
            }

            Button {
                if !placed.isEmpty { placed.removeLast() }
            } label: {
                Label("Undo", systemImage: "delete.left")
                    .font(Typeface.ui(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(minHeight: 44)
            }
            .disabled(placed.isEmpty || locked)
            .opacity(placed.isEmpty ? 0.4 : 1)
        }
    }
}

// MARK: - Dictation: type the digits on an in-app keypad

struct DictationAreaView: View {
    @Binding var typed: String
    let locked: Bool

    private let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["⌫", "0", ""]]

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(typed.isEmpty ? " " : typed)
                    .font(Typeface.numeral(72, relativeTo: .largeTitle))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 84)
                    .minimumScaleFactor(0.5)
                Rectangle()
                    .fill(Palette.ink.opacity(0.5))
                    .frame(height: 1.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(typed.isEmpty ? "Nothing typed yet" : "Typed \(typed)")

            VStack(spacing: 10) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            keyView(key)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyView(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: 56)
        } else {
            Button {
                press(key)
            } label: {
                Group {
                    if key == "⌫" {
                        Image(systemName: "delete.left")
                            .font(.title3.weight(.semibold))
                    } else {
                        Text(key)
                            .font(Typeface.numeral(30, relativeTo: .title))
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Palette.ink.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel(key == "⌫" ? "Delete" : key)
        }
    }

    private func press(_ key: String) {
        if key == "⌫" {
            if !typed.isEmpty { typed.removeLast() }
        } else if typed == "0" {
            typed = key
        } else if typed.count < 3 {
            typed += key
        }
    }
}

// MARK: - Write: type the French words

struct WriteAreaView: View {
    @Binding var text: String
    let locked: Bool
    var onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Type it in French", text: $text)
                .font(Typeface.serif(.title, weight: .medium))
                .foregroundStyle(Palette.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .disabled(locked)
                .onSubmit {
                    if !locked { onSubmit() }
                }
                .padding(.vertical, 10)
                .accessibilityLabel("Your answer in French")
            Rectangle()
                .fill(Palette.ink.opacity(0.5))
                .frame(height: 1.5)
            Text("Hyphens or spaces both work. Hold a letter to see accents.")
                .font(Typeface.ui(.footnote))
                .foregroundStyle(Palette.inkMuted)
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                focused = true
            }
        }
    }
}

// MARK: - Spelling rules card (shown once)

struct SpellingCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Writing numbers")
                .font(Typeface.hand(32, relativeTo: .title))
                .foregroundStyle(Palette.pen)
            Text("Five things to know before you type them.")
                .font(Typeface.serif(.title3))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Hairline()
            ForEach(FrenchNumber.spellingRules, id: \.title) { rule in
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.title)
                        .font(Typeface.serif(.headline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Text(rule.detail)
                        .font(Typeface.serif(.body))
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Hairline()
            }
        }
    }
}
