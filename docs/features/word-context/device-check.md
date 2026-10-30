# word-context — device check (owner)

Run after the Worker is deployed (see the end). Tick each line on a phone.

1. **Photo import.** Add words from a photo. Open one word's popup on the Words screen: the context sentence shows in
   italic with its label ("from the photo"). Try a few words from different photos.
2. **Film found by name.** Import words from a film found by name. Open a word's popup: the context line is the film
   dialogue line, labelled with the film. The film name, season and episode are saved on the row (the popup context
   label shows them). The time is saved too but is not shown anywhere in the UI.
3. **Subtitle file.** Import words from a subtitle file. Same check as 2: popup shows the line and the film name,
   season, episode where the file name gives them; time is stored, not shown.
4. **Typed word.** Type a word and a definition, then tap its lightning. The popup shows a dictionary example as the
   context.
5. **Edited translation.** Change a translation by hand (or pick another in the menu). Nothing changes on screen: the
   row only gets an "edited by learner" flag, which stories later use. Changing only a definition also lets the
   background fill try the row's context again.
6. **Relaunch.** Close and reopen the app. Old words without a context fill slowly in the background (at most 20 a
   minute); reopen a popup after a few minutes to see them appear.

## Worker deploy

`/analyze` (full_text, context_source) needs the new Worker. From the repo folder:

```
cd vocab-photo-api && npm run deploy
```

The owner runs this or approves it. Until then photo words get no context.
