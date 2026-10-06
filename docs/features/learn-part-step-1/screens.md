---
status: draft
feature_size: "S"
tool: "code"
updated_at: "2026-10-06"
---

# Screens — learn-part-step-1

> The canonical **screen manifest** — every screen in every state — produced by `screens` (between
> `api` and `tasks`) and read by `tasks` (each `ui` task cites SCR ids + states), `implement`
> (builds the screen to the declared states) and `review` (the built screen must match this).
> Downstream stages reference **only this manifest**.

## Source

- **Tool:** code. There is no `docs/design-system.md` yet, so no canon tool is declared and this manifest falls back to code mode.
- **File:** inline wireframes below.
- **Component inventory used instead of a canon:** what the repo already has. In the app that means Flutter Material widgets as `words_table_screen.dart` uses them: `AppBar`, `ElevatedButton.icon` (Share), `SnackBar`, `TextButton`, `Tooltip`, `CheckboxListTile` and `ListTile`. On the web it means the shared page's `shell()` and these CSS classes in `src/session/style.ts`: `.actions`, `.btn`, `.toasts`/`.toast` (the `toast()` helper in `page.js`) and `.gone` (`renderNotFoundPage`).
- **Inputs:** [ux-flows.md](ux-flows.md) (SCR-01…08), spec §5 AC-01…AC-13, [sad.md](sad.md) §6 S-01…S-05, [contracts/openapi.yaml](contracts/openapi.yaml) (`getLearnPage`, `getComingSoonPage`, GonePage 404).
- **Owner decision (screens stage, 2026-10-06):** the learn page's title is **"Learn"**, both as the app's `AppBar` title and as the web page's `h1`. The word count sits under it.
- **Shared wording:**
  - Word count: `"1 word"` / `"<n> words"`, the same rule as the shared page (`page.ts:191`).
  - Hint: `"Pick at least one exercise"`.
  - Coming-soon text: `"Coming soon — this exercise is not ready yet."`.
  - Back button: `"Back to exercises"`.
  - No-words message: `"No words to learn"`.
  - Exercise names: AC-04 labels, verbatim, in `exercises.json` order (ADR-0003).

## Screens

### SCR-01 — Main screen or History (app)

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | Unchanged by this feature. It is only the existing way to SCR-02 | existing | — |
| empty / error | N/A: this feature changes nothing on this screen | — | — |

### SCR-02 — Words screen (app)

The top bar order is back arrow, Learn, "Words", Share (AC-01). Learn is `ElevatedButton.icon` with `Icons.school` (graduation cap) and the label "Learn", styled exactly like Share. In each layout the two buttons have the same padding. `NEW: LearnShareBar` measures the space and picks the layout.

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default · normal bar | Everything fits with today's padding (AC-01, AC-12; S-05 first branch) | `AppBar`, 2 × `ElevatedButton.icon` (Share untouched: `Padding(right: 16)`, same icon and label; Learn matching), `NEW: LearnShareBar` | wireframe A |
| default · compact bar | Doesn't fit with today's padding, but fits with less (AC-11; S-05 second branch) | Same, with smaller horizontal padding. Icons and labels kept, "Words" whole, each button ≥ 48 × 48 dp | wireframe B |
| default · icon-only bar | Doesn't fit even with less padding (AC-11b; S-05 third branch) | Same, without labels. Each icon is wrapped in a `Tooltip` ("Learn", "Share"); "Words" whole; each button ≥ 48 × 48 dp | wireframe C |
| icon-only · long press | Long press on an icon (AC-11b) | `Tooltip` showing "Learn" or "Share" | wireframe C |
| empty | Session has no word to learn ("No words added yet") and Learn is tapped (AC-03; S-01 first branch) | `SnackBar` "No words to learn", as Share's "No words to share". The learn page does not open | wireframe D |
| success | At least one word to learn and Learn is tapped (AC-02, AC-13) | `LearnRoute(sessionId).push`. Opens SCR-03 for this screen's session (current or History) | → SCR-03 |
| loading | N/A: the screen's existing loading is unchanged. Learn counts the rows the screen already holds (sad §4) | — | — |
| error | N/A: Learn only reads rows already in memory and has no failure path (S-01 has no error branch) | — | — |

```text
A · normal bar (Share exactly as today)
+------------------------------------------------------+
| <-  [🎓 Learn]   Words             [⤴ Share]        |
+------------------------------------------------------+

B · compact bar (smaller padding, labels kept)
+--------------------------------------------+
| <- [🎓 Learn] Words          [⤴ Share]     |
+--------------------------------------------+

C · icon-only bar (long press shows the name)
+------------------------------+
| <-  [🎓]  Words        [⤴]   |
|      └ "Learn" (tooltip)     |
+------------------------------+

D · empty session, Learn tapped
+------------------------------------------------------+
| <-  [🎓 Learn]   Words             [⤴ Share]        |
|                                                      |
|                 No words added yet                   |
|                                                      |
| [ No words to learn                              ]   |  <- SnackBar
+------------------------------------------------------+
```

### SCR-03 — Learn page (app)

Full screen, pushed on top of SCR-02. The `AppBar` title is "Learn" with a back arrow. Under it come the word count, three sections headed "Step 1", "Step 2" and "Step 3", one `CheckboxListTile` per exercise, then the hint and Start at the bottom. Ticks are kept in widget `State` only.

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | Opened from Learn: nothing ticked (AC-04, AC-05b, AC-07; S-02 opening state) | `AppBar` ("Learn"), `Text` count, section headers, 11 × `CheckboxListTile`. Mnemonic story is enabled; the other ten are `enabled: false` (greyed) with the subtitle "Coming soon". Start is an `ElevatedButton` with `onPressed: null`, and "Pick at least one exercise" is shown near it | wireframe E |
| coming-soon tap | Tap on a coming-soon tile, its box or its label (AC-06) | Same as before the tap: a disabled tile ignores taps, nothing changes | wireframe E |
| ticked | Mnemonic story ticked (AC-05, AC-07; S-02) | Start enabled, hint hidden | wireframe F |
| unticked again | Mnemonic story unticked (AC-07) | Back to `default`: Start disabled, hint shown | wireframe E |
| start pressed (disabled) | Start pressed with nothing ticked (AC-07; S-02) | Nothing happens; the hint stays | wireframe E |
| success | Start pressed while ticked (AC-05) | `ComingSoonRoute(exercise: first ticked in plan order).push` → SCR-04 | → SCR-04 |
| returned | Back from SCR-04 (AC-05) | Same `State`, so Mnemonic story is still ticked | wireframe F |
| loading | N/A: the exercise list is a Dart const and the rows are already held, within the 300 ms target (ADR-0003, sad §4) | — | — |
| empty | N/A: unreachable, because Learn never opens this page for a session with no word to learn (AC-03, CONTEXT invariant) | — | — |
| error | N/A: the page only reads local data and has no failure branch in S-01/S-02 | — | — |

```text
E · default (nothing ticked)            F · ticked / returned
+-------------------------------+       +-------------------------------+
| <-  Learn                     |       | <-  Learn                     |
| 12 words                      |       | 12 words                      |
|                               |       |                               |
| Step 1                        |       | Step 1                        |
| [ ] Mnemonic story            |       | [x] Mnemonic story            |
| [ ] Match synonyms     (grey) |       | [ ] Match synonyms     (grey) |
|     Coming soon               |       |     Coming soon               |
| [ ] Match antonyms     (grey) |       |  …                            |
| [ ] Match word and definition |       |                               |
| Step 2                        |       |                               |
| [ ] Pick the right answer  …  |       |                               |
| [ ] Fill the gaps          …  |       |                               |
| [ ] Remember or not        …  |       |                               |
| Step 3                        |       |                               |
| [ ] Make your own sentences … |       |                               |
| [ ] Translate sentences     … |       |                               |
| [ ] Make your own sentences   |       |                               |
|     (speak)                 … |       |                               |
| [ ] Translate sentences       |       |                               |
|     (speak)                 … |       |                               |
|                               |       |                               |
| Pick at least one exercise    |       |                               |
| [ Start ]  (disabled)         |       | [ Start ]                     |
+-------------------------------+       +-------------------------------+
```

### SCR-04 — Coming-soon screen (app)

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | Start on SCR-03 with Mnemonic story ticked (AC-05; S-02) | `AppBar` with a back arrow, `Text` heading "Mnemonic story" (the exercise's name), `Text` "Coming soon — this exercise is not ready yet.", an `ElevatedButton` "Back to exercises" that pops | wireframe G |
| back | "Back to exercises" or the back arrow (AC-05) | `pop` → SCR-03 `returned` | → SCR-03 |
| loading / empty / error | N/A: static text for a known available exercise. The route is only pushed from Start, which offers available exercises only (AC-06) | — | — |

```text
G · default
+-------------------------------+
| <-                            |
|                               |
|  Mnemonic story               |
|  Coming soon — this exercise  |
|  is not ready yet.            |
|                               |
|  [ Back to exercises ]        |
+-------------------------------+
```

### SCR-05 — Shared page (web)

The only visible change is one link, `<a class="btn learn" href="/s/{id}/learn">Learn</a>`, inside `.actions` and to the right of "Download for AnkiDroid", looking the same (AC-08).

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default · phone layout | Below 900 px (`WIDE`) | `.actions` holding `.btn` Download, `.btn` Learn and the existing photo button | wireframe H |
| default · wide layout | 900 px and wider | Same `.actions` row | wireframe H |
| empty | The fresh saved rows hold no word to learn when Learn is pressed (AC-10; S-03 first branch) | `toast("No words to learn")` in `.toasts`. No navigation, and in the wide layout the pre-opened empty tab is closed | wireframe I |
| success · phone layout | At least one word to learn (AC-08; S-03) | Same tab → SCR-06; the browser's back button returns here | → SCR-06 |
| success · wide layout | At least one word to learn (AC-08; S-03) | The tab opened empty during the click receives `/s/{id}/learn` → SCR-06. The shared page and any unsaved cell stay open | → SCR-06 |
| error | The `/changes` fetch fails, for example with no connection (S-03 `else` branch) | No visible error: the decision uses the rows the page already holds, then goes to `empty` or `success` as above | — |
| loading | N/A: no visible pending state. S-03 draws none, and the fetch is one small request | — | — |

```text
H · .actions row (phone and wide)
+---------------------------------------------------------------+
| Vocabulary                                                    |
| 12 words · published … · available until …                    |
| [Download for AnkiDroid]  [Learn]  [Photos]                   |
| # | Word | Translation | …                                    |
+---------------------------------------------------------------+

I · empty — toast, no navigation
|                                                               |
| ┌────────────────────┐                                        |
| │ No words to learn  │   <- .toast, bottom left               |
| └────────────────────┘                                        |
```

### SCR-06 — Learn page (web)

This page is rendered by `getLearnPage` inside the shared page's `shell()` and stylesheet. The `h1` is "Learn", with the word count under it. Each exercise is a native checkbox inside a `label` (`NEW: .exercise` rows). Start is an `a.btn` whose `href` `learn.js` keeps up to date. The page is one column and needs no sideways scrolling at 320 px (AC-08, spec §6).

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | `GET /s/{id}/learn` with no valid `pick` (AC-04, AC-05b, AC-07, AC-08, AC-08b; S-04) | `shell()`, `h1` "Learn", count, `h2` "Step 1/2/3", 11 × `NEW: .exercise`. Mnemonic story is enabled; the other ten have a `disabled` box, are greyed (`.soon`) and carry "Coming soon". Start is `.btn` marked unavailable (`aria-disabled`, greyed), with the hint "Pick at least one exercise" | wireframe J |
| coming-soon tap | Tap on a coming-soon box or label (AC-06) | The `disabled` input ignores it; nothing changes | wireframe J |
| ticked | Mnemonic story ticked (AC-07; S-04) | `learn.js`: Start available (its `href` is `/s/{id}/learn/mnemonic-story?pick=mnemonic-story`), hint hidden, address rewritten with `?pick=` (`replaceState`) | wireframe K |
| unticked again | Mnemonic story unticked (AC-07) | Back to `default`; `pick` removed from the address | wireframe J |
| returned | `GET /s/{id}/learn?pick=mnemonic-story`, from "Back to exercises" or the browser's back button (AC-05) | Server-rendered with Mnemonic story `checked`, i.e. `ticked`. An invalid `pick` is ignored, giving `default` (AC-06) | wireframe K |
| success | Start pressed while ticked (AC-05) | Follows Start's `href` → SCR-07 | → SCR-07 |
| empty | Live session with no word to learn, link opened directly (AC-08b; S-04 second branch; contract 200 no-words page) | `shell()`, `h1` "No words to learn", a link to `/s/{id}` | wireframe L |
| error | Session expired or unknown (AC-09; contract 404 GonePage) | → SCR-08, the same response as a dead shared link | → SCR-08 |
| no script | JavaScript off or `learn.js` failed to load (ADR-0002 negative consequence) | The page renders as `default`; ticking works natively but Start stays unavailable | wireframe J |
| loading | N/A: a complete server-rendered page with no client fetch, within the 1.5 s on 4G target | — | — |

```text
J · default, 320 px                     K · ticked / returned
+----------------------------+          +----------------------------+
| Learn                      |          | Learn                      |
| 12 words                   |          | 12 words                   |
| Step 1                     |          | Step 1                     |
| [ ] Mnemonic story         |          | [x] Mnemonic story         |
| [ ] Match synonyms  (grey) |          | [ ] Match synonyms  (grey) |
|     Coming soon            |          |     Coming soon            |
|  … (Step 2, Step 3 as in   |          |  …                         |
|     SCR-03, wrapping, no   |          |                            |
|     sideways scroll)       |          |                            |
| Pick at least one exercise |          |                            |
| [Start] (greyed)           |          | [Start]                    |
+----------------------------+          +----------------------------+

L · empty (link opened directly, no word to learn)
+----------------------------+
| No words to learn          |
| Back to the word list  ->  |   <- link to /s/{id}
+----------------------------+
```

### SCR-07 — Coming-soon page (web)

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | `GET /s/{id}/learn/mnemonic-story?pick=…` (AC-05; S-04; contract 200) | `shell()`, `h1` "Mnemonic story", `p` "Coming soon — this exercise is not ready yet.", `.btn` "Back to exercises". Its `href` is `/s/{id}/learn?pick=…`; `learn.js` uses `history.back()` when the previous entry is this session's learn page (ADR-0002) | wireframe M |
| back | "Back to exercises" or the browser's back button (AC-05) | → SCR-06 `returned` | → SCR-06 |
| error | Dead session, or an exercise that is unknown or not available (AC-06, AC-09; contract 404 GonePage; S-04 `opt`) | → SCR-08 | → SCR-08 |
| empty | Live session with no word to learn. **Provisional: shown as `default`** (contract OQ-1, owner `sequences`). Update this row when OQ-1 is resolved | as `default` | wireframe M |
| loading | N/A: a server-rendered static page | — | — |

```text
M · default
+----------------------------+
| Mnemonic story             |
| Coming soon — this         |
| exercise is not ready yet. |
| [Back to exercises]        |
+----------------------------+
```

### SCR-08 — "This word list is gone" page (web)

| State | Trigger / condition | Components (from the inventory) | Source-ref |
|---|---|---|---|
| default | Learn or coming-soon link for an expired or unknown session, or an unknown or unavailable exercise (AC-09; contract 404 GonePage) | The existing `renderNotFoundPage()` (`.gone`), **unchanged**: status, headers and body identical to `GET /s/<unknown id>` | existing page |
| loading / empty / error | N/A: this page is itself the error answer and is unchanged | — | — |

## New components

| Component | Why no existing primitive fits | Registered in design-system |
|---|---|---|
| `LearnShareBar` (app, `lib/features/words_table/widgets/learn_share_bar.dart`) | No existing widget chooses between the normal, compact and icon-only layouts by measuring the available width at the current text scale (AC-11, AC-11b, AC-12; sad §4). It composes `ElevatedButton.icon` and `Tooltip` and invents no new look | pending — no `docs/design-system.md` yet |
| `.exercise` / `.soon` rows (web, rules in `src/session/style.ts`) | The shared page has no tick-box list. A native checkbox in a `label`, greyed when `disabled`, is the smallest addition that works under the existing CSP and stylesheet | pending — no `docs/design-system.md` yet |
