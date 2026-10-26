import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var reminderOn = false
    @State private var reminderTime = Date()
    @State private var notificationsDenied = false
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                audioSection
                learningSection
                rulesSection
                glossarySection
                resetSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: load)
            .task { await refreshAuthorization() }
            .confirmationDialog("Reset all progress?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    store.resetEverything()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your points, streak, marks, stickers and what the app knows about each number. It can’t be undone.")
            }
        }
        .tint(Palette.ink)
    }

    // MARK: Sections

    private var reminderSection: some View {
        Section {
            Toggle("Remind me every day", isOn: Binding(
                get: { reminderOn },
                set: { setReminder($0) }
            ))
            DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                .disabled(!reminderOn)
                .onChange(of: reminderTime) { _, newValue in
                    applyTimeChange(newValue)
                }
            if notificationsDenied {
                Text("Notifications are turned off for FrancNumero in iOS.")
                    .font(.footnote)
                    .foregroundStyle(Palette.pen)
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        } header: {
            Text("Daily reminder")
        } footer: {
            Text("Reminders skip a day once you’ve written its page. If you have a run going, you also get a last call at 21:00.")
        }
    }

    private var audioSection: some View {
        Section {
            Toggle("Play audio automatically", isOn: Binding(
                get: { store.data.autoPlayAudio },
                set: { store.setAutoPlay($0) }
            ))
            Toggle("Sound effects", isOn: Binding(
                get: { store.data.soundEffects },
                set: { store.setSoundEffects($0) }
            ))
            Toggle("Vibration", isOn: Binding(
                get: { store.data.haptics },
                set: { store.setHaptics($0) }
            ))
            LabeledContent("French voice", value: SpeechService.shared.isAvailable ? "Installed" : "Not installed")
        } header: {
            Text("Sound and touch")
        } footer: {
            if SpeechService.shared.isAvailable {
                Text("Sound effects follow your iPhone’s silent switch. The spoken French does not. For a more natural voice, download an Enhanced French voice in Settings, Accessibility, Spoken Content, Voices.")
            } else {
                Text("Without a French voice, listening exercises are skipped. Add one in Settings, Accessibility, Spoken Content, Voices, French.")
            }
        }
    }

    private var learningSection: some View {
        Section {
            if store.canUnlockAll {
                Button("Unlock all chapters") {
                    store.unlockAllChapters()
                }
                .disabled(store.data.unlockedCount >= Curriculum.chapters.count)
            } else {
                Text("Skipping ahead opens at \(Levels.unlockAllLevel.code) (\(Levels.unlockAllLevel.threshold) bons points). Until then, chapters open as you learn. Already know a chapter? Open it on the Tableau and test out of it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Learning")
        } footer: {
            if store.canUnlockAll {
                Text("Opens every chapter at once. Test-outs on the Tableau are still the safer way to skip a chapter you know.")
            }
        }
    }

    private var rulesSection: some View {
        Section("How a page works") {
            rule("Tries", "New and shaky numbers get two tries on every question. Numbers you know well get one try on multiple choice. Typed and built answers always get two.")
            rule("Wrong on a two-try question", "No penalty. You get a hint and a second try for half points.")
            rule("Out of tries", "Your answer is crossed out in red pen. That’s one rature.")
            rule("Near misses", "A missing accent or a one-letter slip in a typed answer costs nothing.")
            rule("Three ratures", "The page is torn and its points are lost. Read the correction, then start a clean page.")
            rule("Two torn pages in a day", "Pages turn gentle: two tries everywhere, hints up front, no tearing, half points. You can always keep your run.")
            rule("Bonus pages", "After today’s page, extra pages earn half points.")
        }
    }

    private var glossarySection: some View {
        Section("Words from the classroom") {
            rule("Bons points", "“Good points”. The reward teachers give. Yours add up to a school level.")
            rule("Gommettes", "The round stickers teachers hand out.")
            rule("Mot d’excuse", "A note from home. Here it covers one missed day.")
            rule("Rature", "A crossing-out.")
            rule("Cahier", "Exercise book.")
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset all progress", role: .destructive) {
                showReset = true
            }
        }
    }

    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    private func load() {
        let r = store.data.reminder
        reminderOn = r.enabled
        reminderTime = Calendar.current.date(from: DateComponents(hour: r.hour, minute: r.minute)) ?? Date()
    }

    private func refreshAuthorization() async {
        notificationsDenied = await NotificationManager.authorizationStatus() == .denied
    }

    private func setReminder(_ on: Bool) {
        reminderOn = on
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        Task { @MainActor in
            let result = await store.setReminder(enabled: on, hour: parts.hour ?? 19, minute: parts.minute ?? 0)
            if result == .denied {
                reminderOn = false
                notificationsDenied = true
            } else {
                notificationsDenied = false
            }
        }
    }

    private func applyTimeChange(_ date: Date) {
        guard reminderOn else { return }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let stored = store.data.reminder
        if parts.hour == stored.hour && parts.minute == stored.minute { return }
        Task { @MainActor in
            _ = await store.setReminder(enabled: true, hour: parts.hour ?? 19, minute: parts.minute ?? 0)
        }
    }
}
