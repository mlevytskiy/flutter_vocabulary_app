---
status: Living
updated_at: "2026-10-16"
---

# Domain Context — flutter_vocabulary_app

## Glossary

- collection — a named set of words collected together and stored on the learner's device; one file on the Collections screen. Formerly called session: Worker routes, shared links and stored records still say session, and specs written before collections-screen use the old name. NOT a login session (the app has no accounts), NOT a Quizlet set (a set is one source a collection's words came from).
- current collection — the one collection the main screen is editing; there is exactly one at a time, History marks it "current" and the main screen's title shows its name. NOT a published collection (sharing a collection does not make it current).
- filing — where a collection or folder sits on the Collections screen: its folder, its place in that folder's order, and its recycle-bin mark. Only the Collections screen's own actions (rename, new folder, move, reorder, delete, restore) change it; background work never does. NOT a word group, NOT a tag.
- kept collection — a collection the learner made with "New collection", renamed, moved, or that ever held a word; it stays when the learner leaves it empty. Only an untouched empty collection disappears on leaving. NOT a collection in the recycle bin.
- folder — a named place on the Collections screen that holds collections and other folders, nested to any depth; it lives only on the learner's device. NOT a word group (a group splits one collection's words for learning), NOT a tag.
- learner — the phone owner who collects words into collections and exports them. NOT partner (the partner only opens a shared link).
- partner — a person who opens a collection's shared link; they have no app and no account. NOT learner (the partner never collects words on a device).
- recycle bin — where a deleted collection or folder waits for 30 days before it is erased for good, and from where it can be restored to its old place. NOT a published collection's expiry (a shared link runs out on its own, whatever the bin holds).
- shared page — the public web page of a published collection, opened through its link; anyone holding the link can read and edit it. NOT an app screen (the app's words table lives on the learner's device).
- translation — the Ukrainian equivalent of an English word in a word row. NOT definition (a definition explains the meaning in English).
- word row — one line of a collection: an English word together with its details. NOT a table row in an export (the export is derived from word rows).
