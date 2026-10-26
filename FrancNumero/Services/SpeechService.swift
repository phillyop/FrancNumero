import AVFoundation

/// Speaks French numbers with the best installed French voice.
///
/// Two things the first version missed:
/// - the audio session must be `.playback`, otherwise the iPhone's silent switch mutes everything;
/// - if no French voice is installed, audio exercises have to be skipped, not read in English.
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    /// Tune the slow mode here. Rates run from 0 (slowest) to 1 (fastest); 0.5 is the voice's default.
    enum Tuning {
        static let normalRate: Float = 0.44
        /// Speed of each chunk in slow mode.
        static let slowRate: Float = 0.30
        /// Silence between chunks in slow mode, in seconds.
        static let slowPause: TimeInterval = 0.85
    }

    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?

    var isAvailable: Bool { voice != nil }

    private init() {
        let french = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("fr") }
        let best = french.max { a, b in
            let scoreA = (a.language == "fr-FR" ? 10 : 0) + a.quality.rawValue
            let scoreB = (b.language == "fr-FR" ? 10 : 0) + b.quality.rawValue
            return scoreA < scoreB
        }
        voice = best ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    func speak(_ text: String) {
        guard voice != nil else { return }
        configureSession()
        synthesizer.stopSpeaking(at: .immediate)
        enqueue(text, rate: Tuning.normalRate, pauseAfter: 0)
    }

    /// Normal speed says the whole number. Slow speed says it in chunks with a pause between,
    /// e.g. "quatre-vingt … dix-sept". Chunks follow the number's own joints (see
    /// `FrenchNumber.speechSegments`), so liaisons like dix-huit are never broken.
    func speakNumber(_ n: Int, slow: Bool = false) {
        guard voice != nil else { return }
        configureSession()
        synthesizer.stopSpeaking(at: .immediate)

        guard slow else {
            enqueue(FrenchNumber.words(for: n), rate: Tuning.normalRate, pauseAfter: 0)
            return
        }
        let parts = FrenchNumber.speechSegments(for: n)
        for (i, part) in parts.enumerated() {
            let isLast = i == parts.count - 1
            enqueue(part, rate: Tuning.slowRate, pauseAfter: isLast ? 0 : Tuning.slowPause)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func enqueue(_ text: String, rate: Float, pauseAfter: TimeInterval) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = pauseAfter
        synthesizer.speak(utterance)
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Speech still works with the default session; it just respects the silent switch.
        }
    }
}
