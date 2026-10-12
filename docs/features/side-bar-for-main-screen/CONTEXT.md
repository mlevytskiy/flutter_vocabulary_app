---
status: Living
updated_at: "2026-10-12"
---

# Domain Context — side-bar-for-main-screen

> Project-wide terms (learner, session, current session, word row, shared page) live in the
> repo-root [`CONTEXT.md`](../../../CONTEXT.md).

## Glossary

- photo panel — the panel that slides in from the right side of the main screen's words page and shows the current session's photos with words. It is closed, half-open or full-open. NOT the drawer (the left menu with Main and History) and NOT the shared page's source pager.
- photo tab — the small handle on the right side of the words page, beside the first word rows, that shows mini previews of the photos with words. Tapping or dragging it opens the photo panel. NOT the drawer's menu button (top-left corner).
- half-open — the photo panel state that shows a column of small photos while the word rows stay visible beside it; tapping a photo here makes it the selected photo. NOT full-open.
- full-open — the photo panel state that covers the word rows and shows the photos large. NOT half-open (no word rows are visible, so nothing is highlighted).
- photo with words — a photo the learner took for the current session from which at least one word row still comes. NOT a Quizlet set (a set has no picture) and NOT a photo whose word rows were all deleted.
- selected photo — the one photo in the half-open photo panel whose word rows are highlighted. It stays selected until the learner taps it again, taps another photo, or the panel closes; it is never saved. NOT a photo the learner is viewing large in full-open.
- design variant — one of the two or three looks built for the photo tab and photo panel so the owner can compare them on a phone. All variants share the same behaviour except two things they may each choose: how the large photos are browsed in full-open, and whether the photo tab hides while the word list scrolls. The owner picks one and the others are removed before release. NOT a setting the learner sees.
