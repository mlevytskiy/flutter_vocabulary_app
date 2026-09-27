---
status: Living
updated_at: "2026-09-27"
---

# Domain Context — good-looking-web

## Glossary

- source photo — a photo of a page the learner took in a session that has at least one word row recognised from it at publishing time. NOT any image (a photo that yielded no words, or whose words were all deleted, is not a source photo and is not published).
- autofill — filling one translation or definition cell, or every empty cell of one column, with a single tap on a lightning icon on the shared page. NOT word recognition from a photo (that happens in the app, before publishing).
- autofill allowance — how many autofills one shared page may still make today. NOT the project-wide dictionary quota (that is shared by the app and every shared page).

## Invariants

- A word row keeps its source photo through edits on the shared page; a row added on the shared page has no source photo.
- Edits on the shared page never flow back into the app.
