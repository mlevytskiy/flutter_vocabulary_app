# vocab-photo-api

Cloudflare Worker that receives a photo from the Flutter app, sends it to Claude
(Anthropic) with a vocabulary-extraction prompt, and returns the detected English
words with Ukrainian translations. Keeps the Anthropic API key off the mobile device.

## Endpoint

`POST /analyze?context=<bool>&translation=<bool>&with_desc=<bool>&shortify_definishion=<bool>&limit=<int>`

All query parameters are optional. If none of `context` / `translation` / `with_desc`
are `true`, the worker defaults to `translation=true` (so a bare `POST /analyze` still
returns translations, matching earlier behavior). `limit` is a maximum, not a target:
if fewer words are found in the photo than `limit`, only the words actually found are
returned — the model is explicitly told never to pad or invent extra entries.

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

## Reverso enrichment endpoints (unofficial, best-effort)

Two extra endpoints call reverso.net's internal (undocumented) endpoints to enrich a
single word beyond what `/analyze` returns. These are **not an official Reverso API** —
there isn't one. They reverse-engineer reverso.net's own web/mobile requests, which
Reverso's terms of service prohibit (no reverse engineering, no integrating the service
into another product). Treat both as optional, best-effort enrichment: expect
occasional 403s / IP rate limiting, and don't build a required feature on top of them.
See the "Reverso" conversation in this session for the full legal/risk rundown.

`GET /reverso-context?word=<text>&from=eng&to=ukr`

Real bilingual example sentences (not AI-generated) for `word`, scraped from Reverso
Context's HTML via Workers' native `HTMLRewriter` (no cheerio/Node DOM dependency).
`from`/`to` are Reverso's 3-letter language codes, not ISO 639-1 (default `eng`/`ukr`).

```bash
curl "https://<your-worker>.workers.dev/reverso-context?word=receipt" \
  -H "x-app-secret: <secret>"
```

```json
{
  "examples": [
    { "source": "Keep the receipt in case you need to return it.", "target": "Збережіть квитанцію на випадок повернення." }
  ],
  "translations": ["квитанція", "чек", "розписка"]
}
```

`GET /reverso-translation?word=<text>&from=eng&to=ukr`

Reverso's own machine translation for `word`, from a plain JSON endpoint (no HTML
scraping involved, so it's less likely to silently break if reverso.net changes its
page markup). Useful as a second opinion alongside Claude's translation in `/analyze`.

```bash
curl "https://<your-worker>.workers.dev/reverso-translation?word=receipt" \
  -H "x-app-secret: <secret>"
```

```json
{ "translation": "квитанція", "allTranslations": ["квитанція", "чек", "розписка"] }
```

Both endpoints share `/analyze`'s `x-app-secret` auth and per-IP rate limit. An empty
`examples`/`translations` array, or a `502`, usually means Reverso rate-limited or
blocked the Worker's IP, or changed its page markup — not that no data exists.

## Setup

```bash
npm install
```

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
   ```

3. Deploy:

   ```bash
   npm run deploy
   ```

   Wrangler will print your live URL, e.g. `https://vocab-photo-api.<your-subdomain>.workers.dev`.
   Use `<that URL>/analyze` from the Flutter app, sending the same `x-app-secret` value
   you set in step 2.

## Rate limiting

`wrangler.jsonc` configures a per-IP limit of 20 requests / 60 seconds via the Workers
Rate Limiting binding, as a backstop against runaway Anthropic API costs. Adjust
`simple.limit` / `simple.period` there if needed (`period` must be `10` or `60`).

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
