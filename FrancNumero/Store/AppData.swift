import Foundation

struct ReminderSettings: Codable, Equatable {
    var enabled = false
    var hour = 19
    var minute = 0
}

/// One finished (or torn) page in the learner's cahier.
struct SessionLog: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: String
    var grade: Int
    var points: Int
    var torn: Bool
    var guided: Bool
}

/// Everything the app saves. Decoding tolerates missing keys so future
/// versions can add fields without wiping a learner's progress.
struct AppData: Codable, Equatable {
    var version = 1
    var hasOnboarded = false
    var points = 0
    var records: [MasteryRecord] = Array(repeating: MasteryRecord(), count: 101)
    var unlockedCount = 1
    var streak = StreakState()
    var completedDays: [String] = []
    var excusedDays: [String] = []
    var sessions: [SessionLog] = []
    var gommettes: [String: String] = [:]
    var tornDay = ""
    var tornCount = 0
    var reminder = ReminderSettings()
    var autoPlayAudio = true
    var soundEffects = true
    var haptics = true
    var hasSeenSpellingRules = false
    /// Chapter id -> the day of its last test-out attempt (one attempt per day).
    var testOutDay: [String: String] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, hasOnboarded, points, records, unlockedCount, streak
        case completedDays, excusedDays, sessions, gommettes, tornDay, tornCount
        case reminder, autoPlayAudio, soundEffects, haptics, hasSeenSpellingRules, testOutDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        hasOnboarded = try c.decodeIfPresent(Bool.self, forKey: .hasOnboarded) ?? false
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        records = try c.decodeIfPresent([MasteryRecord].self, forKey: .records) ?? []
        unlockedCount = try c.decodeIfPresent(Int.self, forKey: .unlockedCount) ?? 1
        streak = try c.decodeIfPresent(StreakState.self, forKey: .streak) ?? StreakState()
        completedDays = try c.decodeIfPresent([String].self, forKey: .completedDays) ?? []
        excusedDays = try c.decodeIfPresent([String].self, forKey: .excusedDays) ?? []
        sessions = try c.decodeIfPresent([SessionLog].self, forKey: .sessions) ?? []
        gommettes = try c.decodeIfPresent([String: String].self, forKey: .gommettes) ?? [:]
        tornDay = try c.decodeIfPresent(String.self, forKey: .tornDay) ?? ""
        tornCount = try c.decodeIfPresent(Int.self, forKey: .tornCount) ?? 0
        reminder = try c.decodeIfPresent(ReminderSettings.self, forKey: .reminder) ?? ReminderSettings()
        autoPlayAudio = try c.decodeIfPresent(Bool.self, forKey: .autoPlayAudio) ?? true
        soundEffects = try c.decodeIfPresent(Bool.self, forKey: .soundEffects) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        hasSeenSpellingRules = try c.decodeIfPresent(Bool.self, forKey: .hasSeenSpellingRules) ?? false
        testOutDay = try c.decodeIfPresent([String: String].self, forKey: .testOutDay) ?? [:]

        // Keep the invariants the rest of the app relies on.
        if records.count < 101 {
            records += Array(repeating: MasteryRecord(), count: 101 - records.count)
        } else if records.count > 101 {
            records = Array(records.prefix(101))
        }
        unlockedCount = min(max(1, unlockedCount), Curriculum.chapters.count)
    }
}
