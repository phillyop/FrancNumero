# Changelog

## Round 2: your feedback

| # | You asked for | What changed | Where to tune it |
|---|---------------|--------------|------------------|
| 5 | Take "unlock all" away from beginners | Hidden until level **CM2** (1,400 bons points). Until then Settings explains why. Added a **chapter test-out** instead (below). | `Levels.unlockAllLevel` |
| 6 | Progress bar fills before the marks | The bar now counts *finished* questions, so it is empty at the start and **reaches 100% on the last answer**. The last button reads **"See my mark"**. The fill is animated. | `LessonEngine.progress` |
| 4 | Slower sound, with breaks | Slow mode speaks in chunks with a **0.85 s pause** at the number's natural joints (*soixante … dix-sept*, *quatre-vingt … onze*) at a slower rate. Numbers up to 29 and *dix-huit / dix-neuf* stay whole so liaisons aren't broken. | `SpeechService.Tuning` |
| 2 | Know which questions get two tries and which one | **Per question.** Typed and built answers always get two. Multiple choice gets two while a number is new or shaky and **one once it is solid**. Guided pages always give two. Tests give one. A small label shows "Two tries", "Last try" or "One try". | `SessionBuilder.tries` |
| 1 | Teach writing numbers in words | Two new exercises: **Écrire** (see digits, type the words) and **Transcrire** (hear it, type the words). At most two per page, only for numbers you already know. A one-time **spelling rules card** appears right before the first one. Every chapter has a **"Writing it"** note. Accent slips and one-letter typos are **near misses**: free, and they don't use a try. A different real number (*dix* for *six*) is never forgiven. | `FrenchNumber.judge` |
| 7 | Sounds and vibration | Four synthesised sounds: pen **strike**, pen **circling the mark**, page **tear**, stamp **thump**. Custom vibration patterns for the **torn page** and for **excellent marks (18 and up)**. Settings toggles for both. | `Tools/make_sounds.py`, `Haptics.swift` |
| n/a | Both unlock options for #5 | **Test-out**: on any unlocked chapter you haven't cleared, take ten questions, one try each. Eight right opens the next chapter. One attempt a day, no penalty, no points, no streak. | `SessionBuilder.testPassMark` |

### Details worth knowing

- **Strikes stay worth one.** The tries rule changes how many chances a question has, not how heavy a strike is. A one-try miss is a rature immediately.
- **Sounds follow the silent switch.** Sound effects are played as system sounds, so iOS mutes them on silent. Spoken French deliberately ignores the switch.
- **Test-out and the teens.** The teens chapter has nine numbers, so its test repeats one in another format. Every test has ten questions.
- **A pass always clears the chapter.** Numbers the test didn't contradict count as known (they still return in reviews), so passing can never leave a chapter stuck just under the clearing threshold.
- **Not built yet:** lighting up the anatomy chips as each part is spoken in slow mode, and the large-number chapters (#3, parked).
