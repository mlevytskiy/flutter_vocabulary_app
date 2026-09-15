# Task 07 — Download the AnkiDroid file straight from the shared page

|  |  |
|---|---|
| **Roadmap step** | [#7](../roadmap.md#steps) |
| **Size** | S |
| **Wave** | 5 (alone — same `vocab-photo-api/src/session/` zone as task-06) |
| **Depends on** | **task-05** — the download has to sit on the shared page |
| **Blocked on** | — |
| **Files** | `vocab-photo-api/src/session/` · `vocab-photo-api/README.md` · `lib/screens/words_table_screen.dart` (format extraction only) |
| **Status** | not started |

## Prompt

Put a download link on the shared page that gives whoever holds it the AnkiDroid-importable file
for that session's words. This is the project's only return path out of the shared page — the brief
closes sync-back deliberately (`docs/idea-brief.md` §5), so this download is how a correction the
partner made ever reaches anyone's learning app.

The file format already exists in the app, in `_generateCloseUpB2Format`
(`lib/screens/words_table_screen.dart:17-31`):

```
#separator:tab
#html:true
#tags column:3
<word>\t<translation>\t
```

The Worker must produce a **byte-identical** format. Dart and TypeScript cannot share this code, so
the format is going to exist twice — which means it needs to be written down once. Add a short
`## AnkiDroid file format` section to `vocab-photo-api/README.md` specifying the three header lines,
the tab separator, the trailing tab (the empty tags column), and the line ending, and reference it
from a comment in both implementations. Two silently diverging copies of an import format is a bug
you find weeks later, inside Anki.

Do the following:

1. **`GET /s/<id>/words.txt`** — public, no secret, same as the page. Generate the TSV from the
   stored session.
2. **Serve it as a download, not as a page.** `content-type: text/plain; charset=utf-8` and
   `content-disposition: attachment; filename="vocabulary_<YYYY-MM-DD>.txt"`, matching the app's
   own naming (`vocabulary_$dateStr.txt`, `words_table_screen.dart:52`). Without the
   `content-disposition`, a phone browser renders the text inline and there is no file to hand to
   AnkiDroid — which is the entire point of the task.
3. **Fix the blank-row bug while porting the format.** The app's version iterates every
   `widget.wordPairs` entry, and `_wordPairs` always carries a trailing empty row by design
   (`_checkAndAddNewPair`) — so the current export writes a line that is just two tabs. Filter
   pairs where both fields are blank. Fix it in the app's `_generateCloseUpB2Format` too, in the
   same commit; it is three lines and leaving the two implementations disagreeing about this
   defeats the point of step 1's shared spec.
4. **Note what `#html:true` implies.** That header tells Anki to interpret field content as HTML.
   Task-06 escapes word text for the *page*; this file is a different sink with a different rule.
   Decide what happens to a word containing `<` or `&` in the file — the safe answer is to escape
   it as an HTML entity, since `#html:true` means Anki will parse it. Say which you chose in the
   comment.
5. **Handle tabs and newlines in field values.** A tab inside a translation would shift columns and
   a newline would split the record. The partner types these by accident. Strip or replace both.
6. **Put the link on the page** next to the table, labelled so a non-technical reader knows what it
   is for — "Download for AnkiDroid", not "Export TSV".
7. **The download reflects current state.** If the partner corrected a translation (task-06), the
   file contains the correction. Generate from the stored session at request time; do not cache a
   file built at publish time.

## Acceptance criteria

- [ ] **AC-1** `cd vocab-photo-api && npm run typecheck` exits 0; `flutter analyze` exits 0.
- [ ] **AC-2** `curl -i` on the download URL with **no headers** returns `200` with
      `content-type: text/plain` and a `content-disposition: attachment` naming
      `vocabulary_<date>.txt`.
- [ ] **AC-3 — byte-identical formats.** Export the same 5-word list from the app's Share action
      and from the download URL, then `diff` the two files. They match exactly. This is the
      criterion that actually matters; run it, don't eyeball it.
- [ ] **AC-4** The file's first three lines are exactly `#separator:tab`, `#html:true`, and
      `#tags column:3`.
- [ ] **AC-5** No blank record: a session with 5 filled words produces exactly 5 word lines (8
      lines total). `grep -c '^\t' <file>` returns 0.
- [ ] **AC-6** `flutter analyze` clean and a re-export from the app also shows no blank trailing
      record — step 3 was applied on both sides.
- [ ] **AC-7 — the real check.** Import the downloaded file into AnkiDroid on a real device. All
      words land as cards, each with its translation on the back, and no card is empty or garbled.
      Nothing short of this proves the format.
- [ ] **AC-8** A word containing `&`, `<`, a tab and a newline survives the round trip into Anki as
      readable text — not as markup, not split across two cards, not shifted into the wrong field.
- [ ] **AC-9** Ukrainian translations render correctly in Anki — the file is UTF-8 and the charset
      is declared.
- [ ] **AC-10** Download URL for a nonexistent or expired session returns `404`.
- [ ] **AC-11 — current state.** Edit a translation on the shared page (task-06), then download
      without republishing from the app. The file has the edited translation.
- [ ] **AC-12** On a real phone: open the shared link, tap the download link, and the browser saves
      a file that AnkiDroid's import picker can see. Check both Android and iOS Safari if both are
      in use — iOS Safari handles `content-disposition` differently and this is where it will fail
      if it fails.
