# learn-welcome — device check (owner)

## Worker deploy (before the device check)

Needed for `/learn/topics`, the talk `topic` / `maxReplies` fields, story extras and the `/analyze` context:

```
cd vocab-photo-api && npm run deploy
```

The owner runs it or approves it. Without it the warm-up topics fall back and the new fields are ignored.

## Checklist

- [ ] Learn on 3 words, 8 words, 20 words and 40 words: each opens the right flow (warm-up, cards, story, main dialog, results).
- [ ] Warm-up: three topics are offered; pick one; also type an own topic, and say one by voice.
- [ ] Dialog length: Hard gives a longer dialog than Easy.
- [ ] Cards flip and can be rated (self-check).
- [ ] Landscape: the story page after card 12; the wait page while the story loads; Skip works.
- [ ] Leave midway (leave dialog) from each stage: nothing breaks, progress is kept as designed.
- [ ] Main dialog, then the results screen and each of its buttons.
- [ ] Everything outside the Learn flow stays in portrait.
- [ ] Test on iPhone and Android (landscape and back to portrait).
- [ ] iPad: `UIRequiresFullScreen` turns off Split View / Slide Over. Owner to confirm this is acceptable.
