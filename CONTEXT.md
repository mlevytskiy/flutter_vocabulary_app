---
status: Living
updated_at: "2026-10-23"
---

# Domain Context — flutter_vocabulary_app

## Glossary

- collection — a named set of words collected together and stored on the learner's device; one file on the Collections screen. Formerly called session: Worker routes, shared links and stored records still say session, and specs written before collections-screen use the old name. NOT a login session (the app has no accounts), NOT a Quizlet set (a set is one source a collection's words came from).
- current collection — the one collection the main screen is editing; there is exactly one at a time, History marks it "current" and the main screen's title shows its name. NOT a published collection (sharing a collection does not make it current).
- filing — where a collection or folder sits on the Collections screen: its folder, its place in that folder's order, and its recycle-bin mark. Only the Collections screen's own actions (rename, new folder, move, reorder, delete, restore) change it; background work never does. NOT a word group, NOT a tag.
- kept collection — a collection the learner made with "New collection", renamed, moved, given a description or a tag, or that ever held a word; it stays when the learner leaves it empty. Only an untouched empty collection disappears on leaving. NOT a collection in the recycle bin.
- folder — a named place on the Collections screen that holds collections and other folders, nested to any depth; it lives only on the learner's device. NOT a word group (a group splits one collection's words for learning), NOT a tag.
- learner — the phone owner who collects words into collections and exports them. NOT partner (the partner only opens a shared link).
- partner — a person who opens a collection's shared link; they have no app and no account. NOT learner (the partner never collects words on a device).
- recycle bin — where a deleted collection or folder waits for 30 days before it is erased for good, and from where it can be restored to its old place. NOT a published collection's expiry (a shared link runs out on its own, whatever the bin holds).
- shared page — the public web page of a published collection, opened through its link; anyone holding the link can read and edit it. NOT an app screen (the app's words table lives on the learner's device).
- origin tag — a tag that answers "Where does it come from?" (a book, a film, a podcast, a trip) on a collection or on a source. NOT a source (a source is the photo, set or film the words came from; an origin tag only names the kind of place), NOT a folder.
- topic tag — a tag that answers "What is it about?" (food, phrasal verbs, a job interview) on a collection or on a source. The same text may be both an origin tag and a topic tag; they are different tags. NOT a word group (a group splits one collection's words for learning), NOT a folder.
- preset tag — one of the app's fixed suggested origin or topic tags, offered before the learner has typed any of their own. It is never edited or forgotten. NOT a tag in the tag library until the learner uses it.
- tag library — every origin and topic tag the learner has ever added, kept on the device; how often each is used is worked out from the collections and sources outside the recycle bin, and tag fields suggest and autocomplete from it. "Forget this tag" removes an entry from the library and from suggestions, never from a collection or source. NOT the tags of one collection.
- translation — the Ukrainian equivalent of an English word in a word row. NOT definition (a definition explains the meaning in English).
- word row — one line of a collection: an English word together with its details. NOT a table row in an export (the export is derived from word rows).
- learning session — one run of Learn → Exercises over a set of words (all the collection's words, or one word group when split is on): exercise pages in word-ladder order, ending with the results screen. NOT a collection (formerly "session"), NOT a login session.
- exercise page — the smallest playable part of an exercise: one word, one gap sentence, or one board of four pairs, answered and checked on its own. A learning session mixes pages of several exercises. NOT a round (a round is several pages of one exercise on the old exercise screens).
- word ladder — the three rungs a word climbs in a learning session: Meet (step 1), Practise (step 2), Use (step 3). A right answer moves the word up a rung; a miss moves it one rung down and back into the queue a few pages later. NOT the Leitner box (the ladder lives inside one session; the box lasts across sessions).
- Leitner box — where a word stands across learning sessions: new (never learned) or box 1 to 5, with a review due after 1, 2, 4, 8 or 16 days. A clean ladder moves the word up one box; any miss sends it to box 1. NOT the word result of the step-3 exams (known/repeat).
- due word — a word whose Leitner box review date has come. A learning session takes due words first, then new words.
- learning companion — who the learner learns with: alone, with teacher, with friend; picked from the drop-down beside Learn. Only "alone" works now. NOT a partner (a partner opens a shared link).
- learn preset — a ready-made choice of exercises per step and words per session in Learn settings: Quick, Balanced, Deep, or Custom (the learner's own switches).
- Talk with AI — the learning mode where the learner converses (typing, later speaking) with an AI partner who steers toward the session's words; the app, not the AI, decides which words were used. NOT the exercise "Explain it to a friend".
