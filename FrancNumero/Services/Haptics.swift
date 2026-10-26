import CoreHaptics
import UIKit

/// Custom vibration patterns for the big moments.
enum HapticPattern {
    case tear        // a ripping page: fast taps that fade, over a low rumble
    case circling    // the pen circling the mark: a soft continuous swell
    case excellent   // a rising run of taps ending in a thump
    case stamp       // the date stamp landing
}

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?

    private init() {}

    private var supported: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func play(_ pattern: HapticPattern) {
        guard supported else {
            fallback(pattern)
            return
        }
        do {
            let active = try preparedEngine()
            let player = try active.makePlayer(with: Self.makePattern(pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil          // rebuilt on the next call
            fallback(pattern)
        }
    }

    private func preparedEngine() throws -> CHHapticEngine {
        let active: CHHapticEngine
        if let existing = engine {
            active = existing
        } else {
            active = try CHHapticEngine()
            active.isAutoShutdownEnabled = true
            engine = active
        }
        try active.start()
        return active
    }

    /// Plain system haptics for devices without Core Haptics.
    private func fallback(_ pattern: HapticPattern) {
        switch pattern {
        case .tear: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .excellent: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .stamp: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .circling: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    // MARK: Patterns

    private static func makePattern(_ kind: HapticPattern) throws -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        var curves: [CHHapticParameterCurve] = []

        func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time
            ))
        }

        func rumble(_ time: TimeInterval, _ duration: TimeInterval, _ intensity: Float, _ sharpness: Float) {
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: time,
                duration: duration
            ))
        }

        switch kind {
        case .tear:
            rumble(0, 0.55, 0.35, 0.2)
            let taps: [(TimeInterval, Float)] = [
                (0.00, 1.0), (0.05, 0.9), (0.10, 0.8), (0.16, 0.9),
                (0.22, 0.7), (0.30, 0.6), (0.38, 0.5), (0.47, 0.4)
            ]
            for (time, intensity) in taps { tap(time, intensity, 0.8) }

        case .circling:
            rumble(0, 0.9, 0.5, 0.15)
            curves.append(CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.0, value: 0.3),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.45, value: 1.0),
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0.9, value: 0.4)
                ],
                relativeTime: 0
            ))

        case .excellent:
            tap(0.00, 0.40, 0.5)
            tap(0.12, 0.55, 0.5)
            tap(0.24, 0.70, 0.6)
            tap(0.36, 0.85, 0.7)
            tap(0.52, 1.00, 0.9)
            rumble(0.52, 0.30, 0.6, 0.3)

        case .stamp:
            tap(0, 1.0, 0.4)
            rumble(0, 0.12, 0.5, 0.1)
        }

        return try CHHapticPattern(events: events, parameterCurves: curves)
    }
}
