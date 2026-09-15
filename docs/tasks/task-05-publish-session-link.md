# Task 05 — Publish a session to a durable shared link

|  |  |
|---|---|
| **Roadmap step** | [#5](../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 3 (parallel with task-04 and task-08 — disjoint file sets) |
| **Depends on** | — |
| **Blocked on** | **D4** — session/photo lifetime and deletion · **D5** — one photo per session or a scrollable set |
| **Unlocks** | task-06, task-07 |
| **Files** | `vocab-photo-api/src/session/` (new) · `vocab-photo-api/src/index.ts` · `vocab-photo-api/wrangler.jsonc` · `vocab-photo-api/README.md` · `lib/screens/words_table_screen.dart` · `lib/services/` (new) |
| **Status** | not started |

## Blocked on D4 and D5

> **D4** — How long a shared session and its photos live, and whether anyone can delete one.
> **D5** — Whether the shared page shows multiple photos as a scrollable set, or one photo per
> session to start.

D4 is not a polish question, it is the storage design. A session with no expiry needs a delete path
and an answer to "anyone holding the URL can delete it" (`docs/idea-brief.md` §6 names this as a
risk); a session with a TTL gets that for free from the store and needs no delete endpoint at all.
**Recommended: a TTL (30 days), no delete endpoint in the first version.** Cloudflare KV takes an
`expirationTtl` directly, so the whole question collapses into one argument, and the risk the brief
worries about — an unauthenticated URL that lets anyone destroy the list — never gets built.

D5 decides whether the stored session holds one photo reference or a list. **Store a list either
way** and render one in the first version if that is the answer — a list that renders one item is a
UI decision, a single field that has to become a list is a migration.

Answer both in `docs/roadmap.md` before starting.

## Prompt

Publish the current word list to a URL the person across the table can open in a browser and read.
No account, no app install — a link is the only credential (`docs/idea-brief.md` §5).

Design the session **source-agnostic** from the start, as §7 of the brief insists: the stored shape
is "a word table, plus whatever the words came from". A photo is today's source; subtitle text is a
plausible next one. Do not name the payload `photo` or key the schema on images.

### The auth problem you must solve first

`vocab-photo-api/src/index.ts:341-344` checks `x-app-secret` in the `fetch` handler **before**
routing, so *every* route currently requires the shared secret. The shared page is public by
definition. So this task has to split the auth model: writes (from the app) stay
secret-gated and rate-limited; the public read route is reachable with no header at all. Restructure
the handler so each route declares whether it is public, rather than bolting on a path check —
something like a per-route `{ handler, public: true }` record. Getting this wrong in the "bolt it
on" direction is how the write endpoint ends up public too.

### Storage

The Worker carries **no KV, D1, R2 or Durable Object binding today** — only the rate limiter
(`wrangler.jsonc`). A persistent store is a new binding, and adding it is part of this task.
Recommended: **KV** for the session JSON (one key, one document, read-mostly, TTL built in), and
**R2** for photo bytes if D5 says photos are shown at all. Do not put image bytes in KV.

Do the following:

1. **Add the binding(s)** to `wrangler.jsonc` and to the `Env` interface in `src/index.ts`. Follow
   the existing comment style there — the rate-limiter block documents why it exists and what to
   change; do the same. Note the file's comment that secrets are set with `wrangler secret put`,
   not in the config.
2. **Define the session shape** in `vocab-photo-api/src/session/` — a new module, not more code in
   `index.ts` (it is already 354 lines). Roughly: an id, a created timestamp, an ordered list of
   `{word, translation}` entries, and a `sources` list whose items are tagged by kind (`photo`
   today). Keep the entry shape aligned with the app's `WordPair` (`lib/models/word_pair.dart`) and
   the Worker's existing `VocabularyWord` so nothing has to be translated between three shapes.
3. **`POST /sessions`** — secret-gated, rate-limited. Takes the word list, returns the session id
   and the public URL. Generate the id with `crypto.randomUUID()`; it is the only credential the
   page has, so it must not be sequential or guessable. Reject an empty word list with a 400. Cap
   the payload size the way `/analyze` caps image bytes (`MAX_RAW_BYTES`) — an unauthenticated read
   surface fed by a capped write surface is the only thing keeping this cheap.
4. **`GET /s/<id>`** — public, no secret. Returns an HTML page: the word table, the source
   alongside it. Server-rendered; do not add a frontend build step to a repo that has none. Plain
   readable HTML with inline CSS is the right amount of machinery here. A missing or expired id
   returns a 404 page that says the session is gone, not a JSON error blob — a human is reading
   this URL.
5. **Photo upload, if D5 says photos are shown.** `POST /sessions/<id>/sources` taking raw bytes
   the way `/analyze` does (the README explains why raw bytes rather than base64 — the same
   reasoning applies). Store in R2, reference it from the session document, serve it back through a
   public `GET` route. Reuse `/analyze`'s `ALLOWED_MEDIA_TYPES` and size cap.
6. **App side: a Share button that publishes.** `lib/screens/words_table_screen.dart` already has a
   Share action that writes a TSV to a temp file and opens the system share sheet (`_shareWords`).
   Add publishing next to it — do not replace the file share; the brief keeps the file as the
   guaranteed return path. Put the HTTP call in a new service beside `vocab_photo_service.dart`,
   reusing `VocabApiConfig` for the base URL and secret. On success, show the link and copy it to
   the clipboard; the point is handing the URL to someone in the next five seconds.
   - **Filter blank pairs before publishing.** `_wordPairs` always carries a trailing empty row
     (`_checkAndAddNewPair`), and `_generateCloseUpB2Format` currently writes it out as an empty
     TSV line. Do not repeat that bug on the shared page.
7. **Document it** in `vocab-photo-api/README.md` — the new routes, which are public and which are
   secret-gated, the TTL, and the new bindings in the `## Setup` section.

## Acceptance criteria

- [ ] **AC-1** `cd vocab-photo-api && npm run typecheck` exits 0; `flutter analyze` exits 0.
- [ ] **AC-2** `POST /sessions` with a valid secret and 5 word pairs returns `200` and a body
      containing an id and a URL.
- [ ] **AC-3** `POST /sessions` **without** `x-app-secret` returns `401`.
- [ ] **AC-4** `POST /sessions` with an empty word list returns `400`.
- [ ] **AC-5 — the public read.** `curl` the returned URL with **no headers at all** and get `200`
      and HTML containing all 5 words and their translations.
- [ ] **AC-6** `/analyze` still returns `401` without the secret — the auth restructuring did not
      make the expensive route public. Check this explicitly; it is the failure mode that costs
      money.
- [ ] **AC-7** `GET /s/<a-random-uuid-that-was-never-created>` returns `404` with a human-readable
      HTML page, not a JSON error.
- [ ] **AC-8** The session id in the returned URL is a UUID — not an incrementing number, not a
      short hash. Create two sessions back to back and confirm the ids are unrelated.
- [ ] **AC-9** Restart the Worker (`npm run dev` stopped and started) and re-fetch a session URL
      created before the restart — it still resolves. This is the difference between a store and an
      in-memory map.
- [ ] **AC-10** The stored session document has the word entries and the sources as **separate,
      tagged** structures — `jq` the raw KV value and confirm a photo is one entry in a `sources`
      list with a kind tag, not a top-level `photoUrl` field. This is the source-agnostic
      requirement, and it is the one thing here that is expensive to fix later.
- [ ] **AC-11** If D5 says photos are shown: upload a photo to a session and confirm it renders on
      the page next to the table, and that its public URL is reachable with no secret.
- [ ] **AC-12** A payload over the size cap returns `413`, not a 500.
- [ ] **AC-13** On device: tap the new publish action on the Words Table screen with 5 words
      entered. A link appears, is on the clipboard, and opening it in the phone's browser shows the
      same 5 words.
- [ ] **AC-14** On device: the shared page shows exactly the filled rows — no trailing blank row.
- [ ] **AC-15** On device: the original file Share action still produces the same TSV file it did
      before this task.
- [ ] **AC-16** On device, with the Worker unreachable (airplane mode): publishing shows a clear
      error message and the screen stays usable. No indefinite spinner.
- [ ] **AC-17** The page is readable on a phone browser held in portrait — the partner is reading
      it on their own phone, not a desktop.
