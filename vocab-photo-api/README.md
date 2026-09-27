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
| `POST /sessions` | secret + rate limit | publish a word list, get a link |
| `POST /sessions/<id>/sources` | secret + rate limit | attach a photo to a published session |
| `GET /s/<id>` | **public** | the page a person reads |
| `GET /s/<id>/sources/<sourceId>` | **public** | the bytes of one attached photo |

Every route in `src/index.ts` declares `public: true` or `false` for itself
(`src/routing.ts`). Anything not marked public is behind the `x-app-secret` check and
the per-IP rate limiter; a route added without thinking about it is therefore
secret-gated, and making one public is a visible, per-route decision.

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
[`../docs/roadmap.md`](../docs/roadmap.md#decisions-so-far)): the KV document is written
with `expirationTtl` and simply disappears, so there is no delete endpoint and no
"anyone holding the URL can destroy the list" surface. Attaching a photo keeps the
original expiry (the document is rewritten with the same absolute `expiration`).

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

Body: `{ "detail": "translation|definition|both", "entries": [ { "word": "…", "translation": "…", "definition": "…" }, … ] }`
as JSON. `detail` (the app's word detail mode when publishing) and `definition` are optional —
older apps send neither, and a document without `detail` reads as `translation`. Rows where
every field is blank are dropped (the app keeps a trailing empty row by design); a list that
is empty after that is a `400`. Caps: 256 KB body (`413` over it), 500 entries, 500 characters
per field — a too-long definition is a `400` whose message names the word.

```bash
curl -X POST "https://<your-worker>.workers.dev/sessions" \
  -H "content-type: application/json" \
  -H "x-app-secret: <secret>" \
  --data '{"entries":[{"word":"receipt","translation":"квитанція"}]}'
```

Answer (`200`): `{ "id": "<uuid>", "url": "https://<your-worker>.workers.dev/s/<uuid>", "expiresAt": "…" }`

### `POST /sessions/<id>/sources` — secret-gated

Attaches a photo. Same contract as `/analyze`: the **raw image bytes** as the body,
`content-type: image/jpeg|png|webp`, ≤ 7 MB (`413` over it). At most 10 sources per
session. Unknown session → `404` JSON. Answer: `{ "sourceId", "url", "pageUrl" }`.

The app does not call this yet — it keeps no copy of the photo after `/analyze` — so
today a published page shows the table only. The route is here so wiring it up later is
an app change, not a Worker change.

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
`npx wrangler tail`.

### `GET /s/<id>/sources/<sourceId>` — public

The bytes of one attached photo, with its stored content type and a long
`cache-control` (the id is random and the object never changes).

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
  3 definition, 4 tags (always empty). The column the word detail mode hides is written
  **empty** — translation mode leaves 3 empty, definition mode leaves 2 empty, both fills
  2 and 3. A column never changes meaning between exports. The page's file follows the
  session's `detail`; the app's export follows the current mode.
- Each field: runs of tabs/newlines collapse to one space, the result is trimmed, then
  `&`, `<`, `>` become `&amp;`, `&lt;`, `&gt;` (`#html:true`).
- A record whose word, translation and definition are all blank is never written.

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

## Rate limiting

`wrangler.jsonc` configures a per-IP limit of 20 requests / 60 seconds via the Workers
Rate Limiting binding, as a backstop against runaway Anthropic API costs. Adjust
`simple.limit` / `simple.period` there if needed (`period` must be `10` or `60`).

It applies to the **secret-gated** routes only (`/analyze`, `POST /sessions`,
`POST /sessions/<id>/sources`). The public page and its photo are plain KV/R2 reads and
are not rate-limited, so a partner refreshing the page never hits `429`.

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
