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
| `POST /sessions` | secret + rate limit | publish (or republish) a word list, get a link |
| `POST /sessions/<id>/sources/<sourceId>` | secret + rate limit | upload the bytes of a declared photo |
| `GET /s/<id>` | **public** | the page a person reads |
| `GET /s/<id>/sources/<sourceId>` | **public** | the bytes of one arrived photo |
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

**Photos (good-looking-web, ADR-0006).** `sources` declares up to 10 photos: an id the app
chose (1–64 letters, digits or dashes) and a distinct `order`, the pager's order. A
recognised row names its photo in `sourceId`, which must be one of the declared ids (`400`
otherwise); a typed row has none. Each declared photo is stored as a *pending* slot until
its bytes are uploaded. With "include photos" off the app sends neither field, and no photo
path of the session answers anything but the gone page.

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

Server-rendered HTML with inline CSS, written for a phone in portrait: the numbered word
table, then the attached photo(s). No build step, no framework. Every value from the
request is HTML-escaped on render. Sent with `cache-control: no-store` so the page never
shows stale words once it becomes editable (task-06). A missing or expired id returns a
**`404` HTML page** saying the list is gone — a human is reading this URL, not a client.

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
   `curl -X POST <url>/defcurl -X POST ine -H "x-app-secret: <secret>" -d '{"word":"tenacious"}'` → `senses`.
6. Open a link published **before** this deploy: it must render exactly as before.
7. Only now install the new app build.

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
test uses the real Merriam-Webster quota, even with a real key in `.dev.vars`.

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
