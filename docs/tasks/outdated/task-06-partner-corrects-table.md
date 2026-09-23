# Task 06 — The partner corrects the word table on the shared page

|  |  |
|---|---|
| **Roadmap step** | [#6](../../roadmap.md#steps) |
| **Size** | M |
| **Wave** | 4 (alone — same `vocab-photo-api/src/session/` zone as task-07) |
| **Depends on** | **task-05** — there is no page to correct until a session is published |
| **Blocked on** | **D6** — whether the random per-person names on the shared page are needed at all |
| **Unlocks** | task-07 |
| **Files** | `vocab-photo-api/src/session/` · `vocab-photo-api/src/index.ts` · `vocab-photo-api/README.md` |
| **Status** | not started |

## Blocked on D6

> Whether the random per-person names on the shared page are needed at all, given nothing depends
> on identity in the first version.

**Recommended: no names.** Nothing in this task's behaviour reads identity — an edit is an edit,
and with two or three people around one table, who typed it is established by the people looking at
each other. Names would be the only piece of per-visitor state on an otherwise stateless page, and
they buy nothing that the first version uses. Answer D6 in `docs/roadmap.md`; if the answer is
"yes, names", add a "shows who last edited a row" criterion to the list below and a per-visitor
identifier (a cookie, not an account) to the design.

## Prompt

Let whoever holds the link edit the word table on the shared page: correct a translation, fix a
typo in a word, add a row, delete a row. The page is the only place these edits exist — corrections
**do not** flow back into the app (`docs/idea-brief.md` §5 closes that direction explicitly; the
file download in task-07 is the only return path). Do not build sync-back, and do not build
anything that assumes it will exist.

Do the following:

1. **A write route for the public page.** Extend `vocab-photo-api/src/session/` with an update
   endpoint — recommended `PUT /s/<id>/words`, taking the whole word list and replacing it. Whole
   list, not per-row patches: the client is a plain HTML page, the list is a handful of rows, and
   full replacement removes every "which row is row 3 now" question. It must be **public** — the
   link is the only credential, same as the read route — which means going through the route-level
   public/secret declaration task-05 introduced rather than adding another special case.
2. **Rate-limit it.** The existing per-IP limiter (20 req/60s, `wrangler.jsonc`) applies to every
   route through the `fetch` handler, so this inherits it — but check the arithmetic against the
   real usage: an autosave-on-every-keystroke page would exhaust 20 requests in a sentence. Save on
   blur or on an explicit Save action, or debounce hard. Whatever you pick, confirm a realistic
   editing session does not hit `429`.
3. **Make the edits visible without a framework.** The page is server-rendered plain HTML with no
   build step (task-05) and that stays true. Use a `<form>` and a full-page POST-redirect-GET, or
   `contenteditable` plus a small inline `fetch`. Either is fine; a framework is not.
4. **Decide and document what concurrent edits do.** Two phones on the same link is the *expected*
   case, not an edge case, and whole-list replacement means last-write-wins silently discards the
   other person's correction. Pick one and implement it:
   - last-write-wins, with the page reloading the server's copy after save so the loser at least
     *sees* the discard;
   - an `If-Match`-style version counter on the session, rejecting a stale write with `409` and
     telling the page to reload.
   The second is recommended and is maybe twenty lines — a version integer on the document,
   compared on write. With two or three people editing the same short table in the same room,
   silent loss will happen on day one.
5. **Validate the payload.** Reject anything that is not a list of `{word, translation}` string
   pairs with `400`. Cap the row count and the per-field length — this is an unauthenticated write
   endpoint, and it is the only one in the project. Strip or escape HTML on render; a word field
   that renders as markup on a page you hand to someone else is the obvious hole here.
6. **Preserve the source.** Editing words must not disturb the `sources` list on the session
   document.
7. **Document it** in `vocab-photo-api/README.md`: the route, that it is public, the concurrency
   rule, and the limits.

## Acceptance criteria

- [ ] **AC-1** `cd vocab-photo-api && npm run typecheck` exits 0.
- [ ] **AC-2** `PUT /s/<id>/words` with a valid list and **no headers** returns `200`, and a
      following public `GET /s/<id>` shows the edited values.
- [ ] **AC-3** An edit survives a Worker restart — it went to the store, not to memory.
- [ ] **AC-4** A row added on the page appears on reload; a row deleted on the page is gone on
      reload.
- [ ] **AC-5** Malformed payloads return `400`: not-JSON, a JSON object instead of a list, a list
      of strings, a list of objects missing `translation`, a row count over the cap, a field over
      the length cap.
- [ ] **AC-6** `PUT` to a nonexistent or expired session id returns `404`.
- [ ] **AC-7 — XSS.** Set a word to `<script>alert(1)</script>` and another to
      `<img src=x onerror=alert(1)>`. Reload the page: both render as visible text, no dialog
      fires, and `curl` of the HTML shows the angle brackets escaped.
- [ ] **AC-8 — concurrency.** Open the same link in two browser windows. Edit row 1 in window A and
      save; edit row 2 in window B and save. The result matches the documented rule: either B is
      rejected with `409` and reloads to see A's edit, or B wins and A's window shows the server's
      copy after its next save. What must **not** happen is both windows claiming success while one
      edit is silently gone.
- [ ] **AC-9** A realistic editing session — correct 5 translations and add 2 rows at normal typing
      speed — never returns `429`.
- [ ] **AC-10** After editing words, the session's `sources` list is unchanged (`jq` the stored
      document before and after).
- [ ] **AC-11** The word list in the app is unchanged after the partner edits the page — sync-back
      does not exist and must not have been built by accident.
- [ ] **AC-12** On two real phones on the same link: both people can edit, and each sees the
      other's correction after a reload.
- [ ] **AC-13** Editing works on a phone browser in portrait — the fields are tappable and the
      keyboard does not cover the save affordance.
