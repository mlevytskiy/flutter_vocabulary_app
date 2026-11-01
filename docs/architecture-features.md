# Feature data flows — flutter_vocabulary_app

Moved here from `docs/architecture.md` §3 on 2026-10-30. Read the section for the feature you touch.

## Import from Quizlet (import-from-quizlet)

The red + menu's "Import from Quizlet" (it took the old Screenshot item's place; the `screenshot`
package is gone) runs `runQuizletImport` in `quizlet_import_flow.dart`:

1. `showQuizletLinkDialog` finds a set link in the pasted text and reduces it to the plain
   `https://quizlet.com/<id>/<name>/` (`quizlet_link.dart`).
2. `showQuizletProgressDialog` opens that page in a `webview_flutter` view (JavaScript on, no
   JavaScript channel, top-level navigation only to that set's Quizlet pages). On every tick
   `QuizletReadController` runs `quizlet_page_script.dart` and hands the raw JSON to
   `parseQuizletPage`; the first read with cards of the pasted set ends the wait. No cards within
   30 s (the clock stops while a robot check is on screen) is one failure message; Cancel/Back is
   silent.
3. Still inside the progress dialog, `quizlet_cards.dart` turns the cards into proposed words (term
   as the word; a back whose letters are at least half Cyrillic as the translation, any other back
   as the definition; the example in the definition; at most 500 characters per field; duplicates
   and words already in the session left out). Nothing is machine-translated: a field the card does
   not fill stays empty, so its lightning looks like a typed word's.
4. `showQuizletResultDialog` shows the set name and the cards. Done with at least one kept word
   adds them to the session via `addWords`, linked to a new `SessionSource(kind: set, name, url)`;
   a result for a session other than the current one at Start is dropped.

Sources and publishing: a session's `sources` hold photos and sets in one list. The old cap of 10
photos is gone; publishing declares every source that has a linked row, bounded only by the Worker's
500 entries and 256 KB. Sets with a linked row are always published; the "Include photos (N)"
switch publishes or hides the photos only; only photos are uploaded afterwards (`photo_upload_service.dart` skips sets, which have no
bytes). The Worker side is in `vocab-photo-api/README.md`; the design is in
`docs/features/import-from-quizlet/sad.md`.

## Mnemonic story (mnemonic-story)

The learn page now groups the session's words to learn into word groups of 7 to 19 (a smaller
session is one group, "All words"). `word_grouping.dart` decides locally what it can
(`GroupingLocal`) and asks the Worker's `POST /story/grouping` (a cheap Haiku call, not counted
against the allowance) only when it must split words by topic (`GroupingAsk`); it re-runs only when
`groupedWordsKey` of the session changes. Start with Mnemonic story ticked opens `StoryScreen` for
the selected group (Start stays disabled until a group is selected).

The story is a Ukrainian story path (one sentence per word, English word inside, joined by "→") and its
picture is one illustration of small connected panels, each with a caption banner carrying that sentence.
The picture prompt writer AI returns only JSON `{character, scenes[]}` (one scene per sentence); the Worker
splits the story on "→" and assembles the final image prompt in code (`buildPicturePrompt` in
`src/story/prompts.ts`), so the captions reach the picture maker verbatim. That assembled prompt is what the
prompt step stores, the picture step sends and the app shows; unparseable JSON fails the prompt step. The
default picture maker is Grok Imagine 2.0 ($0.08, 2k, medium quality); a model may carry a `request` object
in `models.json` that the xAI adapter merges into the request body (never sent to the app).

A story run is made on the Worker, not the phone: `StoryRunTracker.startFor` takes a run id (a UUID
the app makes), POSTs `/story/runs`, and the Worker's `StoryRunWorkflow` (story writer -> picture
prompt writer -> picture maker, no retries on paid steps, word check after the story) records every
step and its price in D1. The phone polls `GET /story/runs?ids=` every 5 s while a story screen is
open or runs are uncollected, copies finished runs into Isar `StoryRun` and the picture into
`mnemonic_pictures/`, after which the Worker's copy is no longer needed (it is deleted after 7 days
at most). So a closed app loses nothing, and a saved story opens from the phone alone. Runs are never
removed from the phone.

The three AIs come from the Worker's offered AI list (`GET /story/models`, from `src/story/models.json`),
fetched and cached in `shared_preferences` with a bundled fallback. Each picker lists them cheapest
first, with a secondary line of list prices; a stored choice that is no longer offered falls back to
the default (AC-13). What shipped is provisional for non-Anthropic models: the OpenCode Zen text
models (DeepSeek V4.1 Flash, GPT-5.4 mini) and the xAI and Higgsfield picture makers carry
`provisional: true` in `models.json` until the owner verifies ids and prices; their API keys are Worker
secrets (`OPENCODE_ZEN_API_KEY`, `XAI_API_KEY`, `HIGGSFIELD_API_KEY`). No story route is public
(`x-app-secret`), and at most 20 runs (starts plus "Draw again") start per UTC day for the whole app.
The Worker side is in `vocab-photo-api/README.md`; the design is in
`docs/features/mnemonic-story/sad.md`.

## Film dialogues (get-words-from-subtitles-improvment)

With "Get dialogues from subtitles" on, a subtitle import asks the Worker for words and up to 10
film dialogues in one request. The results dialog is unchanged; at Done the words are added and
`addImportDialogues` links each dialogue to the import's kept rows by `WordPair.rowId`
(`atDone`), all in one debounced save. Dialogues live in `WordCollection.dialogues` (`FilmDialogue`,
embedded, pager order). Every later save runs `afterEdit`: links only shrink, and a dialogue left
with no words goes (or stays hidden while its delivery is pending). The AC-05 matching rule exists
twice, in `src/story/word-check.ts` and `lib/core/dialogues/dialogue_match.dart`, pinned by one case
file both test suites read.

The main screen no longer shows dialogues (its pager was removed 2026-10-14; they will be shown
elsewhere later). On the learn page, grouping first gives
each dialogue a dialogue group (`WordGroup.dialogueId`, any size, never started on its own), then
groups the other words as before ("Other words" beside dialogue groups). "Dialogs from movie" opens
`DialogueScreen`, which draws the scene picture once as a story run of kind `scene` (picture prompt
writer then picture maker, no story step, one unit of the story allowance); the picture becomes
`FilmDialogue.scenePictureRunId` and is listed in Story runs.

A shared session gets its dialogues two ways. A publish or republish sends them with the words (rows
by position, pictures declared like photos). After that, `dialoguePushProvider` appends each new
import's rows and dialogues (`POST /sessions/<id>/dialogues`, keyed by an app-made import id) and
uploads each scene picture, retrying with growing pauses and on every app start; the delivery state
is on each `FilmDialogue`, so closing the app loses nothing. Words typed by hand still reach the link
only by a republish. The design is in `docs/features/get-words-from-subtitles-improvment/sad.md`.

## Mixed conversation missions (talk-mixed, owner 2026-10-24)

Talk now requests `mode: mixed` from `/learn/talk`. Two turns of short action choices
alternate with one speaking task for three rounds. `talk-mixed.ts` controls the cadence
and validates structured AI answers; `Talk` keeps selection attribution so a tapped
choice never counts as vocabulary recall, including on Retry. Mixed mode reads replies
aloud when enabled but only records after an explicit mic gesture. The final outcome
stays visible until See results. Old Worker responses retain the legacy Talk UI.
Details and tests: `docs/features/talk-mixed/spec.md`.


## Warm-up v2 (learn-warm-up-v2, owner 2026-10-31)

- Profile: level, goal and daily context live in one preferences value (`LearnerProfileStore`, ADR-0001) with the
  warm-up round and counters. They are edited in Learn settings and never shared, published or logged (AC-12).
- Round: `warm_up_plan.dart` is a pure plan (ADR-0002): the level intro only when no level is set, then a reaction and
  the main question, in random order inside rounds of three. The Learn flow walks it.
- Grammar every 5th warm-up: the counter adds 1 per finished warm-up and resets after an answered grammar question.
  The intro and grammar never share a warm-up. The chosen rule's name (fixed list) goes with the main dialog and the
  talk returns a verdict per reply, counted on the results page.
- Reaction call: one free `/learn/warm-up` reaction per answer, 2 s cutoff, fixed-line fallback, no retry (ADR-0003).
- Topics: the topics call takes the profile and mood; slot 3 may be a profile topic, enforced in Worker code
  (ADR-0004). Merged-away topic ids stay as permanent aliases (ADR-0006, AC-15).
- Events call: `/learn/events` accepts fixed names and values only (ADR-0007, AC-17).
- Deploy order: deploy the Worker BEFORE the app. An app that sends profile, rule or events to an old Worker
  would get rejected or ignored calls.
Details and tests: `docs/features/learn-warm-up-v2/spec.md`.
