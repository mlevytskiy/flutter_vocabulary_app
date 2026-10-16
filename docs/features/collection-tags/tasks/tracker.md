# Tracker — collection-tags

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record the collection-tags approvals in CLAUDE.md rules 3 and 5](./T1-docs-record-the-collection-tags-approvals-in-claude-md-rules-3-an.md) | docs | agent | S | — | done |
| T2 | [Add TagKind and the pure tag rules: validation, keys, limits, presets, legacy sort, matching and ranking](./T2-domain-add-tagkind-and-the-pure-tag-rules-validation-keys-limits-pr.md) | domain | agent | M | — | done |
| T3 | [Add the pure collection search: summaries, matching, filters, calendar-day ranges, sort and tag counts](./T3-domain-add-the-pure-collection-search-summaries-matching-filters-ca.md) | domain | agent | M | T2 | done |
| T4 | [Add description, typed tags and TagLibraryEntry to the Isar models and regenerate the schema](./T4-infra-add-description-typed-tags-and-taglibraryentry-to-the-isar-m.md) | infra | agent | S | T2 | done |
| T5 | [Protect description and typed tags in put/update and add setDetails, create(details), addCollectionTags and the library writes](./T5-infra-protect-description-and-typed-tags-in-put-update-and-add-set.md) | infra | agent | L | T4 | done |
| T6 | [Migrate untyped tags once on store open with the legacy-as-topic fallback](./T6-infra-migrate-untyped-tags-once-on-store-open-with-the-legacy-as-t.md) | infra | agent | M | T5 | done |
| T7 | [Add the summaries stream and the library providers, and move tag suggestions into features/tags](./T7-wiring-add-the-summaries-stream-and-the-library-providers-and-move.md) | wiring | agent | M | T3, T6 | todo |
| T8 | [Route details, Notes tag edits and source notes through the store and adopt stored values in the main notifier](./T8-app-route-details-notes-tag-edits-and-source-notes-through-the-s.md) | app | agent | M | T5 | todo |
| T9 | [Add TagChip and grow TagEditor into TypedTagField with hints, examples, suggestion row, autocomplete, limits and Forget](./T9-ui-add-tagchip-and-grow-tageditor-into-typedtagfield-with-hints.md) | ui | agent | M | T2 | done |
| T10 | [Add the Collection details sheet with Discard changes and wire New collection and the main screen's edit button to it](./T10-ui-add-the-collection-details-sheet-with-discard-changes-and-wi.md) | ui | agent | M | T7, T8, T9 | todo |
| T11 | [Show the tag line in the main screen's AppBar bottom and push filtered Collections on a tag tap](./T11-ui-show-the-tag-line-in-the-main-screen-s-appbar-bottom-and-pus.md) | ui | agent | S | T9 | done |
| T12 | [Make the Notes page's collection and source tag fields typed, with focus-only suggestions and the copy-up snackbar](./T12-ui-make-the-notes-page-s-collection-and-source-tag-fields-typed.md) | ui | agent | M | T7, T8, T9 | todo |
| T13 | [Add search mode and the flat results view to the Collections screen, seeded from the route](./T13-ui-add-search-mode-and-the-flat-results-view-to-the-collections.md) | ui | agent | L | T7, T9, T11 | todo |
| T14 | [Add the filter sheet: tag sections with counts, Created and Edited choices with a custom range, sort, Reset and Show N](./T14-ui-add-the-filter-sheet-tag-sections-with-counts-created-and-ed.md) | ui | agent | M | T13 | todo |
| T15 | [Pin that description and tags never reach a publish payload or an export file](./T15-tests-pin-that-description-and-tags-never-reach-a-publish-payload.md) | tests | agent | S | T4 | done |
| T16 | [Update architecture.md and the roadmap for collection-tags](./T16-docs-update-architecture-md-and-the-roadmap-for-collection-tags.md) | docs | agent | S | T10, T11, T12, T13, T14, T15 | todo |
