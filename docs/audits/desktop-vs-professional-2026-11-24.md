# ZÆTHERION compared with professionally built UIs · 24 November 2026

A follow-up to `desktop-cohesion-2026-11-24.md` (findings F1–F21 and fixes S1–S7 are from there). This is a report
only: no view code was changed. Baseline is `s0-seed` at `cf5325d`. Every measurement below was taken offscreen with
fixture data, and nothing on the live session was touched.

The question: compared with desktops and design systems made by professional teams, what is ZÆTHERION missing? You
already suspected the answer isn't more features. This report agrees and says what it is instead.

Tags: **Astra** (looks) · **Claude B** (behaviour, wiring) · **Owner pick**. Sizes: S (an hour or two), M (a day),
L (several days).

---

## 1. Verdict

1. **Features aren't the gap; rules are.** Professional UIs make very few visual decisions and repeat them everywhere. ZÆTHERION makes a new decision almost every time it draws something. It uses 12 font families where professional systems use 2, 40 different spacing values, 37 different transparency levels and 11 kinds of easing.
2. **Professional teams make the right choice the easy one.** A new screen is assembled from parts that already behave correctly. In ZÆTHERION, new surfaces arrive as studies with their own parts. Fluid is a second set of parts rather than a setting on the first set, so it always lags behind Angular.
3. **ZÆTHERION lacks the habits that make something feel solid.** Motion can be interrupted without a jolt, numbers keep still while they change, icons match the form and weight of the text beside them, and every clickable thing reacts by the same rule.
4. **The last gap is the quality loop.** Professional teams keep a catalogue of every part in every state, and they compare screenshots before anything merges. ZÆTHERION has good tests for behaviour but no such catalogue, so mismatches only show up on your screen.
5. **Much of ZÆTHERION is already at a professional level**, notably the island's timing rule, hover intent and the way surfaces grow from the island (§4). The aim is to make the rest of the desktop work the same way, not to start again.

---

## 2. What it was compared against

| System | Why it's a fair comparison |
|---|---|
| **Apple**: iOS Dynamic Island, macOS menus, SF Pro and SF Symbols, SwiftUI springs | ZÆTHERION's island has the same job: one shape that turns into many things. |
| **Google Material 3** (and Material 2's shape theming) | A fully documented set of tokens for motion, state and shape. Material 2 themed **cut corners versus rounded** as a single setting, which is exactly Angular versus Fluid. |
| **KDE Plasma / Kirigami** | A desktop shell written in **QML**, the same toolkit, with shared `Units` for spacing and duration. |
| **GNOME / libadwaita** | A Linux desktop with a strict design guide, a small set of spacing values and spring animations. |
| **Microsoft Fluent 2 / Windows 11** | Named motion tokens, and transitions where an element carries over from one screen to the next. |
| Game and film interfaces with a strong identity (the angular sci-fi kind) | The closest relatives to FART's look. They show that a bold look holds together because it follows a few strict rules, not because it plays safe. |

None of these is a model for the *look*. FART's look is decided (UI_BRIEF, "The look is FART's, strictly"). The comparison is about the care behind each look.

---

## 3. The gaps, ranked by how much each one costs the feeling of one desktop

### G1 · Fluid is a second set of parts, not a setting · Claude B + Astra · L

**What professional teams do:** Material 2's shape theming let one app switch every component between **cut** and **rounded** corners with one token per size (small, medium, large). Android draws both with the same component and swaps only the corner treatment. Duration and easing are tokens too. A form is a set of values the components read. It is never a second set of components.

**What ZÆTHERION does:**
- The Angular parts are `FButton`, `FChoice`, `FText`, `FToggle`, `FField`, `FMenuItem` and about 20 more in `view/ui/`.
- The Fluid parts are a separate, smaller set in `view/fluid/`: `FluidButton`, `FluidChoice`, `FluidText` and `FluidActionRow`.
- Fluid has no toggle, no text field and no menu row of its own.
- 13 places pick a family with `Design.fluid ? … : …`, and every room exists twice (for example `AngularHome` and `FluidHome`).
- This explains why the first audit found Fluid half built (F6). The structure guarantees it: every new Angular thing needs a Fluid twin written by hand, and some never get one.

**Why it reads as unfinished:** when you switch form, part of the screen changes and part doesn't. Professional products never show that seam, because no part can exist in one form only.

**What to do, in ZÆTHERION's vocabulary:**
- Move the form into `Design` as values that every `F*` part reads:
  - corner treatment: `cut` or `round`, with its size per role;
  - the state rule (G3);
  - the motion rule: `cutDuration` or the Fluid spring (G4);
  - the font families (G2).
- Keep a `Fluid*` file only where Fluid is genuinely a different layout, such as a room. Retire the others behind the shared part.
- Do this as part of S1 and S5 from the first audit. It's the largest item here and the one that stops the drift.

### G2 · Too many decisions per pixel · Astra · M (rules), then S-sized sweeps

Professional systems limit choices so that any two screens share almost every value. Counts across `view/` (333 QML files):

| What | ZÆTHERION today | Typical professional system |
|---|---|---|
| Text font families | **11**: Roboto Condensed, JetBrainsMono Nerd Font, "JetBrains Mono" (a different name for the same face), Inter, Inter Display, Poppins, Anurati, DejaVu Sans, DejaVu Sans Mono, DejaVu Serif, Noto Sans | **2**: Apple (SF Pro + SF Mono), GNOME (Adwaita Sans + Mono), KDE (system sans + mono). Display faces only on a hero element. |
| Icon families | 1 (Material Symbols Rounded), but rounded in both forms (G6) | 1, matched to the text |
| Spacing values | **40 distinct literal values** across 368 uses. **55% of them (204) are off the 4 px rhythm** that `Design.baseline: 4` declares. Rooms: 235 literal values against 2 tokens. | About 6–10 named steps on a 4 or 8 px grid (Material). Kirigami's `smallSpacing`/`largeSpacing`, libadwaita's 6/12/18/24. |
| Transparency levels (`Qt.alpha`) | **37 distinct values** across 228 uses | 4 state levels (Material: hover 8%, focus and press 10%, drag 16%) plus 2–3 text levels |
| Easing types outside `view/cues` | 11 kinds in 28 files | 3–4 named curves, or 2 spring presets |
| Fixed colours | 100 distinct hex values in 21 files | none outside the palette |
| Font sizes | Good: 192 of 320 come from the `Design` scale | named scale only |

What isn't the problem:
- The type scale itself is fine. No file uses more than 6 sizes, and most text sizes come from `Design`.
- Fluid's spacing is disciplined: 66 uses of `FluidTokens` against 3 literal values. Shell code mostly uses tokens too.
- The drift is in the rooms, the desktop widgets, the lock and Overdrive.

**Why it reads as unfinished:** nobody consciously notices 10 px here and 14 px there. People do notice that two panels feel slightly different without being able to say why. That's the "not cohesive at all" feeling in its purest form.

**What to do:**
- Add `Design.space` steps (for example 4 · 8 · 12 · 16 · 24 · 32 · 48) and two text-transparency roles (`muted` and `faint` already exist; use them instead of `Qt.alpha(ink, 0.55)`).
- Name exactly two text families per form, plus `Design.display` for the clock's Anurati, which must still never be committed.
- Extend the `RAW_MOTION` lint idea (S7) to spacing, alpha and family literals in `view/rooms`, `view/widgets` and `view/lock`. Allow exceptions only with a comment, the way `// scale:` already works for font sizes.

### G3 · No single rule for how things react · Astra (rule) + Claude B (parts) · M

**What professional teams do:**
- Material defines one *state layer*: the content colour laid over the control at 8% on hover, 10% on focus or press and 16% while dragging.
- Only one layer shows at a time, and disabled controls don't react at all.
- Every button, row, chip and card follows it, so the whole system "feels" the same under the pointer.
- Apple and Fluent have the equivalent: one highlight per control type, everywhere.

**What ZÆTHERION does:** at least five different reactions.
- `FButton` wipes in a fill with `Tween`, which is good.
- `FluidButton` snaps its colour with no motion.
- `FMenuItem` behaves differently again.
- The desktop menu repaints a Canvas.
- The editor buttons have no reaction at all (F4, F5).
- Focus visuals appear in 12 shared parts and in none of `view/widgets` or `view/lock`.

**What to do:**
- Write the rule down once in `Design`: `state.hover`, `state.press`, `state.focus` and `state.drag` amounts, plus one focus mark.
- Then let each form draw it in its own way:
  - Angular: the wipe reaches the amount on `Motion.feedback`;
  - Fluid: a tint over `FluidTokens.controlRadius`.
- This is S1 from the first audit, made into a written rule so new surfaces can't skip it.

### G4 · Motion that jolts when interrupted · Claude B · M

**What professional teams do:**
- Apple moved its system animation to springs. Its WWDC23 session *Animate with springs* explains why: a spring keeps both position and *speed* continuous when it's retargeted mid-flight. A fixed curve can't carry speed in, so it starts each new run at its own built-in speed.
- Material 3 Expressive did the same in 2025, with "spatial" springs for size and position and "effects" springs for colour and fade.
- libadwaita has `AdwSpringAnimation` for the same reason.

**What ZÆTHERION does (measured):**
- I logged the island's width every frame (about 16 ms) while a notice arrived and was dismissed 150 ms later (`pro/retarget.log`).
- **Fluid:** the island is still growing at +0.47 px/ms, and on the next frame it shrinks at **−5.88 px/ms**. That's a full reversal at top speed in one frame, a visible snap. It happens because `Tween` is a `Behavior`, so every retarget starts a fresh OutBack curve, and that curve begins at its fastest.
- **Angular:** the departure starts from rest and accelerates. It stops at full speed when it reaches the resting size, and the width lands at 361 ms while the height lands at 425 ms, so the outline settles in two steps. This is the Cut that **Z150's 21 November amendment** chose ("a reversal starts at the visible shape"), so the curve stays. The two axes landing 64 ms apart is not part of that decision and looks like a slip.

The same jolt happens wherever a `Tween` is retargeted quickly: hover rows, volume going up and down, selection moving through a list.

**What to do:**
- For **Fluid**, give `Motion` a spring role (QML's `SpringAnimation` keeps the current speed when its target changes). Use it in `ExtentTween` and in Fluid's `Tween`s. Fluid's current overshoot already looks like a spring: the island widens to 722 and settles at 716. A real spring would keep that character and remove the snap.
- For **Angular**, keep the Cut (Z150). Make width and height share one duration, worked out once per change, so the cut outline lands in one piece.
- This is a small, contained change in `view/cues` plus `IslandSurface.qml:271-295`.

### G5 · Numbers that shuffle sideways · Astra · S

**What professional teams do:** clocks, timers and meters use *tabular* figures, so every digit is the same width. Apple's clock, Windows' taskbar clock and GNOME's top-bar clock don't change width as the minutes tick over.

**What ZÆTHERION does (measured, `pro/Digits.qml`, at 100 px):**

| Face | Digit width spread | "11:11" vs "20:08" |
|---|---|---|
| Roboto Condensed, JetBrains Mono, DejaVu, Noto | 0 (fixed by default) | same width |
| **Inter** (all of Fluid) | 41 to 65 px | **191 vs 278 px (+45%)** by default; fixed with `tnum` |
| **Poppins** (desktop clock and login details) | 32 to 64 px | **149 vs 268 px (+79%)**, and `tnum` does nothing: the font has no tabular digits |

- `FText`, `FField`, `FChoice`, `RollingDigits`, `FluidHome`'s clock and the timers set `tnum`. **`FluidText` doesn't**, so Fluid's Performance percentages, memory figures, task counts and media times change width with every update.
- The desktop clock's time label (`OffcutFace.qml:52-60`, `DayIndexFace.qml:124-131`) changes width every minute. In Offcut it also changes the width of the date line, which is sized as date + 30 + time.

**What to do:**
- Add `font.features: { "tnum": 1 }` to `FluidText`, which is one line.
- For the desktop clock, set its figures in a face that has tabular digits, or hold each digit in a fixed-width cell (`RollingDigits` already does this). Which face to use is an owner and Astra pick, since Poppins came from the study.

### G6 · Icons that don't match the form or the text beside them · Astra · S

**What professional teams do:** SF Symbols come in nine weights so that an icon matches the weight of the text next to it. Material Symbols offer **Sharp**, **Rounded** and **Outlined** sets so that icons match the shape language.

**What ZÆTHERION does:**
- `MaterialSymbol.qml:7` is always **Rounded**, in Angular as well. Sharp is installed.
- The icon weight is 400 (300 for Fluid "thin"). Angular text beside it is mostly Black or Bold: `Font.Black` is the most-used weight in the project, with 56 uses.
- Sizes are 14, 16, 20, 22, `statusIcon` or a fraction of the parent, with no named scale.

**What to do:**
- `font.family: Design.fluid ? "Material Symbols Rounded" : "Material Symbols Sharp"`.
- Give `iconWeight` an Angular value close to the text weight, around 600–700.
- Add `Design.icon` sizes for caption, control and status.
- This is a small change that people notice immediately on every icon.

### G7 · Designing for the best case only · Astra + Claude B · M

**What professional teams do:** every part is drawn with deliberately awkward content: the longest translated label, a two-line title, zero items, one item, a hundred items, missing artwork, an error. Apple's guidelines, GNOME's guide and Material's component pages all show these cases next to the normal one.

**What ZÆTHERION does:** the fixtures show the pleasant case. The overlaps the first audit found (F11: Home, Devices, Inbox) and the lock and selector states that weren't rendered come from the same habit.

**What to do:** give each room's fixture a "rough day" set (long name, empty, many items, offline) and render it in the catalogue (G8).

### G8 · No catalogue and no screenshot gate · Claude B · M

**What professional teams do:** every serious system has a living catalogue: GNOME's *Widget Factory*, KDE's *Kirigami Gallery*, Material's catalogue app, Apple's UIKit Catalog. It shows every component in every state on one screen. Teams also keep reference screenshots and fail a change when the pixels move unexpectedly. Design reviewers check that page before a merge.

**What ZÆTHERION has:**
- Behaviour tests are strong: more than 200 test files, and several of them already grab images (`test_lock_screen`, `test_selector`, `test_osd_change`, the island fixtures).
- `tools/shots.py` renders rooms.
- But there's no page that shows **every part × state × form × palette** together, and no stored reference screenshots to compare against.
- The desktop studies got in without anything checking them against the system. A catalogue would have shown the mismatch the first time it rendered.

**What to do:**
- Build a `tools/catalogue` harness that lays out every `view/ui` and `view/fluid` part. Show each part at rest, hover, press, focus, disabled and with long text, in Angular and Fluid, on one dark and one light palette.
- Store its renders under `tests/` as reference images, then add a test that reports when pixels change by more than a small threshold.
- Make "added to the catalogue" part of what counts as done for any new surface (AGENTS.md).
- This is how professional teams keep many people consistent, and ZÆTHERION has several authors.

### G9 · The same gesture behaving differently · Astra + Claude B · M

**What professional teams do:**
- Professional teams don't animate everything. **macOS context menus open instantly.** The care is that every menu on the system opens the same way, and when you choose an item it flashes once before the menu fades.
- Windows 11 menus all slide and fade the same way.
- Every surface opens from a known origin: the pointer, the control that summoned it, or the edge it belongs to.

**What ZÆTHERION does:**
- There are three menus that behave three ways (F9).
- The desktop menu comes from nowhere: no origin and no motion (F4).
- The panel and Settings grow from the island, which is right (Z157).

**What to do:**
- Choose one menu behaviour per form, then make all three menus use it (S5).
- Angular could be "cut open from the pointer on `cutDuration`, flash the chosen row on `Motion.feedback`, fold on `cutOut`".
- The macOS lesson: the selection flash and a consistent close matter more than a showy open.

### G10 · Boldness without a budget · Owner pick

**What professional teams do:** the boldest professional interfaces, such as Nothing OS and the sci-fi game interfaces, are bold through repetition: one display face, one accent, one corner, one way of moving, used without exception. Each screen has one hero moment, and everything else stays quiet around it.

**What ZÆTHERION does:** the creative ambition is real and should stay (experimental, never boring). But each study introduces its own hero: a new face, a new plate, a new colour. Bold elements then compete with each other instead of supporting each other.

**What to do:** keep the ambition, and give each surface a single "hero". For example: the desktop clock's Anurati, the orbit, the lock's karaoke. Everything around the hero speaks the shared system from G1–G3. This is a direction for Astra rather than a rule. Whether to adopt it is your call.

---

## 4. Where ZÆTHERION is already at a professional level (leave alone, copy outward)

- **Timing that scales with distance.**
  - `Motion.cutDuration` lengthens with how far the edge moves and how much the size changes.
  - Departures run at 72% of the arrival time.
  - That is exactly the guidance from Material and Apple (bigger moves take longer, exits are quicker), and very few hobby shells do it.
- **Hover intent.** Measured: the island waits about 320 ms before opening its wings, so a pointer crossing it for 120 ms opens nothing. That's the same courtesy macOS shows with its tooltips and Dock.
- **Everything grows from the island** (Z150, Z157). This matches Material's *container transform* and Apple's Dynamic Island, the strongest idea in the project.
- **Fluid's slight overshoot**: 6 px past, then settle. It already feels spring-like; G4 only removes the snap when it's interrupted.
- **Reduced motion and time scale.** `Motion.scaled` is used throughout, as professional systems do.
- **Accessibility labels.** There are 136 `Accessible.*` uses, more than many shells have.
- **Discipline where the system exists.** Fluid spacing (66 tokens against 3 literals), shell code, and the `Design` type scale show the project can work to tokens. The drift is in the parts that skipped the system.
- **The core's contrast lift** (`palette_catalog.normalize`), the same idea as impasto's minimum contrast and Material's tonal palettes.

---

## 5. Suggested order (polish work, not features)

| Step | What | Gap | Tag | Size |
|---|---|---|---|---|
| 1 | `tnum` in `FluidText`; Sharp icons and a heavier weight in Angular | G5, G6 | Astra | S |
| 2 | Width and height of the Cut share one duration | G4 | Claude B | S |
| 3 | A written state rule in `Design`, drawn by both forms' buttons and rows | G3 (S1) | Astra + Claude B | M |
| 4 | The catalogue harness and reference screenshots | G8 | Claude B | M |
| 5 | `Design.space`, two families per form, and a lint for literals in rooms, widgets and lock | G2 (S7) | Astra + Claude B | M |
| 6 | A Fluid spring role in `Motion`, used by `ExtentTween` and Fluid `Tween`s | G4 (S3) | Claude B | M |
| 7 | One menu behaviour per form, used by all three menus | G9 (S5) | Astra + Claude B | M |
| 8 | Form as values that every `F*` part reads; retire duplicated `Fluid*` parts | G1 (S1, S5) | Claude B + Astra | L |
| 9 | "Rough day" fixtures in every room, shown in the catalogue | G7 | Claude B | M |
| — | One hero per surface | G10 | Owner pick | — |

Steps 1 and 2 are small enough to try this week, and you'd notice them straight away. Step 4 makes every later step checkable. Step 8 is what stops Fluid falling behind again.

---

## 6. How this was checked

- **Counts:** grep and a short Python tally over `view/` for spacing keys, `Qt.alpha` values, `font.family`, `font.weight`, `pixelSize`, `Easing.` and hex colours. Numbers are as of `cf5325d`.
- **Digit widths:** `pro/Digits.qml` measured each digit 0–9 and two clock strings at 100 px, with and without `tnum`, in every face the shell uses.
- **Interruption:** `pro/Retarget.qml` (built on the first audit's island harness, run through `tools/smoke.prepare` offscreen) logged `island.width` and `island.height` every frame in both forms. It covered a full hover, a 120 ms pointer crossing, and a notice dismissed after 150 ms. The output is `pro/retarget.log`.
- **Scratch files:** these are in the audit's scratch folder, not in Git.
- **Professional references:** published documentation, not copied art.
  - Apple's WWDC23 session *Animate with springs* (10158), and the SwiftUI `interpolatingSpring` documentation on velocity across overlapping animations.
  - Material 3 state-layer values as generated in Flutter's Material token data (hover 0.08, focus 0.10, press 0.10, drag 0.16).
  - The Material 3 Expressive motion scheme (spatial and effects springs, each fast, default or slow).
  - KDE's HIG *Units and Measurements* page and the Kirigami `Units` source.
  - Material 2 shape theming (cut and rounded corner families).
  - What macOS, Windows 11 and GNOME do is described from their shipped behaviour.
- **Not done:** no side-by-side screenshots of other products, and no second monitor.
