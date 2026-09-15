# Task 09 — Extra word detail: recon, not build

|  |  |
|---|---|
| **Roadmap step** | [#9](../roadmap.md#steps) |
| **Size** | fog — no size and no shape yet |
| **Wave** | — (never enters a wave; what gets scheduled is the recon, not the work) |
| **Depends on** | **task-01** — it frees the word-detail slot this would occupy |
| **Blocked on** | **D3** — whether an English-description dictionary is the right thing for that slot at all |
| **Files** | `docs/roadmap.md` (D3, the step's size) · this file (findings) |
| **Status** | not started |

## This task does not write app code

It produces two things: an answer to D3, and enough evidence that step 9 can be given a real size.
If you find yourself editing `lib/` you are doing task-10, which does not exist yet. Write the
findings into a `## Findings` section at the bottom of this file, update D3 in
`docs/roadmap.md#open-decisions`, and replace step 9's `fog` size with a real one.

## Blocked on D3

> Whether an English-description dictionary is the right thing for the word-detail slot at all, and
> if so whether `dictionaryapi.dev` is accepted as the source.

The roadmap describes the recon leg as half-done: `dictionaryapi.dev` is live, key-less and
rate-limit-free, but nobody has looked at what its responses actually contain for the kind of words
this app collects — nor whether definition-in-English is the detail the owner wants.

## Read this before the recon: the slot may already be filled

Two things in the codebase change the shape of this question, and both were found after the roadmap
was written:

1. **The Worker already returns English definitions.** `/analyze` supports `with_desc=true` and
   `buildSystemPrompt` asks Claude for *"a short English definition of the word, fitting its
   meaning in this context"* (`vocab-photo-api/src/index.ts:71-77`). `VocabWord` already carries a
   `description` field (`lib/models/vocab_word.dart`). So a per-word English definition is not a
   missing capability — it is a field that already arrives.
2. **...except it never actually arrived, because of a bug.** `lib/services/vocab_photo_service.dart:48`
   sends `'with_desc': 'false'` when the flag is *true*, so the photo call site's
   `withDesc: true` has been silently getting nothing. **task-02 step 3 fixes this.**

That reordering matters: once task-02 lands, descriptions start coming back for real, from a model
that saw the whole page. A dictionary API only sees a bare word. For a learner collecting
*ambiguous* words — which `docs/idea-brief.md` §6 says are the ones most worth capturing — the
context-aware definition is plausibly the better one, and it costs no extra request.

**So run task-02 first, then look at what Claude's `description` gives you before evaluating any
dictionary.** D3 may resolve to "the slot is already filled, close step 9", which would be the
cheapest possible outcome.

## Prompt

Answer D3 with evidence. Do the following:

1. **Collect a real sample.** Take 15–20 words from actual capture sessions — photographed from
   course material, not invented. They must include the cases that break dictionaries: multi-word
   phrases (`pull through`, `run into`), inflected forms as they appear on the page (`receipts`,
   `running`), proper-ish nouns, and at least three words whose meaning depends on context
   (`charge`, `fine`, `run`).
2. **Look at what the existing path already gives.** For each sample word, record the
   `description` that `/analyze` returns with `with_desc=true` (post-task-02). Judge usefulness
   against one question: *does this help the owner remember the sense the word had on that page?*
3. **Probe `dictionaryapi.dev` with the same list.** `curl https://api.dictionaryapi.dev/api/v2/entries/en/<word>`
   for each. Record, per word: HTTP status, whether an entry exists at all, how many senses come
   back, whether the *relevant* sense is first, whether phonetics are present, and whether an audio
   URL is present (this overlaps D1 / task-04 — if a source serves both detail and audio, that is
   worth knowing before task-04 commits to on-device TTS).
4. **Count the misses honestly.** For a source with no rate limit and no key, coverage is the only
   real risk. How many of the 20 got nothing? Multi-word phrases are the expected failure — check
   them specifically rather than reporting an average.
5. **Check the terms.** The Reverso removal (task-01) happened partly for terms-of-service reasons.
   Confirm `dictionaryapi.dev`'s licensing and attribution requirements before recommending it, and
   note where its data comes from. Do not repeat the Reverso mistake of building on a source that
   cannot be used.
6. **Write the recommendation.** One of: *the slot is already filled by Claude's description, close
   step 9*; *add `dictionaryapi.dev` as a supplement, fetched per word on demand*; *fetch it in
   batch at capture time*; or *neither — the slot stays empty*. Include the per-word-on-demand vs
   batch-at-capture question the roadmap raises; it is a latency-and-cost trade-off and the sample
   above is what decides it.
7. **Size it.** If the answer is "build something", give step 9 an XS–XL size and note which files
   it would touch. If the answer is "close it", move step 9 to the roadmap's out-of-scope list with
   the reason.

## Acceptance criteria

- [ ] **AC-1** A `## Findings` section exists at the bottom of this file containing a table of the
      15–20 sample words with, per word: Claude's `description`, `dictionaryapi.dev`'s status,
      sense count, whether the relevant sense was first, and whether audio was present.
- [ ] **AC-2** The sample demonstrably includes at least 2 multi-word phrases, 2 inflected forms,
      and 3 context-dependent words, each labelled as such.
- [ ] **AC-3** A coverage number is stated as a fraction, not a vibe — "14/20 had an entry; 0/2
      multi-word phrases did".
- [ ] **AC-4** The findings state `dictionaryapi.dev`'s licence and attribution requirement, with
      the URL where it says so.
- [ ] **AC-5** **D3 in `docs/roadmap.md` is resolved** — moved out of the open-decisions table into
      "Decisions so far" with a one-line rationale and a link back to these findings.
- [ ] **AC-6** Step 9's row in the roadmap's steps table no longer says `fog`: it has a real size,
      or the step has been moved to out-of-scope with a reason.
- [ ] **AC-7** If a source is recommended, the recommendation names when it is fetched (per word on
      demand vs batch at capture) and why, referencing observed response times from step 3.
- [ ] **AC-8** `git diff --stat` for this task touches only `docs/` — no file under `lib/` or
      `vocab-photo-api/src/` changed.
- [ ] **AC-9** The recon explicitly answers whether Claude's existing `description` is sufficient.
      A recommendation that never compares against the capability the repo already has is not
      finished.
