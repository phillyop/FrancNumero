# FrancNumero: Phase 1, counting 0 to 100

A daily French-numbers trainer built as a school exercise book. It is meant to sit
beside Duolingo or any course, and cover the part they rush.

## Open it

1. Unzip, then double-click **`FrancNumero.xcodeproj`**.
2. Pick an **iPhone simulator** (or your phone) and press **Run (⌘R)**.
3. First time on a real iPhone: Xcode → *FrancNumero target → Signing & Capabilities*. Your team is already set.

Open it with the same Xcode you used to create FrancNumero (the project file is in that Xcode's format). The app runs on iOS 17 or later, iPhone only.

**If you'd rather keep your existing project:** quit Xcode, then replace your `FrancNumero/`
source folder with the one in this zip. Delete any template `ContentView.swift` or old
`FrancNumeroApp.swift` first, or you'll get two `@main` entries. The project uses a
synchronized folder, so every file in `FrancNumero/` is included automatically.

**If the build reports errors:** this code was written and checked without an Xcode install
(see "What was and wasn't verified" below). Copy the first red error into a chat with me and it
is usually a one-line fix.

## How a page works

Every question has a number of **tries**, shown on screen ("Two tries", "Last try", "One try"):

| Question | Tries |
|----------|-------|
| Typed or built answers | Always 2 |
| Multiple choice, number new or shaky | 2 |
| Multiple choice, number solid | 1 |
| Guided pages (below) | 2 everywhere |
| Chapter test-out | 1 everywhere |

| You do | What happens |
|--------|--------------|
| Answer right | **+10** points. |
| Miss with a try left | **No penalty.** A hint appears, the wrong choice is struck out, you try again for **+5**. |
| Miss on your last try | The answer is **crossed out in red pen** (a *rature*), the correction is shown, 0 points. |
| A typo or missing accent in a typed answer | A **near miss**: free, and it doesn't use a try. |
| Three ratures | **The page is torn.** Points from that page are lost. You read the correction, then start a **clean page** where those numbers come first. |
| Two torn pages in a day | Pages turn **gentle**: two tries everywhere, hints up front, no tearing, half points. |

The progress bar fills as you finish questions and is full on your last answer, just before the mark.
The score is a school mark out of 20 (two marks for a clean answer, one after a hint), with a teacher's
remark. Today's first page earns full points; extra pages earn half, so replaying can't be farmed.

**Skipping ahead.** Chapters open as you learn. If you already know one, open it on the Tableau and
**test out**: ten questions, one try each, eight right opens the next chapter (one attempt a day).
"Unlock all chapters" appears in Settings only from level CM2.

**Sound and touch.** The pen strikes, circles your mark, the page tears and the stamp lands, each with
a sound and vibration. Both can be switched off in Settings. Sound effects respect the silent switch.

## The exercise types

- **Lire**: see digits, pick the French words.
- **Déchiffrer**: see French words, pick the digits.
- **Écouter**: hear it, pick the digits.
- **Construire**: assemble the French from word tiles (this is where the base-20 logic clicks).
- **Dictée**: hear it, type the digits on an in-app keypad.
- **Écrire**: see digits, type the French words.
- **Transcrire**: hear it, type the French words.

New numbers always get a **teaching card** first. It shows the anatomy (*soixante-dix-sept = 60 + 17*) and the rule.
Typed-in-words exercises (at most two a page, only for numbers you already know) are preceded once by a
**spelling rules card**. Wrong answers are the confusions real learners make: 16/60, 17/71, 77/97, 77/67.

## Project layout

```
FrancNumero/
├── FrancNumero.xcodeproj
├── FrancNumero/                  (everything in here is compiled automatically)
│   ├── FrancNumeroApp.swift
│   ├── Models/    FrenchNumber · Curriculum · Exercise · LessonEngine · Streak · Rewards
│   ├── Store/     AppData · AppStore
│   ├── Services/  SpeechService · NotificationManager · SoundEffects · Haptics
│   ├── Design/    Theme · PaperBackground · Components
│   ├── Views/     Home · Lesson · Tableau · Cahier · Onboarding
│   ├── Sounds/                    (four synthesised effects)
│   └── Assets.xcassets            (adaptive colours, app icon)
├── FrancNumeroTests/              (optional unit tests, see the file header)
├── Tools/make_sounds.py           regenerates the sound effects (needs numpy and scipy)
├── CHANGELOG.md                   what changed in round 2
├── AUDIT.md                       what was wrong and what changed
└── README.md
```

All game rules live in `Models/` and contain no UI. `LessonEngine` is a plain value type, so
the retry, rature, torn-page and grading rules can be tested without launching the app.

## What was and wasn't verified

I had no Xcode or Swift compiler in my environment, so **the app has not been built by me**. (You built
and ran round 1 successfully, which confirms the project file and the approach.) What was checked this round:

- `project.pbxproj` unchanged since round 1; the new sounds sit in the synchronized folder, so nothing needed registering.
- All 26 Swift files parse with a Swift grammar; every `Type.member` reference resolves; every colour and sound name exists; every `switch` over the exercise kinds is exhaustive.
- The game rules were ported to Python and run through scenario and property tests: all 10,201 typed-answer pairs
  (a different real number is never forgiven as a typo), slow-speech chunking for 0 to 100, the tries rules, near-miss
  handling, the progress bar (empty at the start, full on the last answer, never backwards), the session builder
  (typed-words limits, spelling card placement), the test-out in every chapter (a pass always clears it) and simulated
  learners at 60%, 80% and 95% accuracy.
- The sounds were checked numerically (levels, no clipping, no clicks at the edges, small-speaker energy) and by spectrogram.

**What I could not check:** type errors that only the compiler sees, and **how anything sounds or feels**. I can't hear the
sounds or feel the vibrations, and the simulator has no haptics, so test those on a real iPhone. If a sound is off, the
knobs are in `Tools/make_sounds.py`, and the slow-speech rate and pause are in `SpeechService.Tuning`.

## Roadmap (already shown on the Cahier tab)

Phase 2 dates and days · Phase 3 telling the time · Phase 4 money and years (1789, 2026) ·
Phase 5 phone numbers, addresses and real-life scenes. Speaking practice (speech recognition) is a good
candidate once the listening side is proven.
