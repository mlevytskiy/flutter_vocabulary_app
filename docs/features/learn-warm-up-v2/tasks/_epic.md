# Epic — learn-warm-up-v2

> **Spec:** [spec.md](../spec.md) · **Design:** [sad.md](../sad.md) · **ADRs:** [adr/](../adr/) · **Flows:** [ux-flows.md](../ux-flows.md) · **Brief:** [improvements.md](../improvements.md)

## Goal

The warm-up becomes a short dialog (intro, main question, sometimes a grammar question, topic, Hard/Easy) that fills a
learner profile kept on the phone; topics fit the words first and the learner a little; a chosen grammar rule steers
the main dialog and gets a results line; fixed counts and an occasional 👍/👎 measure it ([spec §2](../spec.md)).

## Scope

- **In:** the warm-up view and plan, the profile store and settings section, the Worker's topics, reaction, talk and
  events calls, the results page's grammar line and 👍/👎, the revised catalog.
- **Out:** the talk mission's turns, words and microphone (owner D1–D3); dashboards ([spec §3](../spec.md)).

## Order

Worker tasks T2–T6 and the store T7 have no app dependencies and can run first (max 2 agents at a time). Deploy the
Worker before the app release (ADR-0006, G9).

## Task map

```mermaid
flowchart LR
    T1["T1 docs"]
    T2["T2 ports"]
    T3["T3 ports"]
    T4["T4 ports"]
    T5["T5 ports"]
    T6["T6 ports"]
    T7["T7 infra"]
    T8["T8 domain"]
    T9["T9 app"]
    T10["T10 app"]
    T11["T11 ui"]
    T12["T12 app"]
    T13["T13 ui"]
    T14["T14 ui"]
    T15["T15 docs"]
    T2 --> T3
    T7 --> T8
    T3 --> T9
    T4 --> T9
    T6 --> T9
    T8 --> T10
    T9 --> T10
    T1 --> T11
    T10 --> T11
    T5 --> T12
    T10 --> T12
    T1 --> T13
    T9 --> T13
    T12 --> T13
    T1 --> T14
    T7 --> T14
    T2 --> T15
    T11 --> T15
    T13 --> T15
    T14 --> T15
```
