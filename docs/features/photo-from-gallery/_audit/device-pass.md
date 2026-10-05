# Device pass — photo-from-gallery (T6)

> **Status: not run yet.** Fill this in on one iPhone (iOS 15+) and one Android phone (the app's
> current minimum SDK or newer), against the deployed Worker, with a build from `db8f964` or later.
> Every recognition run costs one real AI request.
> Targets: [spec §6](../spec.md) and §7, [sad §10 QG-1 to QG-4](../sad.md), [sad §11](../sad.md).
> Mark each target **met** or **missed**. Fix a miss with `/sdd:fix photo-from-gallery`, or record it in
> sad §11 with the owner.

## Phones

| | Model | OS version | App build (commit) | Date |
|---|---|---|---|---|
| iPhone | | | | |
| Android | | | | |

## 1. Fresh install: 0 new permission prompts (AC-09, QG-3)

Steps on each phone:

1. Delete the app. On iPhone also check Settings → Privacy & Security → Photos: the app must not be listed
   (or reinstalling must reset it). Never grant photo-library access during this pass.
2. Install the build, open it, go to the word-input screen.
3. Tap the speed dial → "Get words from photo" → **Gallery**. Pick one page photo. Note every system
   dialog that appears (the picker itself is not a prompt; a "Allow access to photos?" / "Allow ... to
   access photos and media?" dialog is).
4. Repeat 3 once more, then once with **Camera** (the camera prompt is the existing one, not new: note it
   separately).

| Check | iPhone | Android |
|---|---|---|
| Photo-library / media permission dialog shown during gallery picks (target: none) | | |
| Camera permission dialog on first Camera use (existing, expected) | | |
| After the pass, the app has no photo-library access in system settings | | |
| **Target 0 new prompts** → met / missed | | |

## 2. Camera stays one tap away (AC-01, AC-02, AC-05, QG-4)

Steps: from the word-input screen, open the speed dial, tap "Get words from photo", count every tap
until the camera viewfinder is showing.

| Check | iPhone | Android |
|---|---|---|
| Taps from "Get words from photo" to the camera (target: 2 — the item, then Camera = exactly 1 extra) | | |
| The dialog title is "Get words from photo" with exactly two choices, Camera and Gallery | | |
| Tapping outside the dialog / Back closes it: nothing opens, no message, session unchanged (AC-05) | | |
| After the shot, everything looks and behaves as before this feature (AC-02) | | |
| Tapping "Get words from photo" again while a photo is analysing shows "The current photo is still being analysed" and opens nothing (AC-10) | | |
| **Target exactly 1 extra tap** → met / missed | | |

## 3. Time to results dialog: gallery median ≤ camera median + 2 s (AC-03, QG-1)

Steps on each phone:

1. Use one printed page with highlighted words, same light, same Wi-Fi.
2. **Camera, 5 runs:** start the stopwatch when the shutter is confirmed ("Use Photo" on iPhone, the
   tick on Android); stop it when the results dialog appears. Keep each shot in the phone's gallery
   (save it from the camera app if the app's capture does not save it — or take one shot of the page in
   the system camera app beforehand and use that for the gallery runs).
3. **Gallery, 5 runs:** pick the same shot of that page each time (one stored on the phone, not
   online-only). Start the stopwatch when the photo is tapped in the picker; stop it when the results
   dialog appears.
4. Cancel or keep words as you like; record the word count shown.

### iPhone

| Run | Camera (s) | Camera words | Gallery (s) | Gallery words |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| **Median** | | | | |

Gallery median − camera median: ___ s → **≤ 2 s met / missed**

### Android

| Run | Camera (s) | Camera words | Gallery (s) | Gallery words |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |
| **Median** | | | | |

Gallery median − camera median: ___ s → **≤ 2 s met / missed**

Every results dialog listed ≤ 20 words (AC-03): iPhone ___ / Android ___

## 4. Robustness: 10 of 10 images end in the results dialog or a plain message within 60 s (AC-07, AC-08, QG-2)

Prepare the set in each phone's gallery before starting. For each image: Gallery → pick it → stopwatch
from the pick until the results dialog or a message shows (stop at 60 s and mark "freeze" if neither).
Record the exact message text. If the results dialog shows, cancel it (or remove every word) and check
that no source photo was kept (the "Include photos (N)" count on the Words screen does not grow, AC-11).

| # | Image | How to make it | Expected |
|---|---|---|---|
| 1 | JPEG page photo | A printed page with highlighted words, shot with the camera and saved/exported as JPEG (on iPhone: Settings → Camera → Formats → Most Compatible, or AirDrop a JPEG) | Results dialog |
| 2 | PNG screenshot | A screenshot of a web page or e-book with highlighted words | Results dialog |
| 3 | HEIC photo | iPhone camera with Formats → High Efficiency; on Android copy the same HEIC file to the phone | Results dialog |
| 4 | 1080×20000 screenshot | A scrolling (full-page) screenshot, or a generated 1080×20000 image copied to the phone | Results dialog or a plain message (the Worker's "Failed to analyze photo, please try again" is accepted, ADR-0002) |
| 5 | ≥ 48 MP original | iPhone 14 Pro or later in 48 MP ProRAW/HEIF Max, or a ≥ 48 MP JPEG copied to the phone | Results dialog |
| 6 | Photo stored only online | iCloud Photos with "Optimize iPhone Storage" (an old photo not on the phone) / Google Photos cloud-only item in the Android picker | Results dialog, or "The photo from the gallery could not be used. Try another one." (try once on Wi-Fi and once in airplane mode) |
| 7 | Non-image-looking meme | A meme or picture with little or no printed text | A plain message or an empty/short results dialog, no crash |
| 8 | Page photo A | Another printed page with highlighted words | Results dialog |
| 9 | Page photo B | Another printed page with highlighted words | Results dialog |
| 10 | Page photo C | Another printed page with highlighted words | Results dialog |

### iPhone

| # | File (name, size, dimensions) | Outcome (dialog / message text) | Words | Time (s) | ≤ 60 s? | Crash? | Freeze? | Photo kept with 0 words? |
|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | |
| 2 | | | | | | | | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |
| 6 | | | | | | | | |
| 7 | | | | | | | | |
| 8 | | | | | | | | |
| 9 | | | | | | | | |
| 10 | | | | | | | | |

Result: ___ of 10 within 60 s, ___ crashes, ___ freezes → **met / missed**

### Android

| # | File (name, size, dimensions) | Outcome (dialog / message text) | Words | Time (s) | ≤ 60 s? | Crash? | Freeze? | Photo kept with 0 words? |
|---|---|---|---|---|---|---|---|---|
| 1 | | | | | | | | |
| 2 | | | | | | | | |
| 3 | | | | | | | | |
| 4 | | | | | | | | |
| 5 | | | | | | | | |
| 6 | | | | | | | | |
| 7 | | | | | | | | |
| 8 | | | | | | | | |
| 9 | | | | | | | | |
| 10 | | | | | | | | |

Result: ___ of 10 within 60 s, ___ crashes, ___ freezes → **met / missed**

KPI (spec §7): gallery page photos that gave their words (images 1, 2, 3, 5, 8, 9, 10 plus any other
page photo): iPhone ___ / Android ___ (target ≥ 9 of 10 page photos overall).

## 5. Other gallery outcomes (AC-06, AC-11)

| Check | iPhone | Android |
|---|---|---|
| Gallery → close the picker without picking: "No photo was picked" (no camera wording), session unchanged | | |
| Gallery → pick a page → remove every word / cancel the dialog: no words added, "Include photos (N)" unchanged | | |

## 6. Original photo unchanged (AC-13, QG-3)

Before the pass, note one test photo's date, size and an edit marker (none). After a successful import,
a failed import (image 6 in airplane mode or image 4) and a cancelled import of that same photo:

| Check | iPhone | Android |
|---|---|---|
| Still in the same album, same date | | |
| Not edited (no "Edited"/"Revert" in Photos, no new copy in Google Photos/Files) | | |
| Not deleted, not moved | | |
| **AC-13** → met / missed | | |

## 7. Android picker look (ADR-0001)

| Check | Android |
|---|---|
| Android version / Google Play system update month | |
| Gallery opens the system **Photo Picker** (photo grid with "Photos" / "Albums" tabs, bottom sheet) or the **fallback** document picker (file browser look) | |
| Only one photo can be picked | |
| If fallback: still no permission prompt, still one photo → recorded in sad §11 (expected only on phones without the picker module) | |

## 8. Gallery photo published and seen on the shared page (AC-04, AC-12)

Steps (on one phone; note which):

1. New session. Gallery → pick a page photo → keep at least one word → Done.
2. Open the Words screen: "Include photos (N)" counts the gallery photo; a thumbnail tap opens it among
   the session's photos.
3. Share as a link with "Include photos" **on**. Note the warning that included photos are public for
   30 days.
4. Open the link in a browser on another device (the partner view).

| Check | Result |
|---|---|
| Phone used | |
| Every word row added from the photo points at it (row's photo icon opens it) (AC-04) | |
| "Include photos (N)" counts it; thumbnail opens it (AC-12) | |
| Share sheet shows the 30-day public warning (AC-12) | |
| Shared page shows the photo beside its words (AC-12) | |
| Shared link URL | |
| **AC-12** → met / missed | |

## Summary of spec §6 targets

| Target | iPhone | Android |
|---|---|---|
| Camera path cost: exactly 1 extra tap | | |
| Gallery median ≤ camera median + 2 s | | |
| 10 of 10 unusual images in ≤ 60 s, 0 crashes, 0 freezes | | |
| iOS 15+ / Android min SDK; 0 new permission prompts | | |
| Original photo unchanged (AC-13) | | |
| Gallery photo published and seen on the shared page (AC-12) | (one phone) | |

Misses and what was done about each (fix record or sad §11 row):

-

## Automated checks already run (2026-10-06, commit `db8f964`, no phone needed)

| Check | Result |
|---|---|
| `flutter analyze` | 9 issues, all `info`, all pre-existing (8 in `MyCustomPopupMenuController.dart`, 1 in `test/dots_survive_word_focus_test.dart`). No errors, no warnings |
| `flutter test` (full suite) | **All tests passed** (222) |
| `flutter build apk --debug` | Built `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --no-codesign --debug` | Built `build/ios/iphoneos/Runner.app` (Xcode 26.6) |
| `git diff 0fc7939 -- android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist` | Empty: no permission or usage string was added or changed by the feature commits (313ab44, ce01b17, cbc3e23, 54d9708, db8f964) |
| Merged debug manifest (`build/app/intermediates/merged_manifest/debug/...`) | Only `INTERNET` and the AndroidX `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE` |
| QG-3 code check: gallery call | `pickImage(source: ImageSource.gallery, requestFullMetadata: false)` in `lib/features/word_input/word_input_screen.dart` |
| ADR-0001: Photo Picker turned on | `useAndroidPhotoPicker()` in `lib/main.dart` sets `ImagePickerAndroid.useAndroidPhotoPicker = true` |
| Platform floors | iOS deployment target 15.0 (Podfile and project); Android `minSdk = flutter.minSdkVersion` |

Note: `ios/Runner/Info.plist` already had `NSPhotoLibraryUsageDescription` before this feature. With
PHPicker and `requestFullMetadata: false` it should never be shown; section 1 confirms that on the iPhone.

Toolchain: Flutter 3.35.1 (stable), Xcode 26.6, macOS 26 (Darwin 25.6.0).
