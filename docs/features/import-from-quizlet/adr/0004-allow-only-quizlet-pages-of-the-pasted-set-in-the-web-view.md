---
status: Accepted
owner: "Maksym (learner, app owner)"
reviewers: ["Maksym (Tech Lead)", "Maksym (Security Lead)"]
updated_at: "2026-10-06"
feature_size: "M"
ticket: "import-from-quizlet"
---

# 0004 — Allow only Quizlet pages of the pasted set in the web view

- **Status:** Accepted
- **Date:** 2026-10-06
- **Deciders:** Maksym (owner), with Claude during the design walk

## Context

The in-app page must open only Quizlet's own pages, strictly (spec §1 decision, AC-11): no adverts, store pages, other sites or robot checks served by another company as pages, and words read only from the set whose link was pasted. At the same time Quizlet's page needs its own scripts, images and possibly frames from other hosts (its CDN, its bot-protection provider), and Quizlet's own robot check must work (AC-05).

## Decision drivers

- sad §1 quality goal 2: contain the third-party page.
- spec §6.1 abuse case "made-up words from a non-Quizlet page".
- AC-05: Quizlet's own robot check must be passable inside the preview.
- `webview_flutter` reports top-level navigations reliably on both platforms; sub-frame reporting differs between iOS and Android (ADR-0002).

## Considered options

1. **Block top-level navigation outside Quizlet + lock on the set id** — allow a top-level navigation only to `https://quizlet.com` or a subdomain; cancel every other one; open no new windows; cancel a navigation to a different set's page; accept read results only when the set id on the page equals the pasted set's id. Sub-resources and embedded frames load as the page asks.
2. **Additionally block third-party frames** — cancel embedded frames from non-Quizlet hosts where the platform reports them.

## Decision outcome

**Chosen:** Option 1. "A page the learner is taken to" is a top-level navigation; that is what AC-11 forbids, and option 1 forbids it on both platforms identically. Blocking frames (option 2) behaves differently on iOS and Android and is likely to break Quizlet's own robot check, turning AC-05 into AC-07 failures. The set-id lock makes "words only from the pasted set" independent of navigation: even a same-site page change cannot feed another set's cards.

## Consequences

**Positive**
- One rule in one place (`onNavigationRequest`), the same on iOS and Android; unit-testable as a pure "is this navigation allowed" function.
- A robot check served by another company as a top-level page is cancelled → the wait runs out → AC-07, as the spec wants.

**Negative**
- Adverts embedded as frames still show inside the preview (they cannot take over the page).
- A redirect from the pasted link to a different Quizlet path that is still the same set (a language part, a study-mode URL) must be recognised as "the same set" — the set-id extraction is shared with the link parser (sad §5).

**Neutral**
- `http:` links, `intent:`/`itms-apps:` and other schemes are cancelled by the same rule.

## Links

- Spec: [[../spec.md]] §1 decision (strictly Quizlet), AC-05, AC-07, AC-11, §6.1
- SAD: [[../sad.md]] §3 trust boundary, §4, §8
- Related ADR: [[0002-show-the-set-page-with-webview-flutter]], [[0003-read-the-page-data-with-a-thin-script-and-parse-it-in-dart]]
