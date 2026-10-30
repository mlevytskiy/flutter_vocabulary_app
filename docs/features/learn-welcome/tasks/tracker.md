# Tracker — learn-welcome

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record learn-welcome approvals in CLAUDE.md rules 3 and 5](./t1-record-learn-welcome-approvals-in-claude-md-rules-3-and-5.md) | docs | implementer agent | S | — | done |
| T2 | [Add WordBox.lastCheckSide and keep it through copy, JSON and the store](./t2-add-wordbox-lastcheckside-and-keep-it-through-copy-json-and.md) | infra | implementer agent | S | T1 | done |
| T3 | [Add the pure self-check rules: SelfRating, rateBox, nextSide, box labels](./t3-add-the-pure-self-check-rules-selfrating-ratebox-nextside-bo.md) | domain | implementer agent | S | T2 | done |
| T4 | [Add the pure flow word rules: card words, the source-tail split, dialog words](./t4-add-the-pure-flow-word-rules-card-words-the-source-tail-spli.md) | domain | implementer agent | M | T1 | done |
| T5 | [Add the pure story slot scheduler](./t5-add-the-pure-story-slot-scheduler.md) | domain | implementer agent | S | T1 | done |
| T6 | [Add the 50 topics and POST /learn/topics to the Worker](./t6-add-the-50-topics-and-post-learn-topics-to-the-worker.md) | ports | implementer agent | M | — | done |
| T7 | [Add the topics service with a 4 s timeout and the bundled fallback](./t7-add-the-topics-service-with-a-4-s-timeout-and-the-bundled-fa.md) | app | implementer agent | S | T6 | done |
| T8 | [Let the talk mission take a topic, a reply limit and chosen words](./t8-let-the-talk-mission-take-a-topic-a-reply-limit-and-chosen-w.md) | ports | implementer agent | M | — | done |
| T9 | [Let story runs send each word's context, source and edited translation to the story writer](./t9-let-story-runs-send-each-word-s-context-source-and-edited-tr.md) | ports | implementer agent | S | — | done |
| T10 | [Add the LearnFlowNotifier: phases, per-card save, story start and reuse, leave](./t10-add-the-learnflownotifier-phases-per-card-save-story-start-a.md) | app | implementer agent | L | T3, T4, T5, T7 | done |
| T11 | [Add the self-check card widget with flip, four ratings, box captions and the context line](./t11-add-the-self-check-card-widget-with-flip-four-ratings-box-ca.md) | ui | implementer agent | M | T3 | done |
| T12 | [Add the warm-up view on the Talk screen: 2-step bar, topic and mode choices, own topic](./t12-add-the-warm-up-view-on-the-talk-screen-2-step-bar-topic-and.md) | ui | implementer agent | M | T10 | todo |
| T13 | [Add the flow pager: cards, story picture pages, the wait page and the card counter](./t13-add-the-flow-pager-cards-story-picture-pages-the-wait-page-a.md) | ui | implementer agent | M | T10, T11 | todo |
| T14 | [Lock the app to portrait and turn the story page to landscape](./t14-lock-the-app-to-portrait-and-turn-the-story-page-to-landscap.md) | wiring | implementer agent | S | T13 | todo |
| T15 | [Run the main dialog in learn-flow mode and record its results without moving boxes](./t15-run-the-main-dialog-in-learn-flow-mode-and-record-its-result.md) | ui | implementer agent | M | T8, T10 | todo |
| T16 | [Show the flow's results: cards, stories, talk, due tomorrow, three buttons](./t16-show-the-flow-s-results-cards-stories-talk-due-tomorrow-thre.md) | ui | implementer agent | M | T10 | done |
| T17 | [Open the flow from Learn and remove the Learn sheet, the split checkbox and the group line](./t17-open-the-flow-from-learn-and-remove-the-learn-sheet-the-spli.md) | ui | implementer agent | M | T12, T13 | todo |
| T18 | [Finish learn-welcome: generated code, analyze, changed tests, grep check, device check list, self-check tasks updated](./t18-finish-learn-welcome-generated-code-analyze-changed-tests-gr.md) | docs | implementer agent | S | T9, T14, T15, T16, T17 | todo |

**Total:** 18 tasks, ~14 person-days.
