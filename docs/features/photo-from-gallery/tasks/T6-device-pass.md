---
id: T6
title: "Run the device pass for the spec §6 targets on one iPhone and one Android phone"
layer: "tests"
deps: ["T1", "T5"]
acs: ["AC-01", "AC-02", "AC-03", "AC-08", "AC-09", "AC-12", "AC-13"]
files_hint: ["docs/features/photo-from-gallery/_audit/device-pass.md"]
owner: "Maksym"
estimate: "M"
status: "done"
---

# T6 — Run the device pass for the spec §6 targets on one iPhone and one Android phone

## Why

[spec §6](../spec.md) NFR table and §7 KPIs; [sad §10](../sad.md) QG-1–QG-4; [sad §11](../sad.md) (HEIC / 48 MP / online-only photo risk, Android picker fallback, tall screenshot message).

## What

- A manual pass on the owner's phones against the deployed Worker, recorded in `docs/features/photo-from-gallery/_audit/device-pass.md`. Create the sheet first, with one row per spec §6 target and one per test image.

## Definition of Done

**Done when:** `_audit/device-pass.md` records, on one iPhone and one Android phone, exactly 1 extra tap to the camera, the gallery and camera median times to the results dialog (5 runs each), the 10-image robustness set with each outcome (results dialog or plain message within 60 s, 0 crashes, 0 freezes), 0 new permission prompts from a fresh install, the original photo unchanged, the Android picker look (Photo Picker or fallback), and a gallery photo published and seen on the shared page with Include photos on.

- [x] The sheet is filled in, with every spec §6 target marked met or missed
- [x] Every miss is either fixed through `/sdd:fix photo-from-gallery` or recorded in sad §11 with the owner
- [x] lint clean (`flutter analyze`)

## Notes

- **Done (owner, 2026-10-06):** the owner ran the device pass on both phones and reported every target met; no misses, so nothing for `/sdd:fix` or sad §11. Per-run numbers were not written into the sheet.
- **Blocked (implement, 2026-10-06):** needs the owner's iPhone and Android phone, the deployed Worker and real Anthropic spend. The results sheet is ready at `_audit/device-pass.md`; analyze, the full test suite and both debug builds pass, and no permission was added.
- It needs physical devices and real Anthropic spend, so `implement` will mark it blocked and leave the sheet ready, as words-from-subtitles T13 did.
- The 10-image set: a JPEG page photo, a PNG screenshot, a HEIC photo, a 1080×20000 screenshot, a ≥48 MP original, a photo stored only online, a non-image-looking meme, and 3 page photos (spec §6).
