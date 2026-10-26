import AudioToolbox
import Foundation

/// The notebook's sound effects. The files are synthesised (see Tools/make_sounds.py).
enum SoundEffect: String {
    case strike = "pen_strike"   // red pen striking an answer out
    case circle = "pen_circle"   // red pen circling the final mark
    case tear = "page_tear"      // the page tearing
    case stamp = "stamp"         // the date stamp landing
}

/// Plays short effects as system sounds. iOS mutes these when the Ring/Silent switch is on,
/// which is what people expect from interface sounds. (Spoken French deliberately ignores the switch.)
@MainActor
final class SoundEffects {
    static let shared = SoundEffects()

    private var ids: [SoundEffect: SystemSoundID] = [:]

    private init() {}

    func play(_ effect: SoundEffect) {
        if let id = ids[effect] {
            AudioServicesPlaySystemSound(id)
            return
        }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else { return }
        var id: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &id)
        guard status == kAudioServicesNoError else { return }
        ids[effect] = id
        AudioServicesPlaySystemSound(id)
    }
}
