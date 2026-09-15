# Task 01 — Reverso is gone from the app and the Worker

|  |  |
|---|---|
| **Roadmap step** | [#1](../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 1 (alone — it is the only step touching the word-detail UI and the Worker route table in one change) |
| **Depends on** | — |
| **Blocked on** | — |
| **Unlocks** | task-09's recon (it frees the word-detail slot) |
| **Files** | `lib/widgets/reverso_info_popup.dart` · `lib/services/reverso_service.dart` · `lib/models/reverso_info.dart` · `lib/screens/word_input_screen.dart` · `vocab-photo-api/src/reverso.ts` · `vocab-photo-api/src/index.ts` · `vocab-photo-api/README.md` · `pubspec.yaml` |
| **Status** | code complete (`8a6356f`); AC-9, AC-10, AC-11 need a manual device pass |

## Starting state — read this first

Reverso is **not** committed code being retired. `git status` shows it as work in flight: the
Reverso service, model, popup widget and Worker module are all staged as *additions*. So this task
has two possible shapes, and you must pick one before touching anything:

- **(a) Commit-then-remove** — commit the staged work as the documented dead end it is, then remove
  it in a second commit. The investigation stays in history; `git log` explains why Reverso was
  tried and why it failed.
- **(b) Unstage** — drop the Reverso additions from the index and never commit them. Cleaner tree,
  but the 403-from-Cloudflare finding then lives only in `vocab-photo-api/README.md`.

**(a) is recommended** — the README's investigation is the kind of thing that gets re-litigated in
six months, and a commit is a better anchor for it than prose. Either way, say in the commit
message which you chose.

## Prompt

Remove the Reverso integration from this repo entirely. Reverso's free tier does not work for this
app: `/reverso-context` returns a flat 403 to every request from the Worker's Cloudflare IPs, and
the device-direct path added to work around it was never verified against live Reverso data. It is
also a terms-of-service problem (no official API, no reverse engineering). It is out of scope —
see `docs/idea-brief.md` §5.

The one thing to be careful about: **the popup is not Reverso's.** `ReversoInfoPopupContent` renders
*two* sections — a Google Translate dictionary block (`_buildGoogleSection`, driven by the
`googleInfo` prop and `lib/services/google_translate_service.dart`) and a Reverso block
(`_buildReversoBody`). Only the second one goes. The popup itself, the Google section, the tappable
chips that fill the Translation field, and the dots-button behaviour all stay working.

Do the following:

1. **Worker** — delete `vocab-photo-api/src/reverso.ts`, drop the `/reverso-context` and
   `/reverso-translation` entries from the `ROUTES` map in `vocab-photo-api/src/index.ts`, and
   delete `handleReversoContext` / `handleReversoTranslation` and the now-unused import at the top
   of the file. `/analyze` is the only route left. Note that both deleted handlers carried a
   `// TEMPORARY:` comment about leaking upstream error internals into the response body — that
   concern leaves with them, and no other handler does it.
2. **Worker README** — delete the whole `## Reverso enrichment endpoints` section from
   `vocab-photo-api/README.md`. Replace it with nothing; do not leave a "removed" placeholder. In
   the `## Endpoint` section, make sure nothing still implies more than one route exists.
3. **App: strip the Reverso half of the popup** — in `lib/widgets/reverso_info_popup.dart`, delete
   `_buildReversoBody`, the `_info` / `_error` / `_loading` state, `_fetch`, `initState`'s fetch
   call, the `ReversoService` field, the `cachedInfo` and `onFetched` constructor params, and the
   `Retry` button in the footer (it only ever retried the Reverso fetch). `_buildBody` reduces to
   the Google section. Keep `_SectionHeader`, the close button, `onSelectTranslation`, and the
   scroll/constraint layout as they are. The widget becomes stateless in behaviour — convert it to
   `StatelessWidget` if nothing transient is left.
4. **App: rename what's left** — the widget is now a translation-options popup, not a Reverso one.
   Rename the file to `lib/widgets/translation_options_popup.dart` and the class to
   `TranslationOptionsPopupContent`. Use `git mv` so the rename survives in history.
5. **App: delete the clients** — delete `lib/services/reverso_service.dart` and
   `lib/models/reverso_info.dart`.
6. **App: clean up the call site** — in `lib/screens/word_input_screen.dart`, remove the three
   Reverso imports (lines ~19–21), delete the `_reversoInfoCache` list and **every** place it is
   touched: its declaration (~line 62), the invalidation in the word-controller listener (~174),
   the `add` in `_addControllersForIndex` (~215), the top-up loop in `_ensureRowStateSynced`
   (~260), the reset at ~882, the `removeAt` at ~898, and the reorder swap at ~944–946. Then fix
   the `ReversoInfoPopupContent(...)` construction at ~398 to the renamed widget without its
   dropped props. `_googleInfoCache` is a separate list and stays — do not delete it by symmetry.
7. **Dependency** — `package:html` is imported by exactly one file, `reverso_service.dart`. Once
   that file is gone, drop `html:` from `pubspec.yaml` and run `flutter pub get`.
8. **Empty-popup check** — with Reverso gone, the popup can now render an empty body: the dots
   button shows as filled whenever `_hasTranslationOptions[index]` is true, but `googleInfo` is
   null until the Translation lightning action has run for that row. Decide and implement what the
   popup shows in that state — either a one-line "Tap the lightning icon to load translations"
   message, or make the dots button not open at all without a Google result. Pick one, implement
   it, and say which in the commit message. **Do not ship a popup that opens onto nothing.**

Do not add a replacement information source in this task. What fills the freed word-detail slot is
open decision **D3** and is task-09's question.

## Acceptance criteria

- [ ] **AC-1** `grep -ri reverso lib/ vocab-photo-api/src/ pubspec.yaml` returns no matches.
- [ ] **AC-2** `grep -ri reverso vocab-photo-api/README.md` returns no matches.
- [ ] **AC-3** `grep -rn "package:html" lib/` returns no matches, and `html:` is absent from
      `pubspec.yaml`.
- [ ] **AC-4** `flutter analyze` exits 0 with no warnings about unused imports or dead code.
- [ ] **AC-5** `cd vocab-photo-api && npm run typecheck` exits 0.
- [ ] **AC-6** `ROUTES` in `vocab-photo-api/src/index.ts` has exactly one key: `/analyze`.
- [ ] **AC-7** Against a running Worker (`npm run dev`), both retired routes 404 —
      `curl -s -o /dev/null -w '%{http_code}' -H "x-app-secret: <secret>" "http://localhost:8787/reverso-context?word=receipt"`
      prints `404`, and the same for `/reverso-translation`. (A `401` means you forgot the header;
      the secret check runs before routing, so use a valid one or the test proves nothing.)
- [ ] **AC-8** `/analyze` still works: post a real photo per the `curl` in `vocab-photo-api/README.md`
      and get a `200` with a non-empty `words` array.
- [ ] **AC-9** On device: type a word, tap the Translation lightning icon, then tap the dots. The
      popup opens showing the Google dictionary sections grouped by part of speech, and tapping a
      chip fills the Translation field. No Reverso section, no "REVERSO" header, no EXAMPLES
      section, no Retry button.
- [ ] **AC-10** On device: with a row whose dots show filled but whose Google result was never
      fetched, the popup behaves as decided in step 8 — it shows a message or does not open. It
      never opens onto a blank black box.
- [ ] **AC-11** On device: add three rows, drag to reorder them, delete the middle one. No
      `RangeError`, and each row's word/translation/dots state follows the row it belongs to. (The
      per-row state is a set of parallel lists indexed in lockstep — removing one list is exactly
      where this breaks.)
