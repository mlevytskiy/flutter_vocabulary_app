---
status: Draft
owner: "Maksym (learner, app owner)"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-09-29"
feature_size: "XS"
---

# Spec — edit-session-from-history

> **Glossary:** [project CONTEXT](../../../CONTEXT.md)
> **Reference module / docs / channels used:** `lib/features/history/history_screen.dart` (History rows open the words table by session id) · `lib/features/words_table/words_table_screen.dart` (the table a History row opens) · `lib/features/word_input/word_input_notifier.dart` (the launch rule and RESTORE, which already make a stored session current) · `lib/core/services/session_store.dart` (the current-session pointer)

## 1. Context

A learner who opens an earlier session from History can only look at it and share it. The words table for a past session is read-only, and the main screen always works on the current session. To add words to an older list — say, the list from last week's lesson — the learner has to retype them into the current session, which leaves two half-lists behind.

Why now: History (task-10) and words that survive a restart (task-03) have shipped, so past sessions are kept and visible. The app can already bring an older session back as the current one, but only through the restore offer shown just after launch, and only for a few seconds. This feature makes that possible for any session in History, whenever the learner wants.

Committed approach: the words screen opened from a History row gets a red Edit button. Tapping it asks the learner to confirm. On Yes, the picked session becomes the current session and the learner lands on the main screen with its words, ready to edit. The session they leave keeps every word it had and stays in History.

- Decision (assumptions ledger, accepted 2026-09-29): the button is hidden when the session is already current; No changes nothing; the session being left is saved first (an empty one is dropped); Back from the main screen does not return to History; a shared link changes only when the learner shares again.
- Decision (clarify, 2026-09-29, owner): History stays ordered by real edits — picking a session does not move it. The app separately remembers when the current session was picked, and a relaunch within 5 minutes of that pick (or of the last edit) reopens it. Past 5 minutes the existing rule applies: a new empty session plus the restore offer. This replaces an earlier draft that re-stamped the edit time on pick.
- Decision (clarify, easy-depth assumption, 2026-09-29): a translation, definition or photo lookup still running when the learner switches is ignored when it returns; the picked session is never touched by it.

## 2. Goals

- The learner can carry on with any earlier session in two taps, instead of retyping its words.
- Switching sessions never loses a word, from either the session being left or the one being picked.
- Only the learner, deliberately, decides which session they are working in.

## 3. Non-goals

- Editing words directly on the History words screen — it stays read-only. Editing happens on the main screen, which already has every editing tool.
- Merging two sessions into one — the picked session replaces the current one as the working list; nothing is copied between them.
- Changing a shared page when the session is switched — the page changes only when the learner shares again, so an open partner page doesn't change unexpectedly.
- Deleting sessions from History — that is a separate feature.

## 4. User stories

### US-01: Start editing a past session
**As a** learner
**I want** an Edit button on a past session's words screen
**So that** I can go back to working on that list

### US-02: Confirm before switching
**As a** learner
**I want** to be asked before the app switches my current session
**So that** a stray tap doesn't pull me away from what I'm working on

### US-03: Continue on the main screen
**As a** learner
**I want** to land on the main screen with the picked session's words, as they were
**So that** I can add and fix words with the tools I already use

### US-04: Keep the list I was working on
**As a** learner
**I want** the session I leave to stay in History with every word I typed
**So that** switching never costs me any words

### US-05: See which session is current
**As a** learner
**I want** History and the next app launch to treat the picked session as current
**So that** I always know which list I'm adding words to

### US-06: A shared page doesn't change unexpectedly
**As a** partner
**I want** the shared page I have open to stay as it is when the learner switches sessions
**So that** the list we are discussing doesn't change unless the learner shares again

## 5. Acceptance criteria

### AC-01 (US-01) — happy path
**Given** the learner has opened a session from History that is not the current session
**When** the words screen for that session appears
**Then** it shows a round red Edit button with a pencil icon in the bottom-right corner, and everything else on the screen looks as it did before

### AC-02 (US-02) — happy path
**Given** the learner is on the words screen of a past session opened from History
**When** the learner taps the Edit button
**Then** the app asks "Do you want to edit this list of words?" with the choices No and Yes, and nothing changes until the learner answers

### AC-03 (US-03) — happy path
**Given** the learner has been asked whether to edit a past session
**When** the learner answers Yes
**Then** that session becomes the current session, and the learner is on the main screen with its words in the same order, with their translations, definitions and photos as stored; pressing Back behaves as after a normal launch and leaves the app, never returning to History or the words screen

### AC-04 (US-02) — happy path (decline)
**Given** the learner has been asked whether to edit a past session
**When** the learner answers No
**Then** the question closes, the learner stays on the same words screen, and the current session is unchanged

### AC-05 (US-01) — authorization
**Given** a partner has the shared link of a session open
**When** the partner looks for a way to edit that session
**Then** the shared page offers no way to make it the learner's current session; only the learner, in the app on their own phone, can do that

### AC-06 (US-01) — domain invariant: exactly one current session
**Given** the learner opens from History the session that is already current
**When** its words screen appears
**Then** no Edit button is shown, because that session is already the one the main screen is editing

### AC-07 (US-04) — domain invariant: switching never loses a word
**Given** the current session has words, including a word typed moments before leaving the main screen
**When** the learner switches to a past session
**Then** the session they left appears in History with all its words, including the last one typed; a current session with no words is dropped and does not appear in History

### AC-07b (US-04) — domain invariant: a late lookup never lands in the wrong session
**Given** the learner started a translation, definition or photo lookup on the main screen
**When** they switch to a past session before that lookup returns
**Then** the late result is ignored: the picked session shows exactly its stored words, and the session they left keeps what it had at the moment of the switch

### AC-08 (US-03) — error
**Given** the learner has confirmed they want to edit a past session
**When** that session can no longer be loaded from the phone
**Then** the learner sees a plain message that the session can't be opened for editing, stays on the words screen, and the current session is unchanged — nothing about it (saving, dropping, which session is current) is touched until the picked session has loaded

### AC-09 (US-05) — cross-context: History and the launch rule
**Given** the learner has just switched to a past session
**When** they open History, or close and reopen the app within the 5-minute window
**Then** History marks the picked session as current but keeps it in the same place, because no word was edited; the app opens straight on its words with no restore offer, counting the 5 minutes from the later of the pick and the last edit; any restore offer still pending from the last launch is cancelled by the switch; once a word is edited, the session moves to the top as today

### AC-10 (US-06) — cross-context: the shared page
**Given** the picked session was shared earlier and the partner has its page open
**When** the learner switches to it and edits words on the main screen
**Then** the partner's page doesn't change; it is updated only when the learner shares again from that session, which replaces the same link after the existing warning that the partner's edits will be replaced

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Switch time, Yes tap → main screen showing the picked words (session of ≤100 words) | ≤ 1 s | manual check on the learner's phone, release build |
| Words lost across a switch | 0 | widget test: type a word, switch within the save delay, check both sessions |
| Visual change outside the new button and question | 0 differing areas | side-by-side screenshots of History, words screen and main screen before/after (CLAUDE.md rule 3) |

## 6.1 Security / privacy

- **Data classification:** internal — the learner's own word lists, stored only on their phone.
- **Personal data touched:** none new; the feature only changes which stored session is current.
- **AuthZ/AuthN impact:** none. The app has no accounts; the action exists only in the learner's app, never on the shared page.
- **Abuse cases:**
  - Partner tries to take over the learner's working list: the shared page has no such action (AC-05).
  - Accidental tap switches away from unsaved work: the confirmation question (AC-02) plus saving the session being left (AC-07).
  - A shared link changing without the learner knowing: the link changes only on an explicit re-share, with the existing warning (AC-10).
- **Security review:** N/A — no new data, no new permission boundary, no network change.

## 7. Metrics / KPIs

- **Past sessions resumed through Edit** — baseline: 0 (not possible today), target: ≥ 1 per week of lessons within 30 days of release (learner's weekly self-check; the app has no analytics).
- **Words retyped from an older list into a new session** — baseline: every word the learner wants to keep adding to, target: 0 within 30 days (learner's own report).
- **Words reported lost after a switch** — baseline: n/a, target: 0 in the first 30 days.

## 8. Open questions

<!-- N/A: none open — every decision was settled in the assumptions ledger on 2026-09-29. -->
