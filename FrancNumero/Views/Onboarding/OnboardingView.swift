import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    @State private var step = 0
    @State private var startIndex = 0
    @State private var reminderOn = true
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 19, minute: 0)) ?? Date()
    @State private var busy = false

    private let lastStep = 3

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(alignment: .leading, spacing: 0) {
                InkProgressBar(value: Double(step + 1) / Double(lastStep + 1))
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                    .padding(.leading, Metrics.pagePadding)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        switch step {
                        case 0: hook
                        case 1: howItWorks
                        case 2: level
                        default: reminder
                        }
                    }
                    .padding(.leading, Metrics.pagePadding)
                    .padding(.trailing, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                footer
            }
        }
    }

    // MARK: Steps

    private var hook: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bienvenue")
                .font(Typeface.hand(32, relativeTo: .title))
                .foregroundStyle(Palette.pen)
            Text("99")
                .font(Typeface.numeral(120, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Text("quatre-vingt-dix-neuf")
                .font(Typeface.serif(.title, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("4 × 20 + 19")
                .font(Typeface.numeral(30, relativeTo: .title2))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.marker.opacity(0.6), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("French counts in a way that surprises everyone.")
                .font(Typeface.serif(.title2, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            Text("Language apps teach you words. FrancNumero trains the numbers they skip: one page a day, written in your own cahier.")
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How a page works")
                .font(Typeface.numeral(38, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            point("Two tries", "On new or shaky numbers, a first miss is free. You get a hint and a second try for half points. Numbers you know well get one try on multiple choice.")
            point("Out of tries?", "Your answer is crossed out in red pen and the correction appears. That’s one rature.")
            point("Three ratures?", "The page is torn and its points are lost. You read the correction, then start again on a clean page.")
            point("Never stuck", "After two torn pages in a day, pages turn gentle: hints up front and no tearing. You can always keep your run.")
        }
    }

    private func point(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typeface.hand(26, relativeTo: .title3))
                .foregroundStyle(Palette.pen)
            Text(detail)
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var level: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Where are you starting?")
                .font(Typeface.numeral(38, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Text("Pick the closest. The app adjusts as you go, and checks the numbers you skip.")
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                Hairline()
                ForEach(Curriculum.startOptions) { option in
                    Button {
                        startIndex = option.id
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .strokeBorder(Palette.ink, lineWidth: 1.5)
                                .background(Circle().fill(startIndex == option.id ? Palette.ink : Color.clear).padding(5))
                                .frame(width: 26, height: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(Typeface.serif(.title3, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text(option.detail)
                                    .font(Typeface.ui(.footnote))
                                    .foregroundStyle(Palette.inkMuted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(startIndex == option.id ? .isSelected : [])
                    Hairline()
                }
            }
        }
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A nudge each day?")
                .font(Typeface.numeral(38, relativeTo: .largeTitle))
                .foregroundStyle(Palette.ink)
            Text("A run only works if you show up. Pick a time and FrancNumero will remind you. It skips days you’ve already written.")
                .font(Typeface.serif(.body))
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                Hairline()
                Toggle("Remind me every day", isOn: $reminderOn)
                    .font(Typeface.ui(.body, weight: .medium))
                    .tint(Palette.ink)
                    .padding(.vertical, 12)
                Hairline()
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .font(Typeface.ui(.body, weight: .medium))
                    .disabled(!reminderOn)
                    .opacity(reminderOn ? 1 : 0.4)
                    .padding(.vertical, 8)
                Hairline()
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Button {
                advance()
            } label: {
                Text(step == lastStep ? "Open my cahier" : "Continue")
            }
            .buttonStyle(InkButtonStyle(kind: .primary))
            .disabled(busy)

            if step > 0 {
                Button {
                    step -= 1
                } label: {
                    Text("Back")
                        .font(Typeface.ui(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.inkMuted)
                        .frame(minHeight: 44)
                }
                .disabled(busy)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .padding(.top, 8)
    }

    private func advance() {
        if step < lastStep {
            withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
            return
        }
        busy = true
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let wantsReminder = reminderOn
        let chosenStart = startIndex
        Task { @MainActor in
            if wantsReminder {
                _ = await store.setReminder(enabled: true, hour: parts.hour ?? 19, minute: parts.minute ?? 0)
            }
            store.completeOnboarding(startIndex: chosenStart)
            busy = false
        }
    }
}
