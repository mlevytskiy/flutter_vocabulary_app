---
id: T19
title: "Run the panel behaviour suite against every look and write the device-pass checklist"
layer: "tests"
deps: ["T10", "T15", "T16", "T17", "T18"]
acs: ["AC-01", "AC-02", "AC-03", "AC-04", "AC-05", "AC-06", "AC-07", "AC-07b", "AC-08", "AC-09", "AC-10", "AC-11", "AC-12", "AC-13", "AC-14", "AC-15", "AC-15b", "AC-16", "AC-17", "AC-18", "AC-19"]
files_hint: ["test/photo_panel_test.dart", "docs/features/side-bar-for-main-screen/device-pass.md"]
owner: "Maksym"
estimate: "M"
status: "todo"
---

# T19 — Run the panel behaviour suite against every look and write the device-pass checklist

## Why

[spec §5, §6, §7](../spec.md), [sad §10 quality scenarios](../sad.md), [ADR-0003](../adr/0003-share-one-panel-behaviour-and-plug-in-each-design-variants-look.md) (every variant runs the same tested behaviour).

## What

- `photo_panel_test.dart`: a `for (final v in PhotoPanelVariant.values)` group over the key behaviour cases from T7 to T15 on the real main screen, plus a variant switch mid-session.
- `device-pass.md`: the owner's checklist for the review build: 20 drags with gesture navigation, 10 timed taps, profile-build frame overlay, timed start with 50 photos, memory profiler, 200-row jump, KPI counts; one table per look.

## Definition of Done

**Done when:** `photo_panel_test.dart` runs the AC-01 to AC-18 cases once per `PhotoPanelVariant` and passes for all, including the 300 ms open and the 500 ms jump in 200 rows; switching the variant redraws at once; `tool/test.sh changed` is green; `device-pass.md` lists every spec §6 NFR and §7 KPI with its method and an empty result column.

- [ ] test: parametrised over all looks
- [ ] `dart run build_runner build --delete-conflicting-outputs`, `flutter analyze` clean, `tool/test.sh changed` green
- [ ] CLAUDE.md greps clean (`Navigator.push`, `MaterialPageRoute`, `static final .* instance`)

## Notes

- The NFRs themselves are measured by hand on the owner's phone (sad §2); this task only prepares the checklist.
- After this task the review build goes to the owner for the design pick.
