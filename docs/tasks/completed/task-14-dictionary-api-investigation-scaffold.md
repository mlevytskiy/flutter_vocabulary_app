# Task 14 — Standalone investigation project scaffold

|  |  |
|---|---|
| **Roadmap step** | [#9](../../roadmap.md#steps) (recon for the "extra word detail" step) |
| **Size** | S |
| **Wave** | 7 (starts a new, app-independent lane) |
| **Depends on** | — |
| **Blocked on** | **D3** — whether an English-description dictionary is the right source at all |
| **Unlocks** | task-15, task-16 |
| **Files** | `investigations/dictionary-apis/README.md` (new) · `investigations/dictionary-apis/.gitignore` (new) · `investigations/dictionary-apis/.env.example` (new) · `investigations/dictionary-apis/data/words.json` (new) · `investigations/dictionary-apis/package.json` (new) |
| **Status** | **done 2026-09-24** — AC-1..AC-4 verified |

## The report

> want to use automode ... Check free and cheap english vocabulary api. ... It should be separate project - investigation. Web-page where I can see small description about each dictionary, table with info about how much cost to use them and table with info about 10 words that we try to get from them.

Create a standalone investigation project — separate from the Flutter app and the Worker — that will hold the API comparison. This task builds only the empty shell it grows into, so the later tasks have one agreed home and one agreed fixture.

## What is already there

The repo is a Flutter/Dart app plus one Cloudflare Worker (`vocab-photo-api/`). There is **no** JS/web tooling, no `investigations/` folder, and the root `web/` name is taken by Flutter's web target — so the new project needs its own top-level folder and must not reuse `web/`.

Secret handling has two patterns in this repo. The Worker's is the clean one: a committed `.dev.vars.example` template, a gitignored `.dev.vars`, and secrets never in committed config. The Dart pattern (`lib/config/vocab_api_config.dart`, "a gitignored constant" per `docs/architecture.md` rule 5) is **broken in practice** — the `.gitignore` line is commented out and the file is tracked. Copy the Worker pattern, not the Dart one.

The three "free" candidates that need no key (dictionaryapi.dev, datamuse, Wiktionary REST) can be probed immediately; the paid ones need keys that are held in the gitignored secrets file this task creates.

## What it should do instead

- One folder, `investigations/dictionary-apis/`, at repo root, next to `vocab-photo-api/`.
- A gitignored `.env` for keys, mirrored by a committed `.env.example` listing every key the project may need (`MERRIAM_WEBSTER_KEY=`, `OXFORD_APP_ID=`, `OXFORD_APP_KEY=`, `COLLINS_KEY=`, `WORDSAPI_KEY=`, `API_NINJAS_KEY=`, …).
- `data/words.json` — the frozen fixture: the ten test words below, each with a stable id and the intended gloss, so every provider is asked exactly the same thing.

  `tenacious` · `determinated` · `claim` · `roller coaster` · `flustered` · `think of one's feet` · `curse` · `direct` · `gated` · `circumstances`

  Two of these are worth a note in the fixture (do not silently "fix" them — record them): `determinated` and `think of one's feet` are not standard English (`determined`; `think on one's feet`). Keeping them as written is itself a finding: it tests how each API behaves on a misspelling and on an idiom.

## Blocked on D3

> Is an English-description dictionary the right replacement for Reverso's extra word detail, and is `dictionaryapi.dev` acceptable as the source?

This task builds the shell either way; only the *shortlist* in task-15 changes if D3 resolves against using a dictionary source at all. Nothing in this scaffold presumes the answer.

## Prompt

Read `CLAUDE.md`, `docs/architecture.md`, `docs/tasks/completed/task-15-*.md`. One commit.

1. **Create the folder.** `investigations/dictionary-apis/` at repo root. Add a `README.md` whose first line states what this project is (compare free/cheap English dictionary APIs for the vocab app's "extra word detail" need), how to run it (`npm install`, `cp .env.example .env`, `npm run probe`), and the current status.
2. **Add `.gitignore`** in the folder ignoring `node_modules/`, `.env`, `out/`, `*.log` — mirroring `vocab-photo-api/.gitignore`.
3. **Add `.env.example`** listing every provider key the project may ever hold, one per line, blank-valued, with a comment marking which providers need manual approval (Cambridge, Collins) so nobody waits on them by surprise.
4. **Add `data/words.json`** with the ten words as an array of `{ "id", "word", "note" }`; `note` carries the spelling/idiom caveat where relevant and is empty otherwise.
5. **Add `package.json`** with `"type": "module"`, a `probe` script stub, and scripts for `build` (page) and `serve`. Keep dependencies minimal — plan on Node's built-in `fetch`, no HTTP client package. Do **not** add the full provider list yet; that is task-15.
6. **Do not touch the Flutter app or the Worker.** No edits under `lib/`, `test/`, or `vocab-photo-api/`. If Flutter tooling would try to analyse the new folder, note it under Open points rather than changing `analysis_options.yaml`.

## Acceptance criteria

- [x] **AC-1** `investigations/dictionary-apis/` exists with `README.md`, `.gitignore`, `.env.example`, `package.json`, `data/words.json`; `git status` shows the key names only in `.env.example`, never a real value.
- [x] **AC-2** `node -e "JSON.parse(require('fs').readFileSync('investigations/dictionary-apis/data/words.json'))"` exits 0 and the file has exactly ten entries.
- [x] **AC-3** `git check-ignore investigations/dictionary-apis/.env` succeeds (the real secrets file is ignorable) while `.env.example` is tracked.
- [x] **AC-4** `flutter analyze` still exits with no *new* issues, and nothing under `lib/` or `vocab-photo-api/` changed.

## Open points

- Folder name: `investigations/dictionary-apis/` is a proposal. Owner may prefer `dictionary-api-compare/` or a `docs/`-adjacent home.
- Whether the built page ships as a plain static HTML file (zero-build, matching the repo's no-toolchain style) or under a tiny Vite project — deferred to task-17.
- The `determinated` / `think of one's feet` spellings are almost certainly typos in the owner's list; kept verbatim for now, flagged for the owner to confirm.
- `flutter analyze` does not look at the new folder (no Dart files there); its 9 infos are all pre-existing (`lib/features/word_input/widgets/MyCustomPopupMenuController.dart`, `test/dots_survive_word_focus_test.dart`). `analysis_options.yaml` untouched.
- `probe` / `build` / `serve` are `echo` stubs with no dependencies; task-16/17 replace them.
- `.env.example` also carries `DATAMUSE_KEY=` (keyless today, required from 2027 per the task-15 research).
