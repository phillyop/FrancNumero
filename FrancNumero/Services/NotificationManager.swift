import Foundation
import UserNotifications

/// Local reminders.
///
/// Instead of one repeating notification (which nags you even after you've done your page),
/// this keeps the next two weeks scheduled and rebuilds them whenever the app opens or a page
/// is finished. Today's reminder is dropped once today's page is done, and a "streak guard"
/// is added for tonight when a run is on the line.
enum NotificationManager {
    private static let prefix = "fn."

    private static let messages: [(String, String)] = [
        ("Your page is waiting", "Three minutes of French numbers. Keep your run going."),
        ("Quatre-vingt-dix-neuf problems?", "Numbers shouldn’t be one. One quick page."),
        ("Vite, vite, vite !", "Today’s page takes less time than a coffee."),
        ("Ready to write?", "Today’s numbers are ready, and so are you."),
        ("Un, deux, trois… go !", "Open your cahier and write today’s page."),
        ("Small steps count", "One page now keeps your ear sharp."),
        ("Allô ? C’est le cahier.", "Your numbers miss you. One quick page?")
    ]

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks once if needed. Returns whether notifications are allowed afterwards.
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus()
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ?? false
        }
    }

    static func refresh(enabled: Bool, hour: Int, minute: Int, streak: Int, doneToday: Bool) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        if !ours.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ours) }

        guard enabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let calendar = Calendar.current
        let now = Date()

        for offset in 0..<14 {
            if offset == 0 && doneToday { continue }
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = hour
            parts.minute = minute
            guard let fire = calendar.date(from: parts), fire > now else { continue }

            let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? offset
            let message = messages[ordinal % messages.count]
            let content = UNMutableNotificationContent()
            content.title = message.0
            content.body = message.1
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + "daily.\(offset)", content: content, trigger: trigger)
            try? await center.add(request)
        }

        // Streak guard: a last call tonight if a run of 2+ days is at risk.
        if !doneToday && streak >= 2 && hour < 21 {
            var tonight = calendar.dateComponents([.year, .month, .day], from: now)
            tonight.hour = 21
            tonight.minute = 0
            if let fire = calendar.date(from: tonight), fire > now {
                let content = UNMutableNotificationContent()
                content.title = "Your \(streak)-day run ends tonight"
                content.body = "One page before midnight keeps it going."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: tonight, repeats: false)
                let request = UNNotificationRequest(identifier: prefix + "guard", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }
}
