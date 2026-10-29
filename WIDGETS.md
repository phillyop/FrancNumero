# Widgets

Three widgets, covering the Home Screen (small, medium, large) and the Lock Screen (circular,
rectangular, inline). All of them are drawn in the notebook style of the app and show **your** data.

| Widget | Families | What it does |
|--------|----------|--------------|
| **Today's page** | Small, Medium, Lock Screen circular, rectangular, inline | Your run as a bookmark ribbon, the last seven days as hand-stamped circles, and whether today's page is written. If it is, a red **"Vu"** stamp and your mark. If your run is at risk it gets louder: a nudge from 18:00, a **"Last call !"** from 21:00. The circular Lock Screen version is a ring of seven arcs, one per day, with your run in the middle. |
| **Un nombre** | Small, Medium, Lock Screen circular, rectangular, inline | Teaches while you do nothing. A French number every three hours, drawn from **your** weak, due and new numbers, with how it's built (*60 + 17*) and the rule. Tap the little arrow for another one without opening the app, or tap the number to open it. Long-press → Edit Widget lets you choose *needs work*, *new numbers* or *a bit of everything*. |
| **Le Tableau** | Medium, Large | All 101 numbers as a colour-coded chart of how well you know each one, with your level, your run, and the chapter you're working on. |

Taps open the right place in the app: a number opens its page, Today's page opens a new page (or the
Today tab once it's done), Le Tableau opens the Tableau tab.

An extra-large size isn't included because it only exists on iPad, and the app is iPhone-only.
Small widgets also show up in **StandBy** automatically.

## How it works

The widgets live in a separate process, so the app hands them data through an **App Group**: a folder
both can read. After every change the app writes one small file (`widget-snapshot.json`: your run,
level, a 101-number mastery list and a dozen numbers to teach) and tells WidgetKit to redraw after a
finished page, a torn page, a test-out and each new day. Everything stays on your phone.

The widgets work out the *state* from the date, not from a stored flag. That is why "page due" turns
into "last call" at 21:00, and a fresh day starts at midnight, even if you never open the app.

If the App Group isn't set up the app carries on as normal and the widgets show a friendly
"Open FrancNumero" state. "Un nombre" still works, using a built-in list of the numbers French
learners trip over most.

## Set up (about 5 minutes)

The app builds and runs exactly as before without any of this. The widget target is added in Xcode,
because that is far safer than me editing your project file by hand.

**1. Add the target.** *File ▸ New ▸ Target… ▸ iOS ▸ Widget Extension.*
Product Name: **`FrancNumeroWidgets`**. Untick *Include Live Activity*, *Include Control* and
*Include Configuration App Intent* if they appear. When asked to activate the scheme, choose **Cancel**.

**2. Swap in my files.** In the new `FrancNumeroWidgets` group, delete the Swift files Xcode generated
(*Move to Trash*). Keep `Info.plist` and `Assets.xcassets`. Then, in Finder, copy these from
`WidgetFiles/` into the project's `FrancNumeroWidgets/` folder:
- every `.swift` file,
- the `Design` and `Shared` folders,
- and replace `Assets.xcassets` with mine (it holds the notebook colours).

Xcode picks the files up on its own.

**3. Fix three build settings on the widget target** (select the target ▸ *Build Settings*, and search
for each). Xcode gives new targets the strict defaults I removed from your app in round 1, and the
widget code needs the same:
- **iOS Deployment Target** → `17.0` (Xcode sets the newest by default)
- **Default Actor Isolation** → `nonisolated`
- **Approachable Concurrency** → `No`
- (and confirm **Swift Language Version** is `Swift 5`)

**4. Add the App Group to both targets.** For **FrancNumero** *and* **FrancNumeroWidgets**:
*Signing & Capabilities ▸ + Capability ▸ App Groups ▸ +*, and enter exactly

```
group.com.theophilusatuahpersonalteam.FrancNumero
```

Tick it on both targets. (If you change this name, change it in `WidgetSnapshot.appGroupID` in both
copies of that file.) If Xcode says your account can't add App Groups, see *If something's off*.

**5. Run.** Run the **FrancNumero** scheme, open the app once so it writes your data, then add the
widgets: long-press the Home Screen ▸ **+** ▸ FrancNumero. For the Lock Screen, long-press it ▸
Customize ▸ Lock Screen ▸ add widgets.

**To debug a widget**, pick the **FrancNumeroWidgets** scheme and press Run. Xcode asks which widget.
Every widget file ends with `#Preview` blocks, so you can also tune the designs live in the Xcode canvas.

## If something's off

- **Widgets say "Open FrancNumero".** The App Group isn't reaching both targets, or the names differ.
  Check *Signing & Capabilities* on both, then open the app once.
- **Xcode refuses the App Group.** Some accounts can't use App Groups, and I couldn't confirm
  whether a free "Personal Team" can. Apple's capability table suggests it can, but a couple of
  third-party pages say it can't. Xcode tells you the moment you add it. If it can't, the app is
  unaffected and "Un nombre" still works on its built-in list. Today's page and Le Tableau need the
  shared data, so they will stay on their "open the app" state until the group works.
- **A widget doesn't change after I finish a page.** The system budgets refreshes. Opening the app
  also refreshes it. Removing and re-adding the widget forces one.
- **Tapping a widget only opens the app.** The tap target needs the `francnumero://` link scheme. It's
  registered in `Config/AppInfo.plist`, which the app target already points at.
- **Build error on the widget target** mentioning actor isolation or `MainActor`: step 3.

## Changing things

| To change | Where |
|-----------|-------|
| Group name | `WidgetSnapshot.appGroupID` (both copies) |
| How often "Un nombre" changes | `FocusNumber` rotation: the `hour / 3` and `* 8` in `WidgetSnapshot.focusNumber`, and the `3 * step` in `NumberProvider` |
| When the evening nudge starts | `TodayState.atRisk` (18:00) and `urgent` (21:00), plus the hours in `TodayProvider.getTimeline` |
| Which numbers get taught | `WidgetSync.focusList` |
| Colours | `WidgetFiles/Assets.xcassets` (a copy of the app's) |

If you edit `WidgetSnapshot.swift`, copy it over its twin. `python3 Tools/check_widget_files.py`
tells you whether they match, and `--fix` copies the app's version across.

## Not included

- **Controls** (Control Center buttons, iOS 18 and later) and **Live Activities.** A "start today's page"
  control would be a natural next step. It needs an iOS 18 minimum for that one piece.
- **Speaking from a widget.** Widgets can't play the app's voice on their own, so the medium
  "Un nombre" says *Hear it in the app* and the tap opens that number, where you can hear it.
