---
status: Final
owner: "Maksym"
reviewers: ["Tech Lead", "Security Lead"]
updated_at: "2026-10-06"
feature_size: "XS"
---

# Spec — photo-from-gallery

> **Glossary:** [CONTEXT](./CONTEXT.md) · repo-root [CONTEXT](../../../CONTEXT.md) · source photo per [good-looking-web CONTEXT](../good-looking-web/CONTEXT.md)
> **Reference module / docs / channels used:** `lib/features/word_input/word_input_screen.dart` (the photo flow: `_takePhotoForVocabulary`, `_processPickedPhoto`, `_keepSourcePhoto`), `lib/features/word_input/widgets/word_input_speed_dial.dart`, `lib/core/services/photo_scaler.dart`, `lib/features/words_table/words_table_screen.dart` (the "Include photos" switch), [`good-looking-web/spec.md`](../good-looking-web/spec.md) §5 AC-23 and §6.1.

## 1. Context

"Get words from photo" only opens the phone's camera. A learner who already has a page in the phone's photo library has no way to use it: a page photographed earlier, a screenshot of an e-book, a photo a friend sent. They have to retake the photo, and often the page is no longer at hand. Owner's words: "We want to just have options to get image from gallery when we do getting words from photo."

Why now: photo import is the app's main capture path, and the owner keeps finding pages in the photo library that they cannot import. The camera screen belongs to the phone, not to the app. Apple's and Android's camera screen for other apps has no gallery button, and no setting adds one. So the choice has to be offered by the app before either screen opens.

Committed approach: tapping "Get words from photo" shows a small source choice, Camera or Gallery. Both open the phone's own screens: the system camera, or the system photo picker for a single photo. The app draws no capture or picker screen of its own. From the picked photo onward, a successful import is exactly as for a camera shot: recognition of highlighted words with the same word cap, the results dialog, the words added to the current session, and the photo kept as a source photo. Two things are new: failure messages name the gallery when the photo came from it, and only one photo import runs at a time, for Camera and Gallery alike (today a second tap during analysis starts a second import). Comparable products (Google Translate's image mode, Google Lens) offer both sources inside one capture flow but collect no words. The sharpest risk found is a private gallery image being published through the share sheet. It is accepted as the camera's existing risk (§6.1): the Words screen shows the "Include photos (N)" switch with up to three thumbnails (a tap opens all photos), and the share sheet warns that included photos are public for 30 days. Success means a page already in the library becomes session words in one import, while the camera costs exactly one extra tap.

- Decision (owner review, import-from-quizlet, 2026-10-06): the dialog's Gallery choice is labelled "Photos", and Camera and Photos are two bordered cards side by side, each an icon above its name. "Gallery" in this spec means that choice.
- Research footnote: the comparable products were checked on 2026-10-06. None of the pages verified shows a Camera/Gallery dialog, multi-photo import or a remembered last choice. Translate and Lens put a gallery button on their own camera screen, which this app cannot do on the system camera.
- Decision override: product and platform names (Apple, Android, Google Translate, Google Lens) stay in §1 — rationale: they name the phones' own screens and the researched comparables, not technology choices for this feature; same precedent as good-looking-web §1.

## 2. Goals

- A learner can turn any page already in the phone's photo library into words in the current session.
- After a successful pick, a gallery photo behaves exactly like a camera shot: same recognition, same results dialog, same source photo, same publishing. Only its failure messages name the gallery.
- The camera path stays almost as quick as today: one choice before the camera opens, plus the new one-import-at-a-time guard shared by both sources.

## 3. Non-goals

- **Several photos in one import:** the whole photo chain (one recognition request, one word cap, one source photo) is built for one photo. Several pages means several imports.
- **Remembering the last choice or skipping the dialog:** the choice is asked every time. A remembered default is a later step if the extra tap proves annoying.
- **A camera or picker screen drawn by the app:** the phone's own screens do this work, and the owner wants it that way.
- **A different publishing rule for gallery photos:** the "Include photos" switch treats them like camera photos (decision in §6.1). Changing that would change the share sheet of good-looking-web.
- **Removing duplicate words when the same photo is imported twice:** the camera path does not do this today either.

## 4. User stories

### US-01: Choose where the photo comes from

**As a** learner
**I want** to choose Camera or Gallery when I tap "Get words from photo"
**So that** I can either take a new photo or use one I already have

### US-02: Get words from an existing photo

**As a** learner
**I want** to pick one photo from my phone's photo library and get its highlighted words
**So that** I don't have to retake a page I photographed earlier or received from someone

### US-03: Keep the gallery photo with its words

**As a** learner
**I want** a gallery photo whose words I keep to stay with the session, like a camera photo
**So that** I can see, and later share, the page the words came from

### US-04: Back out without side effects

**As a** learner
**I want** to close the choice or the photo library without picking anything
**So that** an accidental tap leaves my session exactly as it was

### US-05: Understand why a gallery photo failed

**As a** learner
**I want** a plain message that names the photo library when a picked photo can't be used
**So that** I know it was that photo, not the camera, and can try another

### US-06: See the page behind shared words

**As a** partner
**I want** to see the page photo beside words that came from a gallery photo, when the learner included photos
**So that** the words have the same context as words from a camera photo

## 5. Acceptance criteria

### AC-01 (US-01) — happy

**Given** a learner is on the word-input screen and no photo import is running
**When** the learner taps "Get words from photo"
**Then** a small dialog offers two choices, Camera and Gallery (labelled "Photos" since the owner review of 2026-10-06, shown as two bordered cards side by side, each an icon above its name), and nothing else opens until one is chosen

### AC-02 (US-01) — happy

**Given** the source choice is shown
**When** the learner chooses Camera
**Then** the phone's camera opens, and everything after the shot behaves as it does today

### AC-03 (US-02) — happy

**Given** the source choice is shown
**When** the learner chooses Gallery and picks one photo of a page with highlighted words
**Then** the app shows that it is analysing the photo, then the results dialog lists the recognised words (no more than the photo word cap of 20), and Done adds the kept words to the current session

### AC-04 (US-03) — happy

**Given** a learner kept at least one word from a gallery photo in the results dialog
**When** the words are added to the current session
**Then** the photo becomes a source photo of that session, and every word row added from it points at it, exactly as for a camera photo

### AC-05 (US-04) — error

**Given** the source choice is shown
**When** the learner closes it without choosing (taps outside it or goes back)
**Then** the dialog closes, nothing opens, no message appears, and the session is unchanged

### AC-06 (US-04) — error

**Given** the learner chose Gallery
**When** the learner closes the photo library without picking a photo
**Then** the app says no photo was picked, without mentioning the camera, the session is unchanged, and no photo is kept

### AC-07 (US-05) — error

**Given** the learner chose Gallery
**When** the picked photo cannot be read (an unsupported format, or a photo stored only online that fails to download)
**Then** the app says the photo from the gallery could not be used and to try another one, no words are added, and no photo is kept

### AC-08 (US-05) — error

**Given** the learner picked an unusual image from the gallery, such as a very tall scrolling screenshot or a very large original
**When** the app processes it
**Then** the app either shows the results dialog or a plain message, never freezes or closes, and keeps no photo when no words are kept

### AC-09 (US-02) — authorization

**Given** a learner has never given the app access to their whole photo library
**When** the learner picks a photo through Gallery
**Then** the app receives only the one photo picked: it does not ask for access to the whole library and does not read or keep any other photo

### AC-10 (US-01) — domain invariant

**Given** a photo import is still being analysed
**When** the learner taps "Get words from photo" again
**Then** no second import starts, and the learner is told that the current photo is still being analysed ("one photo import at a time")

### AC-11 (US-03) — domain invariant

**Given** a learner picked a gallery photo
**When** the results dialog closes with no word kept (every word removed, or the dialog cancelled)
**Then** the photo does not become a source photo: the app keeps no copy of it as a source photo and it is not offered when publishing ("a photo becomes a source photo only when at least one of its words is kept")

### AC-12 (US-06) — cross-context

**Given** a session has a source photo that came from the gallery
**When** the learner shares the session as a link
**Then** that photo counts in "Include photos (N)" on the Words screen and is among the photos its thumbnails open, the share sheet gives the same warning that included photos are public for 30 days, and with the switch on the partner sees it on the shared page beside its words

### AC-13 (US-02) — cross-context

**Given** a learner picked a photo through Gallery
**When** the import succeeds, fails, or is cancelled
**Then** the original photo in the phone's photo library is unchanged: it is not moved, edited or deleted

## 6. Non-functional requirements

| Aspect | Target | Measurement |
|---|---|---|
| Camera path cost | exactly 1 extra tap (the source choice) between "Get words from photo" and the camera | device pass on the owner's phone at release |
| Gallery photo to results dialog (photo stored on the phone) | median ≤ camera median + 2 s | stopwatch on the device from the moment the photo is picked (or the shutter confirmed) to the results dialog; 5 runs each path on the same printed page, gallery runs using one of those camera shots |
| Robustness on unusual images | 10 of 10 test images end in the results dialog or a plain message within 60 s, with 0 crashes and 0 freezes | device pass with a fixed set: JPEG page photo, PNG screenshot, HEIC photo, a 1080×20000 screenshot, a ≥48 MP original, a photo stored only online, a non-image-looking meme, and 3 page photos |
| Platforms | iOS 15+ and Android at the app's current minimum SDK; 0 new permission prompts | device pass on one iPhone and one Android phone |

## 6.1 Security / privacy

- **Data classification:** internal. Same as camera photos, but a gallery image can be private as a whole (a chat screenshot, a letter), not just in the background.
- **Personal data touched:** gallery photos the learner picks. No new stored fields. The kept copy follows the existing source-photo rules (good-looking-web).
- **AuthZ/AuthN impact:** none added. The app gets only the photo the learner picks through the phone's picker and asks for no access to the whole library (AC-09).
- **Abuse cases:**
  - Private gallery image published: **accepted, same as camera** (re-confirmed by the owner after the critic pass). The Words screen shows the "Include photos (N)" switch, on by default, with up to three stacked thumbnails; a tap opens all photos. The share sheet warns in text that included photos are public for 30 days (good-looking-web AC-23). Catch: with four or more photos, a private screenshot can be published without its thumbnail ever being on screen, and it can't be deleted (good-looking-web D4).
  - Whole image sent for recognition before the learner sees results: accepted, same as camera. The learner chose the photo.
  - Same photo imported twice: the words and the source photo are duplicated, using up a photo slot when publishing. Accepted, as on the camera path (§3).
- **Security review:** N/A. There is no new surface, permission or stored field. Publishing consent is the existing good-looking-web switch.

## 7. Metrics / KPIs

- **Pages imported from the gallery:** baseline 0 (impossible today), target ≥ 5 photo imports from the gallery within 30 days of release, counted by the owner.
- **Gallery import success on page photos:** baseline none, target ≥ 9 of 10 gallery photos of highlighted pages give their words in the device pass at release.
- **Camera path cost:** baseline 1 tap from "Get words from photo" to the camera, target exactly 2 taps with no other change, checked at release.

## 8. Open questions

- [ ] What should happen to very tall screenshots, whose shorter side is small so they stay huge after scaling: shrink by the longer side, or refuse with a message? (Splitting one image into several recognition requests is out of scope for this XS feature, §3.) Default now: treated like any image; they may return no words, but must satisfy AC-08. — owner: Maksym, due: before `sdd:design`
