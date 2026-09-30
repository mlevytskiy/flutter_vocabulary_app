# Device pass — words-from-subtitles (T13)

> **Status: not run yet.** Fill this in on the owner's phone against the deployed Worker (README
> "Deploying words-from-subtitles"). 4 models × 5 films is exactly the daily cap of 20, so
> spread it over two UTC days (sad §11).
> Targets: [spec §6](../spec.md), [sad §10 QG-1 / QG-2](../sad.md).

Films (≤ 2 h of subtitles each, English `.srt` / `.vtt`):

| # | Film | File size | Lines after stripping |
|---|---|---|---|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

## Time to results dialog, maximum 20, Sonnet 5 — target p95 ≤ 30 s

| Film | Time (s) | Words shown | ≤ 20? | Full list or AC-12 message? |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

**p95:** ___ s → met / missed

## Maximum 100, per model — no hard target, measured

| Film | Sonnet 5 (s / words / ≈ $) | Sonnet 5.5 | Haiku 4.5 | Opus 5.5 |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

Partial lists shown: ___ (target 0).

## Ranking stability (AC-19, sad §11)

One film, "understand this film", maximum 20 then maximum 30, per model: are the 20 words of the
first import the top 20 of the second?

| Model | Same top 20? | Differences |
|---|---|---|
| Sonnet 5 | | |
| Sonnet 5.5 | | |
| Haiku 4.5 | | |
| Opus 5.5 | | |

If it drifts: record it and raise the sad §11 fallback (rank once, cut on the phone) with the owner.

## Ordinary rows everywhere (AC-17)

| Place | Subtitle words look like typed words? |
|---|---|
| Words table | |
| History (reopen the session) | |
| Shared link (partner page) | |
| Shared file (AnkiDroid export) | |

## Also check on the device

- [ ] The system file chooser opens from "Choose file" and returns an `.srt` file (T10 DoD).
- [ ] A 1 MB + 1 byte file gets "The largest file accepted is 1 MB" (AC-11).
- [ ] The 11th import in 10 minutes gets "Too many subtitle imports…" (AC-14).
