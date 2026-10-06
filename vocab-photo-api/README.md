# vocab-photo-api

Cloudflare Worker that receives a photo from the Flutter app, sends it to Claude
(Anthropic) with a vocabulary-extraction prompt, and returns the **marked** English
words with Ukrainian translations. Keeps the Anthropic API key off the mobile device.
It also publishes a word list as a **public, read-only page** the app can hand out as a
link (task-05) — see [Shared sessions](#shared-sessions).

## Routes at a glance

| Route | Auth | What |
|---|---|---|
| `POST /analyze` | secret + rate limit | photo in, marked words out |
| `POST /define` | secret + rate limit | a word's dictionary senses (definition-mode) |
| `POST /subtitles/words` | secret + rate limit + subtitle import allowance | a subtitle file's dialogue lines in, ranked words out (words-from-subtitles) |
| `POST /sessions` | secret + rate limit | publish (or republish) a word list, get a link |
| `POST /sessions/<id>/sources/<sourceId>` | secret + rate limit | upload the bytes of a declared photo |
| `GET /s/<id>` | **public** | the page a person reads |
| `GET /s/<id>/sources/<sourceId>` | **public** | the bytes of one arrived photo |
| `GET /assets/page-<hash>.js` | **public** | the page's browser script (versioned, cached a year) |
| `POST /s/<id>/cells` | **public** + page write limit | save one cell with a revision check |
| `POST /s/<id>/rows` | **public** + page write limit | add a row when its first cell gets text |
| `POST /s/<id>/rows/delete` | **public** + page write limit | delete a row nobody changed meanwhile |
| `GET /s/<id>/changes?since=<rev>` | **public** | what changed after a revision (polling) |
| `POST /s/<id>/define` | **public** + page write limit | fill a row's empty Definition cell (metered) |

Every route in `src/index.ts` declares `public: true` or `false` for itself
(`src/routing.ts`). Anything not marked public is behind the `x-app-secret` check and
the per-IP rate limiter; a route added without thinking about it is therefore
secret-gated, and making one public is a visible, per-route decision. A public route that
writes also declares `pageWrite: true`, which puts it behind the page write limit
(see Rate limiting).

## Endpoint: `/analyze`

`POST /analyze?context=<bool>&translation=<bool>&with_desc=<bool>&shortify_definishion=<bool>&limit=<int>`

`/analyze` returns **only the words the photo shows as visually marked** — highlighter,
underline, circle, box, pen or pencil stroke, an arrow pointing at the word. An unmarked
word is never returned, however useful it looks, so a photo of a dense page with nothing
marked on it comes back as `{"words":[],"timings":{...}}` with status `200`. **That empty
array is a valid successful response, not an error** — the app shows its empty-result
state for it. Marked text that is not meaningful English vocabulary (numbers, single
letters, barcodes, UI chrome, Ukrainian words) is filtered out too, which is the other
way an empty array happens.

All query parameters are optional. If none of `context` / `translation` / `with_desc`
are `true`, the worker defaults to `translation=true` (so a bare `POST /analyze` still
returns translations, matching earlier behavior).

`limit` is a cap, not a target:

- Fewer marked words in the photo than `limit` → only the marked ones come back. The
  model is explicitly told never to pad or invent entries to reach the limit.
- More marked words than `limit` → the **first `limit` in reading order** (top to bottom,
  then left to right) are kept and the rest are dropped. There is no
  "most useful for a learner" ranking; the marks already say what the owner wanted
  (decision D2 in [`../docs/roadmap.md`](../docs/roadmap.md#decisions-so-far)). The
  server also truncates the response to `limit` as a cheap backstop against a runaway
  answer — the prompt, not that `slice`, is the mechanism.

The app sends `limit=20` (`_photoWordCap` in `lib/features/word_input/word_input_screen.dart`).

`translation` and `description` prefer any translation/definition already visible in
the photo (glossary, subtitle, dictionary entry) over one Claude invents itself.
`shortify_definishion=true` additionally asks Claude to shorten whichever translation
or definition it ends up using (from the photo or self-generated) as much as possible
without losing its meaning.

Headers:
- `content-type: image/jpeg` (or `image/png` / `image/webp`) — this **is** the image's
  media type, there is no separate `mediaType` field
- `x-app-secret: <APP_SHARED_SECRET>` — must match the secret configured on the Worker

Request body: the **raw image bytes**, not JSON/base64. For example:

```bash
curl -X POST "https://<your-worker>.workers.dev/analyze?translation=true&with_desc=true&limit=10" \
  -H "content-type: image/jpeg" \
  -H "x-app-secret: <secret>" \
  --data-binary @photo.jpg
```

Sending raw bytes (instead of base64-encoding the image into a JSON body) avoids the
~33% size overhead base64 adds, on the leg that matters most — the phone's upload. The
worker still base64-encodes the image once, server-side, only because Anthropic's API
requires it for the outbound call to Claude.

Success response (`200`) — each word object only contains the fields you asked for via
the query params:

```json
{
  "words": [
    { "word": "receipt", "translation": "квитанція", "description": "a printed proof of purchase" },
    { "word": "shelf", "translation": "полиця", "description": "a flat surface for storing items" }
  ],
  "timings": { "aiMs": 1380 }
}
```

`timings.aiMs` is how long the Claude API call itself took, measured server-side. It's
useful for telling apart "the model is slow" from "the phone's network is slow" — the
Flutter app subtracts this from its own end-to-end request time to show both.

Error response (non-2xx): `{ "error": "<message>" }`

## Endpoint: `POST /subtitles/words` (words-from-subtitles)

The contract is `docs/features/words-from-subtitles/contracts/openapi.yaml`; the code is
`src/subtitles/`. The app strips a subtitle file to its dialogue lines on the phone (ADR-0002)
and sends them as JSON with the `x-app-secret` header:

```json
{ "lines": ["I was reluctant to leave, but the tide was coming in."],
  "purpose": "understand_film", "level": "B2", "maximum": 20,
  "model": "claude-sonnet-5", "sessionWords": ["tide"] }
```

- `lines`: 1 or more strings of 1–200 characters, at most 1 MB (1,048,576 bytes) together.
- `purpose`: `understand_film` | `frequent_words`. `level`: `A1`…`C2`. `maximum`: 1–100.
- `model`: one of the allow-list in `src/subtitles/prompt.ts` (`SUBTITLE_MODELS`):
  `claude-sonnet-5` (the default in the app), `claude-sonnet-5-5`, `claude-haiku-4-5-20251001`,
  `claude-opus-5-5`. Each model's reasoning settings sit in `MODEL_SETTINGS` in the same file.
- `sessionWords`: the words already in the session, at most 500 of at most 500 characters.
  They are compared case-insensitively and never sent to the AI or logged.

One AI call ranks up to `maximum + 10` candidates most important first; the Worker drops the
session's words and repeats and returns the first `maximum`:

```json
{ "words": [{ "word": "reluctant", "translation": "неохочий",
              "description": "Unwilling and hesitant to do something.",
              "context": "I was reluctant to leave, but the tide was coming in." }],
  "model": "claude-sonnet-5", "timings": { "aiMs": 18450 },
  "usage": { "inputTokens": 31250, "outputTokens": 2140 } }
```

An empty `words` list means nothing qualified. Errors are `{ "error": "...", "code": "..." }`:

| Status | `code` | When |
|---|---|---|
| 400 | `bad_request` | a field missing or out of bounds (the allowance is not touched) |
| 400 | `unknown_model` | `model` is not on the allow-list |
| 401 | — | no or wrong `x-app-secret` |
| 413 | `too_large` | the lines total more than 1 MB, or the body more than 2 MB |
| 422 | `no_english_lines` | the model found no English dialogue |
| 429 | `too_many_imports` | over 10 imports in this address's 10-minute window, or over 20 today from all addresses |
| 429 | — | the shared per-IP rate limiter (see Rate limiting) |
| 502 | `words_not_picked` | the AI call failed, took over 225 s, was cut off or refused, or its reply was not a complete word list |

**The allowance** (ADR-0003, `src/subtitles/allowance.ts`): each import takes one unit from its
address's fixed 10-minute window and one from the UTC day's total, in one D1 batch, before the
AI call; a unit is not given back when the call fails. Raise `SUBTITLE_WINDOW_LIMIT` (10) or
`SUBTITLE_DAY_LIMIT` (20) there. The address is stored only as its SHA-256; the daily clean-up
deletes every window before the current one, so no hash lives a day. The day totals hold no
address and stay.

**Logs:** one `subtitle import` line per import (model, outcome, AI ms, words returned, input
and output tokens), or `subtitle import refused` (with `window` / `day`) / `subtitle import
failed` (with the reason). Never the lines or the session words. Spend is in the Anthropic
console.

## Shared sessions

Publish a word list once from the app, hand the link to the person across the table,
they open it in any browser. No account, no app install — **the link is the only
credential** (`docs/idea-brief.md` §5), which is why the session id is a
`crypto.randomUUID()` and never anything sequential.

A session lives for **30 days** (decision D4 in
[`../docs/roadmap.md`](../docs/roadmap.md#decisions-so-far)): the session is stored in the
`DB` D1 database with its `expires_at`, and from then on an expired session reads exactly
like an unknown id, so there is no delete endpoint and no "anyone holding the URL can
destroy the list" surface. Uploading a photo and republishing both keep the original expiry.
A cron trigger (`triggers.crons`, daily at 03:00 UTC, `src/session/cleanup.ts`) deletes the
sessions past `expires_at` together with their rows, photo slots and page autofill counters,
and logs `{"event":"expired sessions deleted","sessions":…,"rows":…,"sources":…,"counters":…}`.
A missed run only delays the clean-up: an expired session already reads as gone. Photo bytes
in R2 still age out through the bucket's lifecycle rule. Locally, `npx wrangler dev
--test-scheduled` and `curl "http://localhost:8787/__scheduled?cron=0+3+*+*+*"` run it. Links published
before D1 (good-looking-web) were KV documents written with `expirationTtl`: the first
open of such a link imports it into D1 with its original dates, and `SESSIONS` KV is
only read, never written.

The stored document is **source-agnostic** — a word table plus a tagged list of whatever
the words came from. A photo is one `{ "kind": "photo", ... }` item in `sources`, never a
top-level `photoUrl`; subtitle text would be another `kind`, not a schema change.

```json
{
  "id": "35ffe55d-907d-4540-a5bb-5bda856dc6f5",
  "createdAt": "2026-09-21T07:32:30.434Z",
  "expiresAt": "2026-10-21T07:32:30.434Z",
  "entries": [ { "word": "receipt", "translation": "квитанція" } ],
  "sources": [
    { "kind": "photo", "id": "676af069-…", "mediaType": "image/png", "bytes": 73, "addedAt": "…" }
  ]
}
```

### `POST /sessions` — secret-gated

Body as JSON:

```json
{
  "detail": "translation|definition|both",
  "entries": [ { "word": "…", "translation": "…", "definition": "…", "sourceId": "<photo id>" } ],
  "sources": [ { "id": "<photo id>", "order": 0 } ],
  "publishedId": "<id of an earlier publish>",
  "editToken": "<the token that publish returned>"
}
```

Only `entries` is required — older apps send nothing else and publish exactly as before.
`detail` (the app's word detail mode when publishing) and `definition` are optional, and a
document without `detail` reads as `translation`. Rows where every field is blank are dropped
(the app keeps a trailing empty row by design); a list that is empty after that is a `400`.
Caps: 256 KB body (`413` over it), 500 entries, 500 characters per field — a too-long
definition is a `400` whose message names the word.

**Photos (good-looking-web, ADR-0006).** `sources` declares photos: an id the app
chose (1–64 letters, digits or dashes) and a distinct `order`, the pager's order. A
recognised row names its photo in `sourceId`, which must be one of the declared ids (`400`
otherwise); a typed row has none. Each declared photo is stored as a *pending* slot until
its bytes are uploaded. With "include photos" off the app sends neither field, and no photo
path of the session answers anything but the gone page.

**Set sources (import-from-quizlet, ADR-0005, ADR-0006).** A source is a photo or a Quizlet
set, told apart by `kind` (`"photo"` | `"set"`; a source without `kind` is a photo, so older apps
publish unchanged). A set also carries `name` (1–500 characters) and `url`, the plain
`https://quizlet.com/<id>/<name>/` link, and nothing else: `{ "id", "order", "kind": "set",
"name", "url" }`. A set has no bytes, so it is *arrived* from the moment it is published and the
page shows it as one more page of the source pager with its name and link; only photos get an
upload. A wrong `kind`, a photo with a `name`/`url`, or a set without a valid `name`/`url` is a
`400` with `"code": "invalid_source"`. There is **no cap on the number of sources**: a source is
declared only with a linked row, so the bound is the 500 entries and the 256 KB body. Stored by
migration `0003_set_sources` (`kind`, `name`, `url` on `sources`; existing rows become
`photo`).

**Republish (ADR-0008).** Every publish answers with an `editToken`; the Worker keeps only
its SHA-256. Sending `publishedId` with that token overwrites the same link: the rows and
photo slots are replaced, `expiresAt` stays, and the session revision goes up and is
recorded as "replaced at" so open pages reload. An unknown or expired `publishedId`, a
link imported from KV (it has no token) or a wrong token publishes a **new** link instead.

```bash
curl -X POST "https://<your-worker>.workers.dev/sessions" \
  -H "content-type: application/json" \
  -H "x-app-secret: <secret>" \
  --data '{"entries":[{"word":"receipt","translation":"квитанція"}]}'
```

Answer (`200`): `{ "id": "<uuid>", "url": "https://<your-worker>.workers.dev/s/<uuid>", "expiresAt": "…", "editToken": "…" }`
— after a republish, the same `id`, `url`, `expiresAt` and `editToken`.

### `POST /sessions/<id>/sources/<sourceId>` — secret-gated

Uploads the bytes of a photo the publish declared. Same contract as `/analyze`: the **raw
image bytes** as the body, `content-type: image/jpeg|png|webp`, ≤ 7 MB (`413` over it). An
unknown or expired session, or a `sourceId` the session did not declare, is a `404` JSON and
nothing is stored. Once a photo has arrived, uploading it again answers the same and changes
nothing, so the app can retry freely. Answer: `{ "sourceId", "url", "pageUrl" }`.

### `GET /s/<id>` — public

Server-rendered HTML (`src/session/page.ts`) with its CSS inlined (`src/session/style.ts`);
the table is complete before any script runs (ADR-0002). Columns: row number, Word,
Translation, Definition, chosen from the data: a column with no text in any row collapses to
a narrow "+ Translation"/"+ Definition" control (AC-21, AC-22). Each column is capped by a CSS
custom property max width and longer text wraps, so rows grow taller, never the table wider.
Two layouts on one DOM, switched by a media query alone (AC-36): from **900 px** the table
sits beside a sticky photo pager; below it the table scrolls both ways inside its own box and
the page never scrolls sideways, with a stacked (or single) thumbnail photo button instead of
the pager. The breakpoint and the widths are provisional (spec OQ-5) and live at the top of
`style.ts`. Photos come from the declared slots in order; a slot whose bytes never arrived is
an empty placeholder; no slots, no photo area or button. A row with a blank word is marked
"not in the download — needs a word" (AC-31).

Every value from the request is HTML-escaped on render. Sent with `cache-control: no-store`
and a Content-Security-Policy (sad §8): `default-src 'none'`, scripts only from this origin,
the inline `<style>` allowed by its sha256, images only from this origin, `connect-src` this
origin plus `https://translate.googleapis.com`; plus `referrer-policy: same-origin` so the
link never leaks as a referrer. The page loads `src/session/client/page.js` (plain JavaScript
with JSDoc, checked by `npm run typecheck` through `tsconfig.client.json`), which wrangler
bundles as text (`rules` in `wrangler.jsonc`) and the Worker serves at
`/assets/page-<hash>.js` with a one-year immutable cache; only the current hash answers.
The script makes the cells editable in place: leaving a cell saves it through
`POST /s/<id>/cells`; the cell then shows a brief "saved", stays marked "not saved" with the
reason, or shows both values when someone else saved it meanwhile (see below). The plus
button adds an empty row at the end, stored through `POST /s/<id>/rows` once one of its cells
gets text; at 500 rows it says the list is full. The × in a row's number cell hides the row
with a 5-second Undo; only then is `POST /s/<id>/rows/delete` sent, and if someone changed the
row meanwhile it comes back with their text and a notice. Leaving the page within those
5 seconds deletes nothing.
A missing or expired id returns a **`404` HTML page** saying the list is gone — a human is
reading this URL, not a client.

### `POST /define` — secret-gated

Body: `{ "word": "…" }` (≤ 100 characters). The Worker asks the Merriam-Webster Collegiate
API with the `MW_API_KEY` secret (4 s timeout), keeps entries whose headword matches the word
(compounds like *direct current* are dropped when *direct* itself has entries) and answers one
of exactly three shapes — never Merriam-Webster's raw format:

- `200 { "outcome": "senses", "word", "senses": [ … ] }` — short senses, dictionary order.
- `200 { "outcome": "not_found", "word", "suggestions": [ … ] }` — spelling suggestions (≤ 5).
- `503 { "outcome": "unavailable", "error" }` — timeout, bad key, exhausted allowance, outage.

Successful answers are cached in the `DEFINITIONS` KV namespace for 30 days, keyed by the
lowercased word; misses and failures are never cached. One log line per lookup
(`define <cache hit|found|not found|unavailable> "<word>" <ms>`), readable with
`npx wrangler tail`. The app's lookups are not counted against the shared pages' daily
allowance (see `POST /s/<id>/define`). `MW_API_URL` (a var, unset in production) replaces the
dictionary's base URL; the tests point it at a local stub.

### `GET /s/<id>/sources/<sourceId>` — public

The bytes of one photo whose slot has arrived in this live session, with its stored content
type and a long `cache-control` (the id is random and the object never changes). A pending
slot, an undeclared or guessed id, a photo dropped by a republish and an expired session all
answer the gone page, whatever R2 still holds (AC-24).

## Editing a shared page (good-looking-web)

The page's routes are public: the link is the credential (sad §8). Each session has one
revision counter that goes up with every write, and every cell (`word`, `translation`,
`definition` of a row) remembers the revision of its last change (ADR-0004). A write applies
only while the cell is still at the revision the page saw, in one D1 transaction, so a save
either lands or comes back as a conflict. Every refusal is `{ "error", "code" }`: `error` in
plain words for the partner, `code` for the script. An unknown or expired id is always
`404 { "code": "gone" }`. Log lines are JSON (`{"event":"cell saved",…}`) with ids, codes and
counts, never cell text.

### `POST /s/<id>/cells` — public

Body: `{ "rowId", "field": "word|translation|definition", "value", "baseRev" }` — `baseRev` is
the cell's revision as the page last saw it. One cell per request; there is no batch route.
The value is stored exactly as sent (no trimming, no HTML stripping — the page escapes on
output), and a save never changes the row's photo link.

- `200 { "rowId", "field", "rev" }` — saved; `rev` is the cell's new revision.
- `409 { "code": "conflict", "field", "value", "rev" }` — the cell changed since `baseRev`;
  `value`/`rev` are what is saved now. Saving again with that `rev` as `baseRev` keeps the
  partner's own value. A row deleted meanwhile answers `409 { "code": "conflict", "deleted": true }`.
- `422 { "code": "field_too_long", "field", "limit": 500, "overflow" }` — more than 500 characters.
- `422 { "code": "list_full", "limit": 262144 }` — the session's cell text would pass 256 KB
  (UTF-8 bytes of every live cell). An edit that shortens a cell always lands.
- `404 { "code": "unknown_row" }` — no such row id in this session; `400 bad_request` — malformed.

### `POST /s/<id>/rows` — public

Body: `{ "rowId", "field", "value" }`. The page makes the row id (a UUID) when the plus button
is pressed, and sends this only once the row's first cell gets text (`value` must not be
empty), so a row nobody typed in never exists. The row goes at the end with every cell at the
new revision; further cells are saved with `/cells`, using that revision as `baseRev`.

- `200 { "rowId", "rev" }` — added. Retrying an add that already landed answers the same.
- `409 { "code": "conflict", "rowId", "word", "translation", "definition", "revs" }` — the id
  is already used by a row with other content (`deleted: true` if that row is deleted).
- `422 { "code": "rows_full", "limit": 500 }` — the list already has 500 rows (deleted rows
  don't count); `422 list_full` / `field_too_long` as for `/cells`.

### `POST /s/<id>/rows/delete` — public

Body: `{ "rowId", "revs": { "word", "translation", "definition" } }` — the three cell revisions
as the page saw them when the partner pressed delete. Sent once the 5-second Undo has run out.

- `200 { "rowId", "rev" }` — deleted at `rev` (also for a row that is already deleted).
- `409 { "code": "conflict", "rowId", "word", "translation", "definition", "revs" }` — someone
  changed the row meanwhile, so it stays; the body is the row as saved now.
- `404 { "code": "unknown_row" }`; `400 bad_request`.

### `GET /s/<id>/changes?since=<rev>` — public

The page polls this with the last revision it has seen (ADR-0005); the answer is one
consistent read and says what changed after it:

```json
{
  "rev": 7,
  "cells":   [{ "rowId", "field", "value", "rev" }],
  "rows":    [{ "rowId", "position", "sourceId", "word", "translation", "definition",
               "revs": { "word", "translation", "definition" } }],
  "deleted": [{ "rowId", "rev" }],
  "sources": [{ "id", "ord", "mediaType", "rev" }]
}
```

`rev` is the next cursor. `rows` are rows added after `since`, sent whole (also once edited
since; an old row whose three cells all changed may come this way too — apply both kinds by
row id). `cells` are single changed cells of other rows, `deleted` the tombstones, and
`sources` the photo slots whose bytes arrived (swap the placeholder for
`/s/<id>/sources/<id>`). If the list was republished after `since`, or `since` is ahead
of the list, the answer is `{ "rev", "reload": true }`: load the page again. A missing or
malformed `since` is `400 bad_request`; an unknown or expired id `404 gone`. Polling is not
rate-limited.

### `POST /s/<id>/define` — public

Body: `{ "rowId" }`. Looks up the row's word (cache first, as `/define`) and writes the first
sense that fits a cell (≤ 500 characters) into its Definition cell — only while that cell is
still empty, so a filled cell is never overwritten (AC-19). A column autofill is one request
per cell.

Metering (ADR-0003): every lookup takes one unit of the page's allowance (**50 per UTC day**)
and one of the all-pages share (**500 per UTC day**, half of Merriam-Webster's 1,000 — the
rest is kept for the app, whose `/define` is never counted). Both are taken in one D1
transaction, only while both are below their limits, so racing lookups cannot pass them. A
lookup counts whether it finds something or not; a filled, deleted or wordless row is refused
before it and costs nothing.

- `200 { "rowId", "field": "definition", "value", "rev" }` — filled.
- `429 { "code": "autofill_paused", "reason": "page|all_pages", "resumesAt" }` — today's
  allowance or share is spent; `resumesAt` is the next 00:00 UTC (show it in local time).
  Distinct from the write limit's `rate_limited`.
- `422 { "code": "nothing_found" }` — the dictionary has nothing for the word (unit spent).
- `409 { "code": "conflict", "value", "rev" }` — the cell has text (or `deleted: true`).
- `503 { "code": "dictionary_unavailable" }` — the dictionary did not answer (logged as
  `dictionary unavailable`, the spec §7 KPI).
- `404 unknown_row` / `gone`; `400 bad_request` (also for a row without a word).

Log lines: `autofill filled`, `autofill nothing found`, `autofill paused` (with the reason) —
never the word or the definition.

## AnkiDroid file format

The single spec for both writers: the app's export (`lib/features/words_table/anki_export.dart`)
and the page's download (`GET /s/<id>/words.txt`, `src/session/anki.ts`). Change one, change
the other, and this section.

```
#separator:tab
#html:true
#tags column:4
<word>\t<translation>\t<definition>\t<tags>
```

- **Fixed columns in every mode** (definition-mode ADR-0005): 1 word, 2 translation,
  3 definition, 4 tags (always empty). A column never changes meaning between exports.
  - The **app's export** follows the current word detail mode: the column the mode hides is
    written **empty** — translation mode leaves 3 empty, definition mode leaves 2 empty, both
    fills 2 and 3.
  - The **page's file** (good-looking-web AC-30) is built from the live rows in D1 at request
    time and carries whatever the page saved, whatever mode the session was published with: a
    column with no text anywhere (collapsed on the page) comes out empty in its place.
- Each field: runs of tabs/newlines collapse to one space, the result is trimmed, then
  `&`, `<`, `>` become `&amp;`, `&lt;`, `&gt;` (`#html:true`).
- The app never writes a record whose word, translation and definition are all blank. The
  page's file leaves out every row whose **word** is blank (a card needs a word, AC-31) — that
  includes a row whose cells were all cleared; the page marks such rows "not in the download".

Example, `both` mode:

```
#separator:tab
#html:true
#tags column:4
claim	заява	to ask for as a right	
```

**One-time AnkiDroid setup:** create a note type with three fields — *Word*, *Translation*,
*Definition* — and map the columns to them on import (column 4 → Tags). Files exported
before definition-mode (`#tags column:3`) still import into the old two-field note type.

## Setup

```bash
npm install
```

### Bindings (one-time, per Cloudflare account)

`wrangler.jsonc` declares two storage bindings for shared sessions. `wrangler dev`
simulates both locally under `.wrangler/state/` with no account setup; for production
create them once and paste the KV id into the config:

```bash
npx wrangler kv namespace create SESSIONS        # prints an id → put it in wrangler.jsonc "kv_namespaces"
npx wrangler r2 bucket create vocab-photo-sources
# R2 has no per-object TTL: age the photos out with their session.
npx wrangler r2 bucket lifecycle add vocab-photo-sources expire-sources --expire-days 30
```

The `SESSIONS` namespace exists and its id is in `wrangler.jsonc` (created 2026-09-21).

**Dictionary cache (definition-mode):** create it once and replace the placeholder id in
`wrangler.jsonc`:

```bash
npx wrangler kv namespace create DEFINITIONS     # prints an id → replace REPLACE_WITH_DEFINITIONS_NAMESPACE_ID
```

**Sessions database (good-looking-web, ADR-0003):** D1 bound as `DB`, schema in
`migrations/`. Create it once near the owner, replace the placeholder id in `wrangler.jsonc`,
then apply the schema:

```bash
npx wrangler d1 create vocab-sessions --location weur   # prints an id → replace REPLACE_WITH_VOCAB_SESSIONS_DATABASE_ID
npx wrangler d1 migrations apply DB --remote            # --local for wrangler dev
# Revert a migration by hand (never picked up by `migrations apply`):
npx wrangler d1 execute DB --local --file migrations/down/0002_subtitle_imports.sql   # newest first
npx wrangler d1 execute DB --local --file migrations/down/0001_sessions.sql
```

The `vocab-photo-sources` R2 bucket exists with the 30-day `expire-sources` lifecycle rule
(R2 enabled and bucket created 2026-09-21). The Worker still treats `SOURCES` as optional in
code: without the binding the photo routes answer `503` and everything else works.

### Local development

1. Copy `.dev.vars.example` to `.dev.vars` and fill in a real Anthropic API key and a
   secret of your choosing (`.dev.vars` is gitignored, never commit it):

   ```bash
   cp .dev.vars.example .dev.vars
   ```

2. Run the worker locally:

   ```bash
   npm run dev
   ```

3. Test it (replace `photo.jpg` with a real local image, and the secret with the value
   from your `.dev.vars`):

   ```bash
   curl -X POST "http://localhost:8787/analyze?translation=true" \
     -H "content-type: image/jpeg" \
     -H "x-app-secret: choose-a-long-random-string" \
     --data-binary @photo.jpg
   ```

### Deploy to Cloudflare

1. Log in once:

   ```bash
   npx wrangler login
   ```

2. Set the production secrets (you'll be prompted to paste each value):

   ```bash
   npx wrangler secret put ANTHROPIC_API_KEY
   npx wrangler secret put APP_SHARED_SECRET
   npx wrangler secret put MW_API_KEY        # Merriam-Webster Collegiate key (definition-mode)
   ```

3. Deploy:

   ```bash
   npm run deploy
   ```

   Wrangler will print your live URL, e.g. `https://vocab-photo-api.<your-subdomain>.workers.dev`.
   Use `<that URL>/analyze` from the Flutter app, sending the same `x-app-secret` value
   you set in step 2.

### Deploying definition-mode (checklist)

Order matters: an older Worker silently drops definitions and has no `/define` route, so the
Worker ships **before** any app build that publishes definitions or looks them up.

1. Answer the open licence question (definition-mode `sad.md` §11): may Merriam-Webster's
   free-tier text be cached, shown on a public shared link and exported? If not, remove the
   `DEFINITIONS` cache before deploying.
2. `npx wrangler kv namespace create DEFINITIONS` and paste the id into `wrangler.jsonc`.
3. `npx wrangler secret put MW_API_KEY`.
4. `npm run typecheck && npm run deploy`.
5. Smoke-test the live Worker:
   `curl -X POST <url>/define -H "x-app-secret: <secret>" -d '{"word":"tenacious"}'` → `senses`.
6. Open a link published **before** this deploy: it must render exactly as before.
7. Only now install the new app build.

### Deploying good-looking-web (checklist)

Release order (sad §7), each step backward compatible: **D1 → Worker → app build**. An older
app keeps publishing as before (no photos, no token) against the new Worker, and links published
to KV before the release import into D1 on first open.

1. **D1.** Create the database near the owner and put its id in `wrangler.jsonc` (done
   2026-09-27, `vocab-sessions`, id in the config), then apply the schema:

   ```bash
   npx wrangler d1 create vocab-sessions --location weur
   npx wrangler d1 migrations apply DB --remote
   npx wrangler d1 migrations list DB --remote      # → "No migrations to apply!"
   ```

2. **Bindings already in `wrangler.jsonc`** — nothing to create, but check before deploying:
   - the daily clean-up cron `0 3 * * *` (`triggers.crons`); after deploy it shows under the
     Worker's *Settings → Triggers* in the dashboard;
   - `PAGE_WRITE_LIMITER`, 300 page writes / 60 s per IP (see [Rate limiting](#rate-limiting));
     its `namespace_id` must not collide with another Worker on the account;
   - `SOURCES` → `vocab-photo-sources`.
3. **R2 lifecycle.** Confirm the 30-day rule is on the bucket (sad §11: a photo must not outlive
   its session by more than a day):

   ```bash
   npx wrangler r2 bucket lifecycle list vocab-photo-sources
   # → expire-sources, enabled, all prefixes, "Expire objects after 30 days"
   ```

4. **Worker.** `npm test && npm run typecheck && npm run deploy`.
5. **Smoke-test the live Worker:** open a link published before this deploy (it imports from KV
   and renders); publish from the current app build (no photos) and edit a cell on the page from
   two browsers.
6. **App.** Release the build with photo keeping, the "include photos" switch and republish.
   Publish a session with photos and check they appear on the deployed page.
7. **30 days after release** (every pre-release KV link has expired by then): remove the
   `SESSIONS` entry from `kv_namespaces`, the KV import (`importLegacySession` in
   `src/session/store.ts`) and `SESSIONS` in `src/env.ts`, and deploy.
   Put a reminder in the calendar on release day.

### Deploying import-from-quizlet (checklist, owner)

Release order (sad §7), each step backward compatible: **D1 → Worker → app build**. An older app
keeps publishing photos as before (a source without `kind` is a photo). The reverse order fails:
an old Worker refuses the `kind` field. Needs the owner's Cloudflare login; run from
`vocab-photo-api/`.

1. **D1 migration first.** Applies `0003_set_sources` (rebuilds `sources`, existing rows become
   `kind = 'photo'`):

   ```bash
   npx wrangler d1 migrations apply DB --remote
   npx wrangler d1 migrations list DB --remote      # → "No migrations to apply!"
   ```

2. **Worker.** `npm test && npm run typecheck && npm run deploy`.
3. **Publish check from the current store build** (the build *before* the Quizlet release, which
   sends photos without `kind`): publish a session with photos, upload them, open the link and
   check the photos show. Also open a link published before this deploy: it must render as before.
4. **Only now** release the app build with the Quizlet import and "Include sources".

Revert the migration by hand with `migrations/down/0003_set_sources.sql` (newest first, before
`0002`).

### Deploying words-from-subtitles (checklist)

Release order (sad §7): **D1 → Worker → app build**. An older app never calls the new route.

1. **D1.** Apply `0002_subtitle_imports` (the allowance tables):

   ```bash
   npx wrangler d1 migrations apply DB --remote
   npx wrangler d1 migrations list DB --remote      # → "No migrations to apply!"
   ```

2. **Worker.** `npm test && npm run typecheck && npm run deploy`. Nothing new to configure:
   the route uses `ANTHROPIC_API_KEY`, `APP_SHARED_SECRET`, the existing cron and the existing
   rate limiter. `ANTHROPIC_API_URL` and `SUBTITLE_AI_TIMEOUT_MS` are for tests only; leave them
   unset in production.
3. **Smoke-test the live Worker** (one import of the daily 20):

   ```bash
   curl -s https://<worker>/subtitles/words -H "x-app-secret: $APP_SHARED_SECRET" \
     -H "content-type: application/json" \
     -d '{"lines":["I was reluctant to leave, but the tide was coming in."],"purpose":"understand_film","level":"B2","maximum":3,"model":"claude-sonnet-5","sessionWords":[]}'
   ```

   It answers `200` with at most 3 words; `wrangler tail` shows one `subtitle import` line.
4. **App.** Release the build with the "From subtitles" speed-dial item.

### KPIs (spec §7, sad §7)

A weekly manual check; no automated alerts. The D1 counts cover live sessions only (the cron
deletes a session 30 days after its first publish), so read them as "the last 30 days".
Replace the date with the release day.

```bash
npx wrangler d1 execute DB --remote --command "<query>"
```

```sql
-- KPI 1: share of published sessions with ≥1 page write (save, add, delete, autofill).
-- A page write raises rev above replaced_rev; a publish or republish does not.
SELECT count(*) AS sessions, sum(rev > replaced_rev) AS edited,
       round(100.0 * sum(rev > replaced_rev) / max(count(*), 1), 1) AS edited_pct
FROM sessions WHERE created_at >= '2026-10-01';

-- KPI 2 (narrowed, sad §11): publishes that declared photos. A publish with the switch off
-- sends nothing about photos, so the denominator is every publish, with or without photos.
SELECT count(*) AS with_photos,
       round(100.0 * count(*) / max((SELECT count(*) FROM sessions WHERE created_at >= '2026-10-01'), 1), 1) AS pct
FROM sessions AS s
WHERE created_at >= '2026-10-01' AND EXISTS (SELECT 1 FROM sources WHERE session_id = s.id);

-- Photos declared but never uploaded (stay placeholders on the page).
SELECT status, count(*) AS n FROM sources GROUP BY status;

-- Definition lookups all shared pages spent per UTC day (stops at 500).
SELECT utc_day, used FROM all_pages_autofill ORDER BY utc_day DESC LIMIT 14;
```

From Workers observability (*Workers → vocab-photo-api → Logs*), filtered by the JSON `event`
field of the log lines (`src/log.ts`):

- **KPI 3, days the app's lightning failed:** days with `define unavailable` (the app's
  `/define`) or `event = "dictionary unavailable"` (a page's autofill). Target: none.
- **KPI 4, definition autofill fill rate (narrowed: translation autofill never reaches the
  Worker):** `autofill filled` ÷ (`autofill filled` + `autofill nothing found`). Target ≥ 85%.
- Cell save and autofill p95 (spec §6: ≤ 1.0 s, ≤ 3.0 s): request duration of
  `POST /s/*/cells` and `POST /s/*/define` in the Worker's metrics.

## Tests

```bash
npm test
```

`scripts/test.mjs` starts `wrangler dev` on a free port with fresh local bindings (a
throwaway `--persist-to` directory, so every run starts empty, with the D1 migrations
applied), runs
`node --test "test/**/*.test.mjs"` against it, and stops it. The secrets come from
`.dev.vars`, or `.dev.vars.example` when there is none. Shared helpers (`baseUrl`,
`appHeaders()`, `publish()`, `get()`, and `d1()` / `kvPut()` / `kvDelete()` for reading
and seeding the local state `wrangler dev` serves from) live in `test/helpers.mjs`. The tests only work through
`npm test`, because they need the address it passes in. The dictionary is a local stub
(`test/mw-stub.mjs`, passed to `wrangler dev` as `MW_API_URL` and a fake `MW_API_KEY`), so no
test uses the real Merriam-Webster quota, even with a real key in `.dev.vars`. The AI behind
`POST /subtitles/words` is a local stub too (`test/anthropic-stub.mjs`, passed as
`ANTHROPIC_API_URL` with a fake `ANTHROPIC_API_KEY`): the first dialogue line picks its reply
(`STUB:empty`, `STUB:no-english`, `STUB:cutoff`, `STUB:malformed`, `STUB:refusal`,
`STUB:error`, `STUB:slow:<ms>`), and `GET <stub>/__calls` counts the calls.
`SUBTITLE_AI_TIMEOUT_MS=3000` shortens the 225 s abort for the slow case. Code that only needs
`DB.prepare().bind()` and `batch()` (the allowance) is unit-tested against the real
migrations in `node:sqlite` through `test/sqlite-d1.mjs`, imported straight from `src/*.ts`
(Node 23 strips the types).

## Rate limiting

`wrangler.jsonc` configures a per-IP limit of 20 requests / 60 seconds via the Workers
Rate Limiting binding, as a backstop against runaway Anthropic API costs. Adjust
`simple.limit` / `simple.period` there if needed (`period` must be `10` or `60`).

It applies to the **secret-gated** routes only (`/analyze`, `POST /sessions`,
`POST /sessions/<id>/sources/<sourceId>`). The public page and its photo are plain D1/R2 reads and
are not rate-limited, so a partner refreshing the page never hits `429`.

The page's writes (`/s/<id>/cells`, `/s/<id>/rows`, `/s/<id>/rows/delete`, and the definition
autofill) share a second binding, `PAGE_WRITE_LIMITER`: 300 writes / 60 seconds per IP. That is
enough for two partners behind one router while one of them fills a column at 3 saves a
second (AC-35), and stops a script hammering the database. Over it the answer is
`429 { "code": "rate_limited" }`. Page reads and polling are not limited.

`npm test -- test/rows.test.mjs` runs one test file; `npm run test:long` also runs the
15-minute two-partner session.

## Notes

- The model used is `claude-sonnet-5` (better quality on definitions/translations/context
  than `claude-haiku-4-5`, at a higher cost — roughly $0.01–0.02/photo instead of ~$0.005).
  Change it in `src/index.ts` if you want to trade quality for cost either direction.
  Switching to `claude-haiku-4-5` is the single biggest lever for latency if speed ever
  matters more than answer quality.
- The system prompt is sent with `cache_control: { type: "ephemeral" }` (Anthropic
  prompt caching). Since the prompt only depends on the query params — which the app
  always sends the same way — it's byte-identical across requests, so after the first
  call within a rolling 5-minute window, Claude skips re-processing those tokens,
  shaving a bit of latency and cost off every subsequent call. This has no effect on
  the image itself (never cached, since every photo differs) or on answer quality.
- The `x-app-secret` header is a simple shared-secret check, not full authentication —
  enough to stop random internet traffic from hitting your endpoint and spending your
  Anthropic budget, not a substitute for real auth if this ever needs multiple users.
