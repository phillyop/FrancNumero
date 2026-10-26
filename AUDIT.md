# Audit of the ChatGPT version

What was wrong, what was missing, and what was done about it. Everything under
"Wrong" was checked against the files you uploaded.

## 1. Why it would not open in Xcode

| # | Problem | Evidence |
|---|---------|----------|
| 1 | **Two objects share one ID.** `E10000000000000000000001` is used for both the project object and the project's build-configuration list. `rootObject` points at that ID, so Xcode cannot tell what the root is and reports the project as damaged. | Parsed `project.pbxproj`. This is the blocking error. |
| 2 | `productRefGroup` points at the main group. There is no Products group. | `productRefGroup == mainGroup` |
| 3 | Project-level and target-level build settings are swapped. No `SDKROOT` anywhere. | Read the configs. |
| 4 | Asks for an `AppIcon` but ships no asset catalog. | `ASSETCATALOG_COMPILER_APPICON_NAME` set, no `.xcassets` in the project. |
| 5 | Placeholder bundle ID (`com.example…`) and no development team, so it can't run on a real iPhone. | Build settings. |

## 2. Problems in your `FrancNumero` project

| # | Problem | Fix |
|---|---------|-----|
| 1 | The zip contained only the `.xcodeproj`. No source folder, so the project was an empty shell. | Delivered a full project, including the `FrancNumero/` source folder. |
| 2 | iOS deployment target was **27.0**. The app would only install on devices already on the newest OS. | Lowered to **17.0**. |
| 3 | Targeted iPhone, iPad, Mac and Vision Pro, with macOS sandbox settings. The code uses iOS-only APIs. | iPhone-only, portrait. |
| 4 | Leftover template name `MyApp` as `productName`. | Now `FrancNumero`. |
| 5 | Strict-concurrency defaults (`MainActor` isolation, member-import visibility) are a common source of confusing errors in code written for general Xcode versions. | Removed. Language mode stays Swift 5. |
| 6 | No app icon, no accent colour, no display name. | Added. |

Your **team ID, bundle ID and file format were kept exactly as they were.**

## 3. Bugs in the ChatGPT code

1. **Wrong days in the weekly view.** It formats days with `.iso8601`, which defaults to UTC, while the streak logic uses local days. Anyone not on UTC would see ticks on the wrong days.
2. **"Missed numbers" were never saved.** `missed` was a local `@State` array. The results screen promised "A short review tomorrow will help them stick", but nothing was stored or reviewed.
3. **Audio was muted by the silent switch.** No `AVAudioSession` was configured. And if no French voice is installed, French text would have been read with an English voice.
4. **Reminders nagged you after you'd practised.** One repeating notification fired every day regardless.
5. **Points could be farmed.** "Practise again" paid full points, unlimited times.
6. **Wrong answers were random.** Distractors were "answer ± 12", which teaches nothing. Real learners confuse 16/60, 17/71, 77/97.
7. **Accessibility.** 54 fixed-size fonts (down to 8 pt), so Dynamic Type was ignored. Forced light mode. No VoiceOver labels.
8. **Dead code.** One branch of the result text could never run.

## 4. What the brief asked for and the first version skipped

| Your brief | ChatGPT version | This version |
|------------|-----------------|--------------|
| Different from anything on the market | Cream background, coral accent, rounded white cards. The standard template. | A French **school exercise book**: Seyès grid paper, ink-blue Didot numerals, a teacher's red pen, marks out of 20, `gommette` stickers, `bons points`. Dark mode is a chalkboard. |
| Reward correct points | +10 per answer, nothing more. | Bons points, a mark out of 20 with a teacher's remark, school levels (CP → Terminale), 15 gommettes, a dated "Vu" stamp. |
| Chance to retry, penalise consistent wrongs, "maybe a session reset… something innovative" | Retry once. Wrong twice cost −2 points. No reset. | **Ratures and the torn page** (see README). First miss is free with a hint. Second miss crosses the answer out in red pen. Three ratures tear the page, you lose its points, read a correction and restart. After two torn pages in a day, pages go **gentle** so you can always keep your streak. |
| Log a lesson every day to keep a streak | Streak counted. | Streak plus **mots d'excuse**: earn one every 7 days, it covers one missed day. Streak shown as a bookmark ribbon, not a flame. |
| Notifications | One repeating reminder. | Rolling 2-week schedule, skips today once done, a last call at 21:00 if a run is at risk, seven rotating messages, permission handling. |
| Effective, consistent learning | Quiz only. Never explained the rules. | **Teaches first**: every new number gets a card with its anatomy (77 = 60 + 17), then it is tested. **Adaptive**: weak and overdue numbers come back first (spaced repetition). **Chapters** with the rule for each. **Five exercise types**. Smart wrong answers. |
| Augment Duolingo, not replace it | n/a | Phase 1 only covers 0–100, the part most courses rush. Roadmap for dates, time, money and years is in the Cahier tab. |
