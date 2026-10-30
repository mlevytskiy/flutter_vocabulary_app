# Owner brief — learn-welcome and word-context (2026-10-30)

Decision page: https://claude.ai/artifact/8CJZbtjwD23XEAibdd7mz8

## The owner's words (condensed)

- Instead of the Learn sheet, Learn opens a short welcome dialog with AI on the Talk with AI interface, with a
  progress indicator so the learner sees it is short. No skip: the answers are needed to prepare the main dialog.
- The warm-up uses the talk's answer choices. Q1 "What topic do we want to speak about?": 3 topics from 50 prepared
  ones that fit the set's words best, plus "propose my own topic". Q2 "Hard work or easy mode?": the mode only
  sets how long the main dialog is, not its structure.
- No more groups of 7–12. After the warm-up: cards (Easy / Medium / Hard / I don't remember), flip to see the answer.
- After 12 cards, a mnemonic story page: one landscape picture (the text is inside the picture), in the same pager,
  between word cards. Ready → right after its words; not ready → a few more cards first; still not ready → a
  "we are generating your story, please wait" page. At most 3 stories per set of words.
- The phone splits the words (no slow AI answer): in list order, a group may be smaller than 12; when a group's last
  words come from another source (e.g. words 11–12 typed after 10 film words), they go to the next group.
- Stories use the extra information collected about each word.
- Only the story page is landscape; block auto-rotation everywhere else.
- Each word gets typeOfSource (manually entered, movie, image) and a detail per type: movie — movieName, season,
  episode, time (all may be empty), wasDescriptionEditByUser, wasTranslationEditByUser; image and manual — the two
  edit flags. Each word gets a "context": image — the sentence(s) where it is used (the AI returns the full text, or
  writes a sentence on an exercise sheet); movie — the parsed line; translation-only — empty; with a definition —
  from our context API. A film picked by name already has its full name, season and episode from the suggestion.

## The owner's picks

A1 warm-up straight away · A3 50 topics in the Worker, AI picks 3 · A4 Easy 6 replies / Hard 12 · A4b Easy about
half the words, Hard all · A5 up to 36 words from the first due or new word, list order · A6 card side per word
(stored, as in Self-check) · A7 ratings move the box with the Self-check rules · A8 another film/photo/set/typing
is another source · A8b up to 4 last words move (a group keeps ≥ 8) · A9 5 extra cards before the wait page ·
A10 reuse a saved story · A11 the screen turns by itself · A12 tablets locked like phones · A13 results with
Exercises · Talk with AI · Done · A14 remove the sheet and the split checkbox, keep Learn settings · A15 merge with
Self-check Cards · A16 the bar covers the warm-up only (2 steps), then a card counter · A17 wait page with a
progress bar and "Skip, show it later" · A18 main dialog after cards and stories · A19 own topic typed or said ·
A20 always ask both fresh.

B1 typed, movie, image, Quizlet set · B2 one embedded WordOrigin + context (rule 5 approved) · B3 old rows: type
from their source, else typed, flags false · B4 any change counts as edited · B5 a changed English word clears
context and flags, keeps the type · B6 start of the first line with the word · B12 file: season/episode from the
file name, empty if not found · B7 photo's full text on the photo + a sentence per word · B7b context marked
"from the source" / "written by AI" · B8 typed with a definition: dictionary example only, else empty · B9 backfill
at launch · B10 shown on the card back and in the Words screen popup (rule 3 approved) · B11 stories get context,
source and edited translations.

## Owner-proxy answers (Fable 5.1, 2026-10-30, delegated by the owner)

Q1 dialog words: Easy min(6, ceil(N/2)) and never fewer than 4; Hard min(12, N); today's "I don't remember" first,
then Hard, then list order. Q2 dialog results never move a box; missed/hinted words get the quick check's
self-check card. Q3 nothing due or new → the 36 words due soonest. Q4 under 4 words → snackbar "Add at least 4
words to learn"; 4–7 words → full flow, one group, one story. Q5 50 topics as a JSON constant `topics.ts` in the
Worker: {id, title ≤ 4 words, description, keywords 5–10}. Q6 `POST /learn/topics`, the talk mission's model, 3
ids; fails or > 4 s → 3 bundled topics (Daily routine, Food and cooking, Travel). Q7 warm-up and topic pick are
free; the main dialog is one talk; limit reached → dialog skipped, results say "Daily talk limit reached". Q8 a
skipped story shows at the next story slot, else before the main dialog, else only in Story runs with a note on
results. Q9 reuse = same set of rowIds and a finished story. Q10 results: Cards (counts per rating, box moves),
Stories (thumbnails), Talk (used / after hint / missed / unused), "N words due tomorrow", buttons. Q11 own topic:
Send disabled while empty, ≤ 80 characters, taken as it is. Q12 backfill: typed/set from the define API; film only
where the line is still stored; photos never re-analysed; 20 words a minute. Q13 set words: typed rule; a Quizlet
definition is never the context. Q14 context in italic with "from the source" (grey) or "written by AI" with the
sparkle in `AppDecor.aiAccent`. Q15 the mission picture is still made, during the cards. Q16 the popup is
read-only. Q17 leaving: the leave dialog asks; ratings are saved per card; running stories finish into Story runs;
warm-up and dialog progress are dropped.
