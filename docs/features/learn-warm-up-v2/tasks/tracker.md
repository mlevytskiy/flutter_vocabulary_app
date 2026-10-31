# Tracker — learn-warm-up-v2

> Status of every task in the epic. `implement` updates `done` as it commits each task.
> States: `todo` · `in_progress` · `blocked` · `review` · `done`.

| # | Task | Layer | Owner | Estimate | Blocked by | Status |
|---|---|---|---|---|---|---|
| T1 | [Record the four approved visible changes in approved-changes.md](./t1-record-the-four-approved-visible-changes-in-approved-changes.md) | docs | implementer agent | S | — | todo |
| T2 | [Revise the 50 topics: groups, hooks, merged pairs, six new topics and permanent aliases](./t2-revise-the-50-topics-groups-hooks-merged-pairs-six-new-topics.md) | ports | implementer agent | M | — | todo |
| T3 | [Let the topics call take the profile and mood, fill slot 3 only from the profile, and write situation lines](./t3-let-the-topics-call-take-the-profile-and-mood-fill-slot-3-onl.md) | ports | implementer agent | M | T2 | todo |
| T4 | [Add the free warm-up reaction call with a checked one-line reply](./t4-add-the-free-warm-up-reaction-call-with-a-checked-one-line-re.md) | ports | implementer agent | S | — | todo |
| T5 | [Let the talk take a grammar rule on every turn and return a verdict per reply](./t5-let-the-talk-take-a-grammar-rule-on-every-turn-and-return-a-v.md) | ports | implementer agent | M | — | todo |
| T6 | [Add the events call that accepts fixed names and values only](./t6-add-the-events-call-that-accepts-fixed-names-and-values-only.md) | ports | implementer agent | S | — | todo |
| T7 | [Add the learner profile store with the round and counters in one preferences value](./t7-add-the-learner-profile-store-with-the-round-and-counters-in.md) | infra | implementer agent | S | — | todo |
| T8 | [Add the pure warm-up plan and the grammar rule list](./t8-add-the-pure-warm-up-plan-and-the-grammar-rule-list.md) | domain | implementer agent | M | T7 | todo |
| T9 | [Add the reaction and events services and send profile and mood with the topic pick](./t9-add-the-reaction-and-events-services-and-send-profile-and-moo.md) | app | implementer agent | M | T3, T4, T6 | todo |
| T10 | [Walk the warm-up plan in the Learn flow: save answers, react, pick topics, count](./t10-walk-the-warm-up-plan-in-the-learn-flow-save-answers-react-p.md) | app | implementer agent | L | T8, T9 | todo |
| T11 | [Draw the warm-up as a dialog: step bar, level, main and grammar taps, own words, topics with situations](./t11-draw-the-warm-up-as-a-dialog-step-bar-level-main-and-grammar.md) | ui | implementer agent | M | T1, T10 | todo |
| T12 | [Send the grammar rule with the main dialog and count the verdicts](./t12-send-the-grammar-rule-with-the-main-dialog-and-count-the-ver.md) | app | implementer agent | M | T5, T10 | todo |
| T13 | [Show the grammar line and the occasional 👍/👎 on the results page](./t13-show-the-grammar-line-and-the-occasional-on-the-results-page.md) | ui | implementer agent | M | T1, T9, T12 | todo |
| T14 | [Add the learner profile section to Learn settings](./t14-add-the-learner-profile-section-to-learn-settings.md) | ui | implementer agent | S | T1, T7 | todo |
| T15 | [Finish learn-warm-up-v2: generated code, analyze, changed tests, grep check, deploy order, device check list](./t15-finish-learn-warm-up-v2-generated-code-analyze-changed-tests.md) | docs | implementer agent | S | T2, T11, T13, T14 | todo |

**Total:** 15 tasks (1 L, 7 M, 7 S), ~11 person-days.
