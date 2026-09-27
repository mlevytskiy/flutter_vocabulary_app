---
status: Accepted
owner: "Maksym (Tech Lead)"
reviewers: ["Maksym (Tech Lead)"]
updated_at: "2026-09-27"
feature_size: "M"
ticket: "docs/features/good-looking-web/spec.md"
---

# 0007 — Call the translation endpoint from the partner's browser

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Maksym (owner) with Claude during the design walk

## Context

Translation lightnings on the shared page (US-08, US-09) need a source of translations. The app uses Google's undocumented `translate.googleapis.com/translate_a/single` endpoint from the phone. A server-side call to a free service may be blocked, as happened with Reverso (spec OQ-1). Whether the endpoint answers a browser on another origin (CORS) could not be confirmed during design: from the design machine it answered 429 (too many requests).

## Decision drivers

- spec §1 and AC-18: translation autofill costs no dictionary quota and is not metered.
- spec OQ-1 default (resolved at clarify 2026-09-27): call the free service from the partner's browser.
- sad §1 quality goal 2: the Worker's public surface stays bounded.

## Considered options

1. **From the partner's browser** — the page script calls the endpoint directly, parsing the answer the way the app does.
2. **Through the Worker** — the page asks the Worker, which calls the endpoint from Cloudflare's addresses, with its own limit and a cache.

## Decision outcome

**Chosen:** option 1, gated by a spike as the first task: a page served by `wrangler dev` must get a translation from the endpoint in Chrome and Safari. Translation autofill then runs outside the allowance and outside the Worker, and the page's content-security policy allows exactly that one origin. If the spike fails, this ADR is superseded by option 2.

## Consequences

**Positive**
- No server quota, no counter, no new Worker route for translation.

**Negative**
- An undocumented endpoint can change, throttle or refuse browsers without notice; the page then shows "nothing found" or an error for translation lightnings while definition autofill keeps working.

**Neutral**
- The fallback (option 2) adds one route and one counter in D1 and needs a new ADR.

## Links

- Spec: [[../spec.md]] US-08, US-09, AC-16, AC-17, AC-18, §8 OQ-1
- SAD: [[../sad.md]] §3, §4, §11

## Spike result

**2026-09-27 — T1 passed: the endpoint answers a page script in all four target browsers.**

Setup: `vocab-photo-api/spike/translate.html`, served by `npx wrangler dev -c spike/wrangler.jsonc --ip 0.0.0.0` (port 8791, reachable from a phone on the same Wi-Fi at `http://<mac-lan-ip>:8791`). The page's own script calls `translate_a/single?client=gtx&sl=en&tl=uk&dt=t&q=<word>` with plain `fetch`, one word every 400 ms, and parses `data[0]` the way `translate_response_parser.dart` does.

| Browser | Result | 429s | Notes |
|---|---|---|---|
| Chrome 154, macOS | **19 / 20** — CORS allowed, body readable | none | all 20 answered HTTP 200 |
| Opera 135 (Chromium 151), macOS | **19 / 20** | none | extra run, same engine as Chrome; identical answers, including `recieve` → `отримати` and `blorptastic` echoed |
| Safari 26.6.2, macOS | **19 / 20** | none | identical answers |
| Safari 26.6.1, iOS 18.7 (iPhone) | **19 / 20** | none | identical answers; page reached over LAN |
| Chrome 153, Android 10 | **19 / 20** | none | identical answers; page reached over LAN |

Findings:

- **CORS:** a page script on another origin can read the response — no preflight needed for a plain GET.
- **Response shape:** unchanged from the app — `[[["яблуко","apple",…]],null,"en",…]`; `data[0][*][0]` joined is the translation, `data[2]` the detected language.
- **Misspellings are auto-corrected**, not reported: `recieve` → `отримати`. So AC-17 will fire only for words the service cannot map at all.
- **"Nothing found" = the word echoed back:** `blorptastic` → `blorptastic` (HTTP 200). T15 must treat a translation equal to the word (case-insensitive) as "nothing found for this word" (AC-17).
- **Server-side calls are refused:** from the same Mac, `curl` gets HTTP 429 ("automated queries") even with a browser user agent, while the browser gets 200. Evidence against option 2 (Worker proxy) as a fallback: Cloudflare's addresses may be throttled the same way.

**Verdict:** option 1 holds — Chrome and Safari, desktop and phone, each translated 19 / 20 (the 20th is the deliberate nonsense word, correctly reported as not found), with no 429s and no CORS error. ADR-0007 stays Accepted; T15 may proceed. The echo rule above is the AC-17 detection rule for translation lightnings.
