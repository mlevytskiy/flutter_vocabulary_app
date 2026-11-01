# Folder layout — flutter_vocabulary_app

Moved here from `docs/architecture.md` §1 on 2026-10-30. Look things up here or with grep; keep it in step with `lib/` when you add or move files.

```
lib/
  main.dart                     runApp(AppRestarter())
  app_restarter.dart            ProviderScope(child: App()) that can be dropped and built again
                                (new-user-trial: the data moves while nothing holds the database)
  app.dart                      MaterialApp.router — the chosen theme; TrialFrame draws the
                                new-user trial's red line over every screen
  router/
    routes.dart (+ routes.g.dart)   the ONLY place routes are declared (go_router_builder)
    start_location.dart         the start screen: Words when left < 5 min ago or the only
                                collection is empty, else Collections; `main` sets it before
                                the first frame (start-screen, owner 2026-10-18)
  config/
    vocab_api_config.dart       the Worker URL + secret as constants — kept, gitignored, as today
    azure_config.dart           pre-existing, untouched by this plan
  core/
    providers.dart (+.g)        providers for services: photoScaler, imagePicker (camera/gallery
                                picks, photo-from-gallery), vocabPhotoService, collectionStore,
                                googleTranslateService, pronunciationService, collectionPublishService,
                                collectionById, dictionaryService (definition-mode),
                                sourcePhotoStore, photoUploadService (keepAlive, so uploads outlive
                                the words table; good-looking-web); plus the
                                dragMode display preference (task-13) and the persisted
                                wordDetailMode preference (definition-mode)
    models/                     vocab_word.dart — moved, unchanged
                                word_pair.dart (+.g) — Isar @embedded row: the two strings plus the
                                dots/lightning extras that make a restored row look untouched;
                                sourceId links a recognised row to its photo (good-looking-web)
                                word_collection.dart (+.g) — Isar @collection: a set of words with an
                                identity and timestamps (task-03); its sources (photos taken, in
                                order) and the publishedId + editToken a republish overwrites
                                (good-looking-web, ADR-0008)
                                session_source.dart (+.g) — Isar @embedded SessionSource: where words came from.
                                SourceKind { photo, set, subtitles } (stored as the ordinal: photo
                                first, so older records read as photos; new kinds only appended);
                                id (the declared source id), fileName, takenAt, for a set its
                                name + plain url, for subtitles the film/episode title as name
                                (never published: the Worker knows photo and set only). Stored
                                name stays SourcePhoto (good-looking-web; import-from-quizlet,
                                ADR-0005; side-panel-sources AC-22)
                                name_kind.dart — NameKind { undefined, auto, byUser } (ordinal stored;
                                collection-naming): "Vocabulary N" until 5 words, then the AI's name
                                (collection_naming_service.dart → Worker POST /collections/name), a
                                typed name for good; WordCollection.nameKind, written only by the store;
                                WordCollection.descriptionKind the same for the description: empty until
                                20 words, then the AI's (POST /collections/description), unless typed
                                At launch, every collection still waiting for either goes to the AI in
                                one request (POST /collections/autofill, ≤100, newest first); Collections
                                settings' "Replace all date names" does the same for every date name
                                tag_kind.dart — TagKind { origin, topic } (ordinal stored; collection-tags);
                                tag_library_entry.dart (+.g) — Isar @collection TagLibraryEntry {kind, key,
                                text, lastUsedAt, forgotten}, unique (kind, key); effective_tags.dart — legacy
                                tags read as topic tags until the migration ran. WordCollection gains
                                description, originTags, topicTags; SessionSource originTags, topicTags
                                word_result.dart (+.g) — Isar @embedded WordResult {rowId, exerciseId,
                                label known/repeat, at}: WordCollection.results, append-only, at most 2000;
                                never in a row, a publish or an export (learn-kit S-22)
                                word_box.dart (+.g) — Isar @embedded WordBox {rowId, word, box 1-5, dueAt,
                                lastUpDay}: WordCollection.boxes, the Leitner boxes (learn-redesign ADR-0001);
                                put() keeps the stored boxes, only update() writes them
                                translation_result.dart (Google's dictionary block)
                                definition_result.dart (the Worker's dictionary answer:
                                senses / not found / unavailable; definition-mode)
    theme/                      app-themes; import app_theme.dart (exports the rest).
      app_decor.dart            AppDecor (every colour a screen used to hard-code, the Collections
                                pictures' shades, row shape, blur, backdrop; defaults = Classic),
                                AppBackdrop, DecorSurface, LiveBlur (on Android a DecorSurface
                                blurs live only under a LiveBlur — the main screen's dragged row —
                                since at rest only the smooth backdrop is under a row and a
                                live blur costs a full-screen pass per animated frame; owner,
                                2026-10-18)
      theme_kit.dart            AppThemeSpec, buildTheme, seedScheme, withDisplayFont
      themes/                   one file per theme (classic, aurora, matcha, amber_terminal,
                                windows95); themes.dart = AppThemeId + appThemes and how to add
                                one. The choice is the persisted appThemeNotifier in
                                providers.dart, shown on the App settings page
    services/                   photo_scaler.dart, vocab_photo_service.dart,
                                collection_store.dart (persistence: Isar + the current-session pointer,
                                and beside it the History pick record — session id + time,
                                edit-session-from-history ADR-0002)
                                google_translate_service.dart + translate_response_parser.dart
                                (translate_a/single with dt=t,bd,at + the part-of-speech rule)
                                pronunciation_service.dart (task-04)
                                collection_publish_service.dart (task-05: POST /sessions → public link;
                                sends the word detail mode + definitions, definition-mode; with
                                every set and, with "Include photos" on, every photo that has a
                                linked row (no cap; each with its kind, a set with name +
                                url) and each row's sourceId; republishes with the stored token,
                                good-looking-web)
                                dictionary_service.dart (definition-mode: POST /define on the Worker)
                                new_user_trial.dart (new-user-trial: moves the documents dir and
                                every preference to new_user_backup/ in the support dir, and back)
                                source_photo_store.dart (the kept 1600 px photo files under
                                source_photos/ in the documents dir; never throws, good-looking-web)
                                photo_upload_service.dart (background POST /sessions/<id>/sources/
                                <sourceId> after a publish, retried with growing pauses; the link
                                dialog never waits for it, good-looking-web)
                                system_gesture_exclusion.dart (side-bar-for-main-screen ADR-0002:
                                the vocab/system_gesture_exclusion channel; MainActivity keeps the
                                photo tab's screen edge from Android's Back gesture)
                                tag_rules.dart (collection-tags: pure tag rules — 1-30 chars,
                                10 per kind, case-insensitive keys, presets, legacy sort, word-start
                                matching, suggestion ranking)
                                collection_search.dart (collection-tags: CollectionSummary, search,
                                filters, calendar-day ranges, sort, tag counts; pure)
                                collection_search_scope.dart (collections-search: the matches split
                                by the open folder — here / deeper / elsewhere —, the pruned route of
                                the Match outside sheet, live tag counts; pure). The sheet is
                                features/collections/match_outside_sheet.dart
                                collection_store.dart also holds the tag writes (setDetails,
                                saveSourceNote, addCollectionTags, forgetTag), the one-time typed-tag
                                migration and watchSummaries() (ADR-0004/0003/0006/0009 of collection-tags)
                                quizlet_link.dart (import-from-quizlet: pure rules — find a set link
                                in pasted text, the plain https://quizlet.com/<id>/<name>/ form the
                                Worker accepts, which web view navigations may be followed)
                                quizlet_page_script.dart (the thin JavaScript the web view runs on
                                a set page; returns raw JSON, no interpretation)
                                quizlet_set_parser.dart (parseQuizletPage: raw JSON → set found /
                                robot check / nothing yet; never throws)
                                quizlet_cards.dart (cards → proposed words: a Ukrainian back is
                                the translation, any other the definition; cleaning, the 500
                                character cut, duplicates, skipped cards, the numbers the results
                                dialog names)
                                story_api_service.dart (mnemonic-story: the Worker's /story/* routes —
                                offered AI list, grouping split, start, status, redo, picture bytes;
                                30 s timeout, throws StoryApiException)
                                learn_api_service.dart (learn-kit: POST /learn/data — typed per
                                LearnDataKind, 30 s — and POST /learn/check, 15 s; throws
                                LearnApiException)
                                talk_api_service.dart (learn-redesign: POST /learn/talk start/reply, 15 s;
                                throws TalkApiException dayLimit/failed/network)
                                openai_voice_service.dart (openai-voice: POST /learn/speech → mp3 bytes,
                                20 s; throws OpenAiVoiceException dayLimit/unavailable/failed/network;
                                splitForSpeech; VoiceSource) and voice_player.dart (VoicePlayer,
                                AudioplayersVoicePlayer on audioplayers); PronunciationService speaks
                                Talk's lines with them per learn.voiceSource, the phone voice on failure
                                speech_input.dart (learn-redesign ADR-0009: SpeechInput over
                                speech_to_text or speech_to_text_pro, picked by the persisted
                                SpeechEngine in Learn settings; speechInputProvider)
                                learner_profile_store.dart (learn-warm-up-v2 ADR-0001: LearnerProfileStore —
                                level, goal, daily context, warm-up round and counters in ONE preferences value)
                                warm_up_reaction_service.dart (learn-warm-up-v2 ADR-0003: the free one-line
                                reaction call, 2 s cutoff, fixed-line fallback, no retry)
                                learn_events_service.dart (learn-warm-up-v2 ADR-0007: POST /learn/events,
                                fixed names and values only, fire and forget)
                                exam_result_sink.dart (learn-kit: ExamResultSink, StoreExamResultSink —
                                Step 3 word results onto the session via appendResult; latest per row)
                                story_run_store.dart (Isar StoryRun: put/byId/watch; nothing is ever
                                removed) and StoryPictureStore (mnemonic_pictures/<runId>-<attempt>.jpg,
                                at most 3 MB each)
    story/                      mnemonic-story logic shared by several features (rule 3 below):
                                word_grouping.dart (pure: group sizes 7..19, "All words" / "New words",
                                groupedWordsKey, planGrouping, applySplit)
                                word_groups_notifier.dart (+.g) (grouping a session, the selected
                                group; keepAlive, per session)
                                story_run_tracker.dart (+.g) (starts runs, polls the Worker every 5 s,
                                collects stories and pictures onto the phone; read once in app.dart;
                                startScene for a dialogue group's scene picture)
    dialogues/                  film dialogues (get-words-from-subtitles-improvment), shared by
                                words, learn, dialogue and words_table:
                                dialogue_match.dart (pure AC-05 rule: does a word appear, and where;
                                tested against the Worker's match-cases.json)
                                dialogue_rules.dart (pure: atDone, afterEdit, afterPublish, cardName)
                                dialogue_push.dart (+.g) (keepAlive outbox: appends an import's rows
                                and dialogues to a shared link, uploads scene pictures, retries;
                                read once in app.dart)
    widgets/                    synced_text_field_row.dart — moved, unchanged
  features/
    words/                            the Words screen (word_input until 2026-10-18; route /words)
      words_screen.dart          the screen: composes widgets below, owns controllers/focus as today
      word_rows.dart                  (notes-editing) part of words_screen.dart: mixin _WordRows,
                                      the per-row lists, lightning rules, translate / definition /
                                      pronunciation actions and the row widget, CUT unchanged from the
                                      screen so the Notes words dialog edits rows the same way
      source_words_dialog.dart        (notes-editing) part of words_screen.dart: a source's words
                                      as main-screen rows + a dashed "+ Add a word"; writes straight
                                      into the session, and the main screen rebuilds its rows from it
                                      when Notes closes (markEditedElsewhere / takeEditedElsewhere)
      quizlet_read_controller.dart    waits for and decides a read: 30 s limit per phase, clock paused
                                      during a robot check; outcomes succeeded / failed / cancelled
      quizlet_import_flow.dart        runQuizletImport: link dialog → progress dialog (reads, shows
                                      the cards, Cancel still works; no machine translation) → results
                                      dialog → addWords on Done; a result for another session is dropped
      words_notifier.dart (+.g)  AsyncNotifier<WordCollection> + the launch rule + debounced save()
                                      + switchTo(id): makes a History session current without
                                      stamping it (edit-session-from-history); every save runs the
                                      dialogue edit rule; addImportDialogues keeps an import's
                                      dialogues (get-words-from-subtitles-improvment)
      subtitle_import_flow.dart       runSubtitleImport: import dialog → the phone picks the words →
                                      progress dialog while they are translated → results → Done;
                                      with "Get dialogues from subtitles" on it also asks for film
                                      dialogues and hands them over after the words
      photo_panel/                    (side-bar-for-main-screen) the photo tab and panel on the words
                                      page: photo_panel.dart (behaviour: closed / half-open /
                                      full-open), photo_panel_controller.dart, photo_panel_stops.dart,
                                      photos_with_words.dart (+.g), photo_preview.dart, row_jump.dart;
                                      looks/: photo_panel_look.dart (the interface, tab ≤ 200 dp),
                                      look_a.dart (the one look, picked 2026-10-14) and edge_glass.dart
                                      (photo-panel-glass); photo_panel_host.dart (words-photo-panel):
                                      the PhotoPanelHost mixin both hosting screens use (the controller,
                                      the guard that closes an open panel on a touch, the highlight);
                                      PhotoPanel(collectionId:) lists a stored collection's sources
                                      (storedSourcesWithWordsProvider) instead of the current one's
      lightning_rules.dart            two pure lightning predicates, cut unchanged (see step 4 findings)
      widgets/                        pieces CUT from words_screen.dart, code unchanged:
        word_row_item.dart              _buildItem
        word_row_morph.dart             (photo-panel-glass) while the photo panel is open each row
                                        glides, top to bottom, into CompactWordLine — one line,
                                        "word — translation" (the definition when there is no
                                        translation or the mode shows none) — and back on close
        translation_dots_button.dart    _buildTranslationDotsButton (popup_menu_2 stays)
        still_body.dart                 StillBody / StillBodyWhileMounted: on Android the main
                                        screen's body is one picture (SnapshotWidget) while the
                                        side menu is on screen — the Scaffold builds the drawer's
                                        child only then — so a frame of the menu's slide does not
                                        draw Aurora's row blurs again (owner, 2026-10-18)
        vocab_result_dialog.dart        showVocabResultDialog (was _showVocabResultDialog) and
                                        showQuizletResultDialog (set name, "Read X of Y", skipped
                                        cards, "No new words in this set.")
        quizlet_link_dialog.dart        showQuizletLinkDialog: how-to animation, paste text, refuses
                                        text without a set link
        quizlet_link_how_to.dart        the link dialog's animation (open set, Share, Copy link, paste)
        quizlet_logo_icon.dart          the + menu's painted white Quizlet-like "Q"
        photo_source_dialog.dart        showPhotoSourceDialog: Camera / Photos as two side-by-side cards
        subtitle_search_dialog.dart     showSubtitleSearchDialog: "Find by name" in the import dialog —
                                        English subtitle files found by film or series name
                                        (OpenSubtitles through the Worker's GET /subtitles/search and
                                        POST /subtitles/file, SubtitleSearchService); the picked file
                                        is imported like one chosen from the phone
        subtitle_progress_dialog.dart   showSubtitleProgressDialog: a pager of the picked words with
                                        their context lines and skeleton translations, swipeable
                                        while the translation runs; then filled and scrolled on to
                                        the last card
        quizlet_progress_dialog.dart    showQuizletProgressDialog: a pager of skeleton cards, then the
                                        set's cards (scrolled first to last), over a hidden web view
                                        of the set page (webview_flutter); the page is shown full
                                        size only while Quizlet's robot check is on screen
        translation_options_content.dart  the dots popup's body: dictionary chips by part of speech
        words_speed_dial.dart      the FAB (flutter_speed_dial stays); "From subtitles" dark grey
                                        with the captions icon; it shares the Scaffold's floating-button
                                        slot with the Settings button, so both rise above a SnackBar
    words_table/
      words_table_screen.dart         reads words from the notifier (no sessionId) or from
                                      sessionByIdProvider (a History row), read-only either way;
                                      Share → bottom sheet: file (TSV) or link (publish, task-05);
                                      the photo tab and panel as on the main screen (words-photo-panel:
                                      while open the table cross-fades into one line per row; Notes
                                      only for the current collection); include_photos.dart: the
                                      "Include photos (N)" value (includePhotosProvider, per collection
                                      id, not saved; photos only, Quizlet sets are always sent), its
                                      switch with stacked thumbnails (widgets/photo_stack.dart) is in
                                      the Words settings; the sheet warns about public photos and that
                                      a republish replaces the partner's edits (good-looking-web);
                                      a History session that is not current gets a red Edit FAB →
                                      "Do you want to edit…?" → switchTo + WordInputRoute().go
                                      (edit-session-from-history)
    notes/                            (notes-page, notes-editing) notes_screen.dart: one pager per
                                      panel source — note (title, description, links, tags), picture
                                      (pinch zoom, tap → PhotoViewerRoute), words (tap → the words
                                      dialog); the collection's origin + topic tag fields above the
                                      list, two typed fields per source note (collection-tags T12).
                                      tag_editor.dart (the old untyped chips editor),
                                      photo_viewer_screen.dart
    tags/                             (collection-tags) tag_chip.dart (one chip look per TagKind),
                                      typed_tag_field.dart (hint, examples, ranked suggestion row,
                                      autocomplete, limits, long-press Forget), tag_suggestions.dart
                                      (+.g: tagSuggestions(kind) = library + live use counts + presets)
    learn/                            lib/features/learn/ (learn-part-step-1): pick exercises to practise a session's words;
                                      the Worker side is vocab-photo-api/src/learn/. learn-redesign (2026-10-23):
                                      Learn opens the Learn sheet; the old learn page opens only from Try it
      entry/                          (learn-redesign) learn_sheet.dart (Exercises / Talk with AI, counts, split
                                      checkbox from 20 words), companion_button.dart (alone / teacher / friend
                                      "Soon" beside Learn), learn_presets.dart (Quick / Balanced / Deep / Custom),
                                      learn_settings_screen.dart (presets, switches, words per session, Try it,
                                      speech engine)
                                      learner_profile_section.dart (learn-warm-up-v2) the learner profile in Learn settings:
                                      level, goal, daily context; change or clear each
      flow/                           (learn-warm-up-v2) warm_up_plan.dart (pure plan: intro, reaction, main question,
                                      grammar every 5th warm-up; ADR-0002), grammar_rules.dart (the fixed rule list
                                      per level), warm_up_view.dart (the warm-up drawn as a dialog), learn_flow_notifier
      session/                        (learn-redesign) leitner.dart (WordBox rules, applySession), session_words.dart
                                      (which words a session takes; session groups of 7-12), ladder_queue.dart
                                      (word ladder Meet/Practise/Use), exercise_page.dart + page_input.dart +
                                      page_registry.dart (each exercise's <x>_pages.dart page source and
                                      <x>_page_body.dart, ADR-0003), learn_page_frame.dart (card-and-check frame,
                                      AppDecor.learnRight/learnWrong), learning_session_notifier/screen
                                      (LearningSessionRoute), session_result.dart (finishSession: one
                                      CollectionStore.update; lastSessionResultProvider), session_results_screen
                                      (SessionResultsRoute)
      talk/                           (learn-redesign) talk_rules.dart (used words by matchPlaces, hints, scoring),
                                      talk_notifier.dart, talk_screen.dart (TalkRoute; hold-to-talk via
                                      speechInputProvider, replies spoken by PronunciationService)
      exercises.dart                  Exercise (id, name, stage, available) + the const list of thirteen (learn-kit),
                                      tested against the Worker's exercises.json (ADR-0003)
      learn_screen.dart               the learn page: ticks live in widget State, nothing is saved;
                                      reads the current session or a History row (LearnRoute);
                                      "Dialogs from movie" only with dialogues; Start opens the
                                      ticked exercises one after the other
      coming_soon_screen.dart         what Start opens while the picked exercise is not built
                                      (ComingSoonRoute carries the exercise id)
      exercise_screens.dart           exerciseScreen: ExerciseRoute's switch on the exercise id (one case
                                      per built exercise); anything else is the coming-soon screen (learn-kit)
      kit/                            (learn-kit) the frame and helpers every exercise shares:
                                      exercise_phase.dart (ExercisePhase states, ExerciseFailure, failureOf),
                                      exercise_scaffold.dart (ExerciseScaffold: loading / failed / not enough /
                                      round / summary; optional againLabel / onAgain extra summary button, S-56),
                                      result_summary.dart (ResultSummary, WordOutcome with optional detail line,
                                      examHeading "N of n known"; S-55, S-56),
                                      split_rounds.dart, question_builder.dart (buildQuestion, QuestionPool),
                                      typed_match.dart (matchTyped), typed_answer_field.dart (practice / exam),
                                      word_marks.dart (maskWord, boldWord, holdsWordOnce), check_verdict.dart
                                      (judgeCheck, sentenceProblem), check_result_line.dart,
                                      exercise_words.dart (+.g) (exerciseWordsProvider: group + other words)
                                      exercise_random.dart (exerciseRandomProvider: the one Random, S-27),
                                      choice_options.dart (ChoiceOptions: four-option widget, S-28)
                                      example_line.dart (exampleLineFor: dialogue example line, S-31); exercise_words.dart also has exerciseDialoguesProvider
                                      match_rounds.dart (MatchPair, usableMatchPairs, MatchRound, shuffledOutOfOrder, MatchRoundsState, matchSummaryDelay; S-41)
                                      definition_text.dart (definitionText, definitionCard: definition line, mask, cut; S-40)
                                      gap_question.dart (GapQuestion, gapFromText, gapFromDialogues, loadGapQuestions, GapPrompt; S-43..S-45)
                                      match_board.dart (MatchBoard + MatchItem + MatchCard: the two-column match round, cardText, missesText; S-35..S-37)
                                      sentence_check.dart (SentenceCheckField practice / exam, SentenceResult, SentenceOutcome, practiceLabel, examLabel, examSummaryText; S-47, S-48; optional timeLimitSeconds and SentenceResult.timedOut, S-61); check_result_line.dart bolds the word in the fix (S-49)
                                      exam_countdown.dart (ExamCountdown "m:ss", onZero once, countdownText; S-61); check_verdict.dart's explain branch refuses the word and Ukrainian letters with fixed notes (S-62)
      pick_the_answer/                (learn-pick-the-answer) Step 1 exercise, no network, nothing saved
        pick_the_answer_notifier.dart (+.g)  PickTheAnswer notifier (usable words, rounds, kinds) + PickState
        pick_the_answer_screen.dart   PickTheAnswerScreen: the question body inside ExerciseScaffold
      remember_or_not/               (learn-remember-or-not) Step 2 flashcards, no network, nothing saved
        remember_or_not_notifier.dart (+.g)  RememberOrNot notifier (fronts, rounds, shuffle, repeat queue) + RememberState
        remember_or_not_screen.dart   RememberOrNotScreen: card front/back, PronunciationButtons, ratings inside ExerciseScaffold
      match_synonyms/                 (learn-match-synonyms) Step 1 match board, one Worker call per open, nothing saved
        match_synonyms_notifier.dart (+.g)  MatchSynonyms notifier (own build/retry/pair/nextRound; shared round code in kit/match_rounds.dart)
        match_synonyms_screen.dart    MatchSynonymsScreen: round counter, line and MatchBoard inside ExerciseScaffold
      guess_my_word/                  (learn-guess-my-word) Step 1 graded-clue riddle: three masked clues per word, tap the word in a grid; one data call (kind clues) per open, nothing saved
        guess_my_word_notifier.dart (+.g)  GuessMyWord notifier (clues S-51, rounds and scoring S-52) + GuessState, GuessRound, GuessWord
        guess_my_word_screen.dart     GuessMyWordScreen: counter, clues so far, 3-per-row grid with long-press translation, outcome line inside ExerciseScaffold
      match_definitions/              (learn-match-definitions) Step 1 match word and definition on the same board; stored definition line first, else one Worker call
        match_definitions_notifier.dart (+.g)  MatchDefinitions notifier (stored/Worker definitions, rounds, links, misses) on MatchRoundsState
        match_definitions_screen.dart MatchDefinitionsScreen: round counter, line and MatchBoard inside ExerciseScaffold
      fill_the_gaps/                  (learn-fill-the-gaps) Step 2 type the missing word; dialogue sentence first, else one Worker call, nothing saved
        fill_the_gaps_notifier.dart (+.g)  FillTheGaps notifier (gap questions, rounds, results, score) + FillState
        fill_the_gaps_screen.dart     FillTheGapsScreen: GapPrompt + TypedAnswerField (practice) inside ExerciseScaffold
      quiz/                           (learn-quiz) Step 3 exam: up to 7 mixed choice + gap questions (S-53, S-54); one sentence data call per open, a failure runs choice only; the first Step 3 writer of word results (S-55 exam-result pattern)
        quiz_notifier.dart (+.g)      Quiz notifier (usable words, quizLayout, answers recorded through examResultSinkProvider at once, Repeat) + QuizState, QuizQuestion, QuizAnswer, choiceLabel, typedLabel
        quiz_screen.dart              QuizScreen: ChoiceOptions (reveal: false) + Skip, or GapPrompt + TypedAnswerField (exam) inside ExerciseScaffold; summary with details and Repeat
      translate_sentences/            (learn-translate-sentences) Step 3 exam: a Ukrainian sentence with the cue in bold, the learner's English translation checked by the Worker; one translate data call per open; each final word recorded through examResultSinkProvider (S-55); no Repeat (S-58)
        translate_sentences_notifier.dart (+.g)  TranslateSentences notifier (usable cards S-57, rounds of 3–5 shuffled once, done/next/nextRound) + TranslateState, TranslateCard, pure cueSpans, translateDetail
        translate_sentences_screen.dart TranslateSentencesScreen: cue card + SentenceCheckField (exam, task translate) + model translation inside ExerciseScaffold
      own_sentences/                  (learn-own-sentences) Step 3 exam: the word and a prompt only, the learner's own English sentence checked by the Worker (task own); no Worker data call; each final word recorded through examResultSinkProvider (S-55); no Repeat (S-60)
        own_sentences_notifier.dart (+.g)  OwnSentences notifier (usable words S-59, rounds of 3–5 shuffled once, done/next/nextRound) + OwnState, OwnCard, pure ownDetail
        own_sentences_screen.dart     OwnSentencesScreen: word card + SentenceCheckField (exam, task own) inside ExerciseScaffold
      explain_to_friend/              (learn-explain-to-friend) Step 3 exam, mode asked once per open: Type (SentenceCheckField exam, task explain, 90 s) records each final word through examResultSinkProvider (S-55); With a friend (30 s ExamCountdown, Understood / Not yet) has no network and saves nothing (S-64); no Worker data call
        explain_to_friend_notifier.dart (+.g)  ExplainToFriend notifier (usable words S-59, mode, rounds of 3–5 shuffled once, done/friendReady/friendAnswer/next/nextRound) + ExplainState, ExplainCard, ExplainResult, pure explainDetail
        explain_to_friend_screen.dart ExplainToFriendScreen: mode question, Type card, friend card inside ExerciseScaffold
      sentence_patterns/              (learn-sentence-patterns) Step 2 model sentence + pattern, then the learner's own sentence checked by the Worker; one data call per open, nothing saved
        sentence_patterns_notifier.dart (+.g)  SentencePatterns notifier (pattern cards, rounds, My turn, results) + PatternsState, PatternCard
        sentence_patterns_screen.dart SentencePatternsScreen: card, PronunciationButtons (read the sentence), SentenceCheckField (practice) inside ExerciseScaffold
      widgets/group_pager.dart        the group pager on the learn page (a card per word group);
                                      step_progress.dart shows a running run's steps
    mnemonic_story/
      story_screen.dart               the story, its picture (zoomable), progress, failures and
                                      "Make a new story" (StoryRoute: groupId, optional sessionId)
      widgets/new_story_dialog.dart   the new-story confirmation (a dialog, not a route)
      widgets/story_picture.dart      a run's zoomable picture; story_parts.dart the progress label,
                                      messages and buttons (both cut from story_screen.dart)
    dialogue/
      dialogue_screen.dart            "Dialogs from movie" for a dialogue group: the dialogue in bold
                                      under its scene picture, drawing it once (DialogueRoute)
    words_settings/
      words_settings_screen.dart      Words settings (WordsSettingsRoute, from the Words screen's
                                      settings button, with the collection id): the "Include photos (N)"
                                      switch at the top (words-photo-panel), the three AI choices (story writer, picture
                                      prompt writer, picture maker), each list cheapest first with the
                                      average price of past runs and the list price; "Story runs"
      story_runs_screen.dart          every story run on the phone, newest first, with totals
      story_run_screen.dart           one run in full: each step's AI, result, price, time
    app_menu/
      app_drawer.dart                 (navigation, owner 2026-10-18) the side menu every menu screen
                                      shares — Collections, Words, App settings; the three are the
                                      branches of one `MenuShellRoute` (StatefulShellRoute, indexed
                                      stack), kept alive; a tap lets the drawer close, then `go`es to
                                      the other branch, alone on it, so its bar shows the menu button;
                                      BackToCollections: Back on Words or App settings goes to
                                      Collections, the start screen
    settings/
      settings_screen.dart            the drag-and-drop mode switch (task-13) and the word
                                      detail mode — translation / definition / both
                                      (definition-mode); writes dragModeProvider and
                                      wordDetailModeProvider, which the input screen reads;
                                      the subtitle import values and "Get dialogues from
                                      subtitles" (dialoguesSettingProvider)
```

No `packages/`, no workspace, no `feature_*` pub packages. A feature is a folder.

