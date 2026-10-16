part of 'word_input_screen.dart';

/// The main screen's word rows, cut from `WordInputScreen` so the Notes words
/// dialog edits a source's rows the same way (notes-editing, owner
/// 2026-10-15): the parallel per-row lists, the lightning rules, the
/// translate / definition / pronunciation actions and the one row widget. A
/// state that mixes it in owns [_wordPairs] and says where its rows live in
/// the session ([_storeIndex]).
mixin _WordRows<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The rows on screen, in order.
  List<WordPair> get _wordPairs;

  /// Where row [index] on screen is in the session's words.
  int _storeIndex(int index) => index;

  /// Keeps one blank row at the end (main screen) or nothing (Notes dialog).
  void _checkAndAddNewPair();

  /// Takes the main screen's RESTORE snackbar down on the first edit.
  void _dismissRestoreSnackBar() {}

  /// Row [index] was just taken out of the session's words at [storeIndex].
  void _onRowRemoved(int index, int storeIndex) {}

  /// The main screen never removes its first row, it only clears it.
  bool get _keepsFirstRow => true;

  final List<TextEditingController> _wordControllers = [];
  final List<TextEditingController> _translationControllers = [];
  final List<bool> _isLoadingTranslation = [];
  // Loading state for the Word icon's own translate action (Translation ->
  // Word), tracked separately from _isLoadingTranslation so the two
  // corners' spinners never interfere with each other.
  final List<bool> _isLoadingWordTranslation = [];
  // Google's dictionary block per row -- the set of translations grouped by
  // part of speech that the last translate brought back, reused by the dots
  // popup so opening it costs no second request. Dropped whenever the Word
  // field changes, so the popup never shows another word's translations.
  final List<TranslationResult?> _translationOptions = [];
  // The trimmed Word text each cached block in _translationOptions was fetched
  // for. The dots show a block only while the current Word still equals this,
  // so editing the word hides it and reverting the edit brings the same block
  // back -- the cache itself is never dropped on a keystroke (see
  // _effectiveOptions and docs/lightning_icon_rules.md).
  final List<String?> _optionsWord = [];
  // "Translation filled" per docs/lightning_icon_rules.md: true once the
  // Translation field was auto-populated (AI translate, picking a popup
  // option, or photo recognition) -- independent of the >5-character rule.
  final List<bool> _translationMarkedFilled = [];
  // "Word filled" counterpart -- true once the Word field was
  // auto-populated (photo recognition, or a real translate-to-Word result
  // via the Word icon). See docs/lightning_icon_rules.md.
  final List<bool> _wordMarkedFilled = [];
  // definition-mode (sad §5): the Definition field's per-row state, kept in
  // lockstep with the Translation lists above. Which fields are *shown* is the
  // word detail mode's business; these always exist so switching modes never
  // loses a definition.
  final List<TextEditingController> _definitionControllers = [];
  final List<FocusNode> _definitionFocusNodes = [];
  final List<bool> _isLoadingDefinition = [];
  final List<bool> _definitionMarkedFilled = [];
  // The dictionary senses fetched for a row and the Word they were fetched
  // for. Hidden while the Word differs and not persisted then, so a Word edit
  // drops the senses but never the definition text (spec §8, resolved) --
  // the same keying _translationOptions / _optionsWord use.
  final List<List<String>?> _definitionSenses = [];
  final List<String?> _sensesWord = [];
  // Per-row focus tracking for the "item in focus" rule (see
  // docs/lightning_icon_rules.md): a lightning icon only ever shows while
  // its own row (word or translation field) currently has focus.
  final List<FocusNode> _wordFocusNodes = [];
  final List<FocusNode> _translationFocusNodes = [];
  final Map<int, CustomPopupMenuController> _popupControllers = {};
  // The definition dots' popup controllers, per row -- kept exactly like
  // _popupControllers (same pruning), for the same package reasons.
  final Map<int, CustomPopupMenuController> _definitionPopupControllers = {};

  void _addControllersForIndex(int index) {
    final wordController = TextEditingController(text: _wordPairs[index].word);
    final translationController = TextEditingController(text: _wordPairs[index].translation);
    final wordFocusNode = FocusNode();
    final translationFocusNode = FocusNode();
    final definitionController = TextEditingController(text: _wordPairs[index].definition);
    final definitionFocusNode = FocusNode();

    // Rebuild on focus change so the lightning icons can appear/disappear
    // per the "item in focus" rule (docs/lightning_icon_rules.md).
    wordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    translationFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    definitionFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    wordController.addListener(() {
      // Only a real edit dismisses the RESTORE snackbar: focus/selection changes
      // also notify the controller (e.g. the post-restore requestFocus), and
      // those must not take it down.
      final wordChanged = wordController.text != _wordPairs[index].word;
      if (wordChanged) _dismissRestoreSnackBar();
      _wordPairs[index].word = wordController.text;
      _checkAndAddNewPair();

      // Якщо word повністю видалений, скинути "filled"-мітку
      final wordIsEmptyNow = wordController.text.isEmpty;
      final shouldResetWordFilledMark = wordIsEmptyNow && _wordMarkedFilled[index];

      setState(() {
        if (shouldResetWordFilledMark) {
          _wordMarkedFilled[index] = false;
        }
        // The cached dictionary is NOT dropped here. It stays keyed to the word
        // it was fetched for (_optionsWord[index]); the dots derive their state
        // from _effectiveOptions, which hides the block while the Word text
        // differs and shows the same block again once the text is reverted. A
        // bare focus/selection notification (this listener also fires on those)
        // therefore leaves the dots untouched. The empty-dots popup still
        // offers the update icon whenever the block is hidden.
      }); // Оновити для показу іконки при >= 2 літерах
      // Same guard for persistence: a no-op push still marks the session
      // dirty and clears the notifier's restorableSessionId, which broke RESTORE.
      if (wordChanged) _pushRow(index, word: wordController.text);
    });

    translationController.addListener(() {
      final translationChanged = translationController.text != _wordPairs[index].translation;
      if (translationChanged) _dismissRestoreSnackBar();
      _wordPairs[index].translation = translationController.text;
      _checkAndAddNewPair();

      // Якщо translation повністю видалений, скинути опції й "filled"-мітку
      final isEmptyNow = translationController.text.isEmpty;
      final shouldResetFilledMark = isEmptyNow && _translationMarkedFilled[index];

      setState(() {
        if (isEmptyNow) {
          _translationOptions[index] = null;
          _optionsWord[index] = null;
        }
        if (shouldResetFilledMark) {
          _translationMarkedFilled[index] = false;
        }
      }); // Оновити для показу/приховування lightning-іконок (docs/lightning_icon_rules.md)
      if (translationChanged) _pushRow(index, translation: translationController.text);
    });

    definitionController.addListener(() {
      final definitionChanged = definitionController.text != _wordPairs[index].definition;
      if (definitionChanged) _dismissRestoreSnackBar();
      _wordPairs[index].definition = definitionController.text;
      _checkAndAddNewPair();

      final isEmptyNow = definitionController.text.isEmpty;
      setState(() {
        if (isEmptyNow) _definitionMarkedFilled[index] = false;
      });
      if (definitionChanged) _pushRow(index, definition: definitionController.text);
    });

    _wordControllers.add(wordController);
    _translationControllers.add(translationController);
    _isLoadingTranslation.add(false);
    _isLoadingWordTranslation.add(false);
    _translationOptions.add(null);
    _optionsWord.add(null);
    _translationMarkedFilled.add(false);
    _wordMarkedFilled.add(false);
    _wordFocusNodes.add(wordFocusNode);
    _translationFocusNodes.add(translationFocusNode);
    _definitionControllers.add(definitionController);
    _definitionFocusNodes.add(definitionFocusNode);
    _isLoadingDefinition.add(false);
    _definitionMarkedFilled.add(false);
    _definitionSenses.add(null);
    _sensesWord.add(null);
  }

  /// The single funnel from the screen's parallel per-row lists into the
  /// notifier. Everything the store keeps for a row travels together, so a
  /// restored row looks exactly as it did before the kill: the text, the dots
  /// state, the cached dictionary behind the dots, and the two lightning
  /// "filled" marks (docs/lightning_icon_rules.md).
  void _pushRow(int index,
      {String? word, String? translation, String? definition, String? sourceId, bool clearSourceId = false}) {
    if (index < 0 || index >= _translationOptions.length) return;
    final senses = _effectiveSenses(index);
    // Persist only what the dots actually show: a block whose word no longer
    // matches is hidden, so it must not be written either. This keeps restore
    // able to re-key a persisted block to the restored word (see
    // _restoreFromStore and _effectiveOptions).
    final options = _effectiveOptions(index);
    ref.read(wordInputNotifierProvider.notifier).updateAt(
          _storeIndex(index),
          word: word,
          translation: translation,
          // Derived, never set by hand: the flag the store keeps now always
          // agrees with whether a block is actually stored.
          hasTranslationOptions: options?.hasDictionary ?? false,
          translationOptions: options,
          clearTranslationOptions: options == null,
          wordMarkedFilled: _wordMarkedFilled[index],
          translationMarkedFilled: _translationMarkedFilled[index],
          definition: definition,
          definitionOptionsJson: senses != null ? DefinitionResult.encodeSenses(senses) : null,
          clearDefinitionOptions: senses == null,
          definitionMarkedFilled: _definitionMarkedFilled[index],
          sourceId: sourceId,
          clearSourceId: clearSourceId,
        );
  }

  /// The session this screen writes into right now. A lookup reads it before
  /// its await and drops its result when a switch from History changed it in
  /// the meantime (edit-session-from-history, ADR-0003).
  String? get _sessionIdNow =>
      ref.read(wordInputNotifierProvider).valueOrNull?.sessionId;

  // --- Lightning icon show/hide rules; Translation dots button (see
  // docs/lightning_icon_rules.md) ---
  //
  // Word icon (offers translating Translation -> Word): shown iff the Word
  // field is fully empty AND Translation has 2+ letters. This threshold is
  // intentionally lower than Translation's own "filled" concept below --
  // it only needs enough text to make a reverse translation worth trying.
  //
  // Translation icon (offers translating Word -> Translation, existing
  // behaviour): shown iff Word has 2+ letters AND Translation is NOT yet
  // "filled" (more than 5 chars, or auto-populated). The loading spinner is
  // governed separately (unaffected by this rule).
  //
  // Translation dots button: sits *outside* the Translation field, always
  // visible -- no focus or length gating, and no loading state of its own. Its
  // appearance is derived from the cached dictionary itself (solid when
  // `_translationOptions[index]` holds a block, outlined when it does not), so
  // it cannot claim options that the popup would fail to show. Tapping it
  // always opens the "more options" popup; when there is no cached block the
  // popup offers an update icon that fetches one.

  /// "Translation filled" per docs/lightning_icon_rules.md: more than 5
  /// characters, OR auto-populated (AI translate, a picked popup option, or
  /// photo recognition) regardless of length. Gates only the Translation
  /// icon's own hide condition -- see _shouldShowWordIcon for the separate,
  /// lower "2+ letters" threshold that triggers the Word icon.
  bool _isTranslationFilled(int index) {
    return _translationControllers[index].text.length > 5 || _translationMarkedFilled[index];
  }

  /// "Item in focus" per docs/lightning_icon_rules.md: true while either
  /// the Word or the Translation field of this row currently has focus.
  bool _isItemFocused(int index) {
    return _wordFocusNodes[index].hasFocus ||
        _translationFocusNodes[index].hasFocus ||
        _definitionFocusNodes[index].hasFocus;
  }

  bool _shouldShowWordIcon(int index) {
    if (!_isItemFocused(index)) return false;
    final wordIsFullyEmpty = _wordControllers[index].text.isEmpty;
    final translationHasTwoLetters = _translationControllers[index].text.length >= 2;
    return wordIsFullyEmpty && translationHasTwoLetters;
  }

  bool _shouldShowTranslationIcon(int index) {
    if (!_isItemFocused(index)) return false;
    final wordHasTwoLetters = _wordControllers[index].text.length >= 2;
    return wordHasTwoLetters && !_isTranslationFilled(index);
  }

  /// Pronunciation buttons (docs/tasks/task-04-uk-us-pronunciation.md):
  /// shown once the row has a translation to go with the word, regardless
  /// of focus -- unlike the lightning icons, this isn't a "compose" action
  /// gated to the row you're actively editing.
  bool _shouldShowPronunciation(int index) {
    // definition-mode: a definition is a detail to go with the word too, so a
    // definition-only row (definition mode) still gets its flags.
    return _translationControllers[index].text.trim().isNotEmpty ||
        _definitionControllers[index].text.trim().isNotEmpty;
  }

  /// Whether this row's Word field has enough text for a dictionary lookup.
  /// The same "2+ letters" bar the Translation icon uses: below it there is
  /// nothing worth asking Google about, and the query would be empty.
  bool _canLoadTranslationOptions(int index) {
    return _wordControllers[index].text.trim().length >= 2;
  }

  /// Loads the dictionary block for this row's current Word field and hands it
  /// to the dots popup. This is the dots popup's own "update icon" action --
  /// the path that makes the block reachable after the cached one was dropped
  /// (a Word-field edit, or the smart-swap path), which used to be a dead-end
  /// "tap the lightning icon" message.
  ///
  /// It deliberately runs the *same* [GoogleTranslateService.translateWord]
  /// call the Translation lightning makes, so the popup shows exactly the
  /// several alternatives that action produces, in the same order -- one
  /// source of truth for "what else could this word be".
  ///
  /// Unlike that action it writes nothing: the Translation field and both
  /// "filled" marks are left alone, because the user asked for extra options,
  /// not for their translation to be replaced. Picking a chip is what changes
  /// the field, via [_selectTranslationOption].
  ///
  /// Returns the block so the popup can render it immediately, or null when
  /// the request failed or Google had no dictionary for the word.
  /// The cached dictionary block for this row, but only while it still
  /// describes the current Word. Editing the Word hides the block; reverting
  /// the edit shows the same block again -- the cache is never dropped on a
  /// keystroke. An empty Word shows nothing. The dots' solid/outlined state and
  /// the popup body are both derived from this, so they can never disagree
  /// (docs/lightning_icon_rules.md).
  TranslationResult? _effectiveOptions(int index) {
    if (index < 0 || index >= _translationOptions.length) return null;
    final opts = _translationOptions[index];
    if (opts == null) return null;
    final current = _wordControllers[index].text.trim();
    if (current.isEmpty) return null;
    return _optionsWord[index] == current ? opts : null;
  }

  /// The row's cached dictionary senses, only while they still describe the
  /// current Word -- the definition counterpart of [_effectiveOptions].
  List<String>? _effectiveSenses(int index) {
    if (index < 0 || index >= _definitionSenses.length) return null;
    final senses = _definitionSenses[index];
    if (senses == null) return null;
    final current = _wordControllers[index].text.trim();
    if (current.isEmpty) return null;
    return _sensesWord[index] == current ? senses : null;
  }

  Future<TranslationResult?> _loadTranslationOptions(int index) async {
    if (index < 0 || index >= _wordControllers.length) return null;
    if (!_canLoadTranslationOptions(index)) return null;

    final word = _wordControllers[index].text.trim();

    setState(() {
      // Reuses the Translation icon's own in-flight flag: it is the same kind
      // of request on the same row, and its spinner slot is the one already
      // wired for it. A second per-row list would need mirroring in remove,
      // reorder, restore and the hot-reload pad for no visible difference.
      _isLoadingTranslation[index] = true;
    });

    final sessionId = _sessionIdNow;
    try {
      final translation = await ref.read(googleTranslateServiceProvider).translateWord(word, from: 'en', to: 'uk');
      if (_sessionIdNow != sessionId) return null;

      if (mounted) {
        setState(() {
          _isLoadingTranslation[index] = false;
          // The block is the state the dots' solid/outlined appearance is
          // derived from, so storing it is also what makes the dots fill in.
          _translationOptions[index] = translation.result;
          // Key it to the word it was fetched for, so it survives edits and
          // reappears on revert (see _effectiveOptions).
          _optionsWord[index] = word;
        });
      }
      _pushRow(index);

      return translation.result;
    } catch (e) {
      if (_sessionIdNow != sessionId) return null;
      if (mounted) {
        setState(() {
          _isLoadingTranslation[index] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
      return null;
    }
  }

  /// Speaks the row's Word field in [accent]. A second tap (same row or a
  /// different one) interrupts whatever is currently playing --
  /// [PronunciationService.speak] always stops before it starts.
  Future<void> _speak(int index, Accent accent) async {
    final word = _wordControllers[index].text.trim();
    if (word.isEmpty) return;
    try {
      await ref.read(pronunciationServiceProvider).speak(word, accent: accent);
    } on PronunciationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Translate Translation -> Word. The Translation field can be in any
  /// language Google Translate supports (auto-detected -- from: 'auto'),
  /// translated to English for the Word field. Only the plain translation is
  /// used here: a dictionary block for the *Translation* field's language
  /// would describe the wrong side of the row. See
  /// docs/lightning_icon_rules.md for the button's visibility rules.
  Future<void> _fillWordWithAI(int index) async {
    final translationText = _translationControllers[index].text.trim();
    if (translationText.isEmpty) return;
    final sessionId = _sessionIdNow;

    setState(() {
      _isLoadingWordTranslation[index] = true;
    });

    // Почекати поки UI завершить рендер поточного frame
    await SchedulerBinding.instance.endOfFrame;

    try {
      // Google Translate: auto-detect source language -> English.
      final translation = await ref.read(googleTranslateServiceProvider).translate(
            translationText,
            from: 'auto',
            to: 'en',
          );
      if (_sessionIdNow != sessionId) return;

      _wordControllers[index].text = translation.text;

      final gotRealTranslation = isRealTranslation(translationText, translation.text);

      setState(() {
        _isLoadingWordTranslation[index] = false;
        // The Word field just changed, so whatever dictionary the dots
        // popup held described a different word.
        _translationOptions[index] = null;
        _optionsWord[index] = null;
        if (gotRealTranslation) {
          // Got an actual translation (not just an echo of the input) ->
          // both fields count as "filled" per docs/lightning_icon_rules.md.
          _wordMarkedFilled[index] = true;
          _translationMarkedFilled[index] = true;
        }
      });
      _pushRow(index, word: _wordControllers[index].text);
    } catch (e) {
      if (_sessionIdNow != sessionId) return;
      setState(() {
        _isLoadingWordTranslation[index] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
    }
  }

  /// Translate Word -> Translation (the Translation icon's action). If
  /// the Word field's first letter is an English letter, behaves exactly
  /// as before: English -> Ukrainian -- but through
  /// [GoogleTranslateService.translateWord], which asks Google for the
  /// dictionary block in the same request and picks the best single
  /// translation out of that set by part of speech (noun first, then verb,
  /// adjective, adverb) instead of taking Google's one-line answer. The
  /// same set is kept for the dots popup, so it costs no extra request.
  ///
  /// Otherwise the Word field probably holds what should have been the
  /// Translation (typed into the wrong
  /// field), so instead this auto-detects its language, translates to
  /// English, and -- only on a real translation -- swaps the two fields:
  /// the text the user typed moves to Translation, the English result
  /// moves to Word. See docs/lightning_icon_rules.md.
  Future<void> _fillWithAI(int index) async {
    final word = _wordControllers[index].text.trim();
    if (word.isEmpty) return;

    final wordStartsWithEnglishLetter = isEnglishLetter(word[0]);
    final sessionId = _sessionIdNow;

    setState(() {
      _isLoadingTranslation[index] = true;
    });

    // Почекати поки UI завершить рендер поточного frame
    await SchedulerBinding.instance.endOfFrame;

    try {
      final translateService = ref.read(googleTranslateServiceProvider);

      if (wordStartsWithEnglishLetter) {
        // Google Translate: English -> Ukrainian, with the part-of-speech
        // rule picking the best of the returned set.
        final translation = await translateService.translateWord(word, from: 'en', to: 'uk');
        if (_sessionIdNow != sessionId) return;

        _translationControllers[index].text = translation.best;

        final gotRealTranslation = isRealTranslation(word, translation.best);

        setState(() {
          _isLoadingTranslation[index] = false;
          // The whole set the request brought back, for the dots popup. This
          // is also what makes the dots solid -- they read the block itself.
          _translationOptions[index] = translation.result;
          _optionsWord[index] = word;
          if (gotRealTranslation) {
            // Got an actual translation (not just an echo of the input) ->
            // both fields count as "filled" per docs/lightning_icon_rules.md.
            _translationMarkedFilled[index] = true;
            _wordMarkedFilled[index] = true;
          }
        });
        _pushRow(index, translation: _translationControllers[index].text);
      } else {
        // Word doesn't start with an English letter -> auto-detect its
        // language and translate to English instead.
        final translation = await translateService.translate(word, from: 'auto', to: 'en');
        if (_sessionIdNow != sessionId) return;
        final gotRealTranslation = isRealTranslation(word, translation.text);

        if (gotRealTranslation) {
          // Swap: what the user typed becomes the Translation, the
          // English result becomes the Word.
          _translationControllers[index].text = word;
          _wordControllers[index].text = translation.text;

          setState(() {
            _isLoadingTranslation[index] = false;
            // The Word field now holds the English result, so there is no
            // dictionary for it yet. The dots go outlined with it, and the
            // popup offers the update icon -- which is how the alternatives
            // the old comment promised here are still reachable, just on a
            // deliberate tap instead of a stale block.
            _translationOptions[index] = null;
            _optionsWord[index] = null;
            _wordMarkedFilled[index] = true;
            _translationMarkedFilled[index] = true;
          });
          _pushRow(
            index,
            word: _wordControllers[index].text,
            translation: _translationControllers[index].text,
          );
        } else {
          // No distinct translation found -- leave both fields untouched.
          setState(() {
            _isLoadingTranslation[index] = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No translation found')),
            );
          }
        }
      }
    } catch (e) {
      // Помилка перекладу - показати повідомлення
      if (_sessionIdNow != sessionId) return;
      setState(() {
        _isLoadingTranslation[index] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
    }
  }

  /// The Definition lightning (spec AC-05..AC-07, sad §6 flow 1): asks the
  /// dictionary for the row's Word and fills the first sense, keeping every
  /// sense for the senses list. A miss never touches the field: an unknown
  /// word shows the dictionary's suggestions, an outage says so.
  Future<void> _fillDefinition(int index) async {
    if (index < 0 || index >= _wordControllers.length) return;
    final word = _wordControllers[index].text.trim();
    if (word.length < 2) return;

    final sessionId = _sessionIdNow;
    setState(() => _isLoadingDefinition[index] = true);
    final result = await ref.read(dictionaryServiceProvider).define(word);
    if (!mounted || index >= _wordControllers.length) return;
    if (_sessionIdNow != sessionId) return;
    setState(() => _isLoadingDefinition[index] = false);

    switch (result.kind) {
      case DefinitionKind.senses:
        setState(() {
          _definitionSenses[index] = result.senses;
          _sensesWord[index] = word;
          _definitionMarkedFilled[index] = true;
        });
        // The controller listener persists the text; this push carries the
        // senses and the mark along with it.
        _definitionControllers[index].text = result.firstSense!;
        _pushRow(index, definition: result.firstSense!);
      case DefinitionKind.notFound:
        final hint = result.suggestions.isEmpty ? '' : ' — did you mean: ${result.suggestions.join(', ')}';
        // A newer lookup's message replaces the previous one instead of
        // queueing behind it.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('No definition found for "$word"$hint')));
      case DefinitionKind.unavailable:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Definitions are temporarily unavailable')));
    }
  }

  /// The definition dots popup's load action (spec AC-08): looks the Word up
  /// and stores the senses for the row without touching the Definition text.
  /// Returns the senses, an empty list when the dictionary has none, or null
  /// when it could not be reached -- the popup explains each.
  Future<List<String>?> _loadDefinitionSenses(int index) async {
    if (index < 0 || index >= _wordControllers.length) return null;
    final word = _wordControllers[index].text.trim();
    if (word.length < 2) return null;
    final sessionId = _sessionIdNow;
    final result = await ref.read(dictionaryServiceProvider).define(word);
    if (!mounted || index >= _wordControllers.length) return null;
    if (_sessionIdNow != sessionId) return null;
    switch (result.kind) {
      case DefinitionKind.senses:
        setState(() {
          _definitionSenses[index] = result.senses;
          _sensesWord[index] = word;
        });
        _pushRow(index);
        return result.senses;
      case DefinitionKind.notFound:
        return const [];
      case DefinitionKind.unavailable:
        return null;
    }
  }

  /// A sense picked in the popup replaces the Definition text and counts as
  /// auto-populated, like a picked translation chip.
  void _selectDefinitionSense(int index, String sense) {
    if (index < 0 || index >= _definitionControllers.length) return;
    setState(() => _definitionMarkedFilled[index] = true);
    _definitionControllers[index].text = sense;
    _pushRow(index, definition: sense);
  }

  void _closeDefinitionOptions(int index) {
    setState(() {
      _definitionPopupControllers[index]?.hideMenu();
    });
  }

  void _selectTranslationOption(int index, String selectedTranslation) {
    _translationControllers[index].text = selectedTranslation;
    // Auto-populated -> counts as "filled" regardless of length.
    setState(() {
      _translationMarkedFilled[index] = selectedTranslation.isNotEmpty;
    });
    _pushRow(index, translation: selectedTranslation);
    // Popup закривається автоматично
  }

  void _removeItem(int index) {
    ref.read(pronunciationServiceProvider).stop();
    setState(() {
      if (index == 0 && _keepsFirstRow) {
        // Для першого айтема тільки очищуємо поля
        _wordControllers[0].clear();
        _translationControllers[0].clear();
        _definitionControllers[0].clear();
        _isLoadingDefinition[0] = false;
        _definitionMarkedFilled[0] = false;
        _definitionSenses[0] = null;
        _sensesWord[0] = null;
        _wordPairs[0] = WordPair(word: '', translation: '');
        _isLoadingTranslation[0] = false;
        _isLoadingWordTranslation[0] = false;
        _translationOptions[0] = null;
        _optionsWord[0] = null;
        _translationMarkedFilled[0] = false;
        _wordMarkedFilled[0] = false;
        _pushRow(0, word: '', translation: '', definition: '', clearSourceId: true);
      } else {
        // Для інших айтемів видаляємо повністю
        // Dispose контролерів перед видаленням
        _wordControllers[index].dispose();
        _translationControllers[index].dispose();

        // Видаляємо з усіх списків
        _wordPairs.removeAt(index);
        _wordControllers.removeAt(index);
        _translationControllers.removeAt(index);
        _isLoadingTranslation.removeAt(index);
        _isLoadingWordTranslation.removeAt(index);
        _translationOptions.removeAt(index);
        _optionsWord.removeAt(index);
        _translationMarkedFilled.removeAt(index);
        _wordMarkedFilled.removeAt(index);
        _wordFocusNodes[index].dispose();
        _wordFocusNodes.removeAt(index);
        _translationFocusNodes[index].dispose();
        _translationFocusNodes.removeAt(index);
        _definitionControllers[index].dispose();
        _definitionControllers.removeAt(index);
        _definitionFocusNodes[index].dispose();
        _definitionFocusNodes.removeAt(index);
        _isLoadingDefinition.removeAt(index);
        _definitionMarkedFilled.removeAt(index);
        _definitionSenses.removeAt(index);
        _sensesWord.removeAt(index);

        // Видаляємо з popup controllers якщо є
        _popupControllers.remove(index);
        _definitionPopupControllers.remove(index);
        final storeIndex = _storeIndex(index);
        ref.read(wordInputNotifierProvider.notifier).removeAt(storeIndex);
        _onRowRemoved(index, storeIndex);
      }
    });
  }

  /// Drops the keyboard as the dots popup opens, so its body gets the full
  /// height between the app bar and the bottom of the screen instead of being
  /// squeezed into the strip above the keyboard (where the close button ends up
  /// unreachable). Same unfocus [_navigateToTableScreen] makes for the same
  /// reason. Only the dots use this -- the lightning icons keep their focus,
  /// since their visibility is gated on the row staying focused (Rule 0,
  /// docs/lightning_icon_rules.md). Unfocusing here therefore hides that row's
  /// two lightning icons while the popup is open; they return when the row is
  /// focused again.
  void _onOpenTranslationOptions() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Closes the dots popup from its own close icon.
  ///
  /// The popup package would normally dismiss the menu when a tap lands outside
  /// the panel it measured, but that measurement is a single rectangle it only
  /// refreshes during layout (`shouldRelayout => false`), so the close button
  /// must not depend on it. Hiding the menu here is the screen's own call, made
  /// at the same predictable point the open path uses.
  void _closeTranslationOptions(int index) {
    setState(() {
      _popupControllers[index]?.hideMenu();
    });
  }

  /// The row with every field, icon and button, as on the main screen.
  Widget _wordRowItem(int index,
      {required bool isDragMode,
      required WordDetailMode detailMode,
      Decoration? highlight}) {
    return WordRowItem(
      highlight: highlight,
      index: index,
      detailMode: detailMode,
      definitionController: _definitionControllers[index],
      definitionFocusNode: _definitionFocusNodes[index],
      isLoadingDefinition: _isLoadingDefinition[index],
      shouldShowDefinitionIcon: shouldShowDefinitionIcon(
        rowFocused: _isItemFocused(index),
        word: _wordControllers[index].text,
        definition: _definitionControllers[index].text,
        marked: _definitionMarkedFilled[index],
      ),
      onFillDefinition: () => _fillDefinition(index),
      definitionSenses: _effectiveSenses(index),
      canLoadDefinitionSenses: _wordControllers[index].text.trim().length >= 2,
      definitionPopupController: _definitionPopupControllers.putIfAbsent(index, () => MyCustomPopupMenuController()),
      onLoadDefinitionSenses: () => _loadDefinitionSenses(index),
      onSelectDefinition: (sense) => _selectDefinitionSense(index, sense),
      onCloseDefinitionOptions: () => _closeDefinitionOptions(index),
      isDragMode: isDragMode,
      wordController: _wordControllers[index],
      translationController: _translationControllers[index],
      wordFocusNode: _wordFocusNodes[index],
      translationFocusNode: _translationFocusNodes[index],
      isLoadingWordTranslation: _isLoadingWordTranslation[index],
      isLoadingTranslation: _isLoadingTranslation[index],
      shouldShowWordIcon: _shouldShowWordIcon(index),
      shouldShowTranslationIcon: _shouldShowTranslationIcon(index),
      shouldShowPronunciation: _shouldShowPronunciation(index),
      translationOptions: _effectiveOptions(index),
      canLoadTranslationOptions: _canLoadTranslationOptions(index),
      onLoadTranslations: () => _loadTranslationOptions(index),
      popupController: _popupControllers.putIfAbsent(index, () => MyCustomPopupMenuController()),
      onRemove: () => _removeItem(index),
      onFillWordWithAI: () => _fillWordWithAI(index),
      onFillWithAI: () => _fillWithAI(index),
      onSelectTranslation: (translation) => _selectTranslationOption(index, translation),
      onOpenTranslationOptions: _onOpenTranslationOptions,
      onCloseTranslationOptions: () => _closeTranslationOptions(index),
      onSpeak: (accent) => _speak(index, accent),
    );
  }
}
