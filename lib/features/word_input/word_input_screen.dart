import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/translation_result.dart';
import '../../core/models/vocab_word.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/photo_scaler.dart';
import '../../core/services/vocab_photo_service.dart';
import '../../router/routes.dart';
import 'lightning_rules.dart';
import 'widgets/word_input_speed_dial.dart';
import 'widgets/word_row_item.dart';
import 'widgets/vocab_result_dialog.dart';
import 'word_input_notifier.dart';

class WordInputScreen extends ConsumerStatefulWidget {
  const WordInputScreen({super.key});

  @override
  ConsumerState<WordInputScreen> createState() => _WordInputScreenState();
}

class _WordInputScreenState extends ConsumerState<WordInputScreen> with WidgetsBindingObserver {
  final List<WordPair> _wordPairs = [
    WordPair(word: '', translation: ''),
  ];

  final List<TextEditingController> _wordControllers = [];
  final List<TextEditingController> _translationControllers = [];
  final List<bool> _isLoadingTranslation = [];
  // Loading state for the Word icon's own translate action (Translation ->
  // Word), tracked separately from _isLoadingTranslation so the two
  // corners' spinners never interfere with each other.
  final List<bool> _isLoadingWordTranslation = [];
  final List<bool> _hasTranslationOptions = [];
  // Google's dictionary block per row -- the set of translations grouped by
  // part of speech that the last translate brought back, reused by the dots
  // popup so opening it costs no second request. Dropped whenever the Word
  // field changes, so the popup never shows another word's translations.
  final List<TranslationResult?> _translationOptions = [];
  // "Translation filled" per docs/lightning_icon_rules.md: true once the
  // Translation field was auto-populated (AI translate, picking a popup
  // option, or photo recognition) -- independent of the >5-character rule.
  final List<bool> _translationMarkedFilled = [];
  // "Word filled" counterpart -- true once the Word field was
  // auto-populated (photo recognition, or a real translate-to-Word result
  // via the Word icon). See docs/lightning_icon_rules.md.
  final List<bool> _wordMarkedFilled = [];
  // Per-row focus tracking for the "item in focus" rule (see
  // docs/lightning_icon_rules.md): a lightning icon only ever shows while
  // its own row (word or translation field) currently has focus.
  final List<FocusNode> _wordFocusNodes = [];
  final List<FocusNode> _translationFocusNodes = [];
  final Map<int, CustomPopupMenuController> _popupControllers = {};
  bool _isDragMode = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isAnalyzingPhoto = false;
  bool _isRecoveringLostPhoto = false;
  bool _restoredFromStore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addControllersForIndex(0);
    // Request focus on the first field after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wordFocusNodes[0].requestFocus();
    });
    _pollForLostPhoto();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Android can kill our process while the system camera app is in the
    // foreground (verified in logcat: the app comes back with a new PID), and
    // the pending pickImage() future dies with it — the photo is taken, but
    // nothing happens when we return. Android delivers onActivityResult
    // before onResume, so resuming is the race-free point to claim it.
    if (state == AppLifecycleState.resumed) {
      _pollForLostPhoto();
    }
    // The OS can kill the process while the camera is open; `paused` is the
    // last guaranteed callback before that happens, so flush immediately
    // instead of waiting on the debounce timer.
    if (state == AppLifecycleState.paused) {
      ref.read(wordInputNotifierProvider.notifier).flush();
    }
  }

  /// Android can restart our process just to serve [ImagePickerFileProvider]
  /// while the camera is still writing the photo, so the result may only reach
  /// the plugin a moment after we start up — and on a cold start we never get a
  /// `resumed` callback to retry on. Polling briefly covers both orderings.
  Future<void> _pollForLostPhoto() async {
    if (!Platform.isAndroid) return;
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(milliseconds: 600),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      if (!mounted) return;
      if (_isAnalyzingPhoto) return;
      if (await _recoverLostPhoto()) return;
    }
  }

  /// Returns true once a lost photo has been claimed (or definitively failed),
  /// so the caller can stop polling.
  Future<bool> _recoverLostPhoto() async {
    // retrieveLostData is an Android-only concern.
    if (!Platform.isAndroid) return true;
    if (_isRecoveringLostPhoto || _isAnalyzingPhoto) return true;
    _isRecoveringLostPhoto = true;
    try {
      final LostDataResponse response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) return false;
      if (response.exception != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lost the photo: ${response.exception}')),
          );
        }
        return true;
      }
      final XFile? file = response.file;
      if (file == null) return false;
      await _processPickedPhoto(file);
      return true;
    } catch (e, stack) {
      debugPrint('VOCAB: recovery failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovering the photo failed: $e')),
        );
      }
      return true;
    } finally {
      _isRecoveringLostPhoto = false;
    }
  }

  void _addControllersForIndex(int index) {
    final wordController = TextEditingController(text: _wordPairs[index].word);
    final translationController = TextEditingController(text: _wordPairs[index].translation);
    final wordFocusNode = FocusNode();
    final translationFocusNode = FocusNode();

    // Rebuild on focus change so the lightning icons can appear/disappear
    // per the "item in focus" rule (docs/lightning_icon_rules.md).
    wordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    translationFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    wordController.addListener(() {
      _wordPairs[index].word = wordController.text;
      ref.read(wordInputNotifierProvider.notifier).updateAt(index, word: wordController.text);
      _checkAndAddNewPair();

      // Якщо word повністю видалений, скинути "filled"-мітку
      final wordIsEmptyNow = wordController.text.isEmpty;
      final shouldResetWordFilledMark =
          wordIsEmptyNow && _wordMarkedFilled[index];

      setState(() {
        if (shouldResetWordFilledMark) {
          _wordMarkedFilled[index] = false;
        }
        // The cached dictionary described the previous word, so it must not
        // stay behind the dots button. The dots themselves keep their state
        // (docs/lightning_icon_rules.md) -- the popup just falls back to its
        // "tap the lightning icon" message.
        _translationOptions[index] = null;
      }); // Оновити для показу іконки при >= 2 літерах
    });

    translationController.addListener(() {
      _wordPairs[index].translation = translationController.text;
      ref.read(wordInputNotifierProvider.notifier).updateAt(index, translation: translationController.text);
      _checkAndAddNewPair();

      // Якщо translation повністю видалений, скинути опції й "filled"-мітку
      final isEmptyNow = translationController.text.isEmpty;
      final shouldResetOptions = isEmptyNow && _hasTranslationOptions[index];
      final shouldResetFilledMark =
          isEmptyNow && _translationMarkedFilled[index];

      setState(() {
        if (shouldResetOptions) {
          _hasTranslationOptions[index] = false;
          _translationOptions[index] = null;
        }
        if (shouldResetFilledMark) {
          _translationMarkedFilled[index] = false;
        }
      }); // Оновити для показу/приховування lightning-іконок (docs/lightning_icon_rules.md)
    });

    _wordControllers.add(wordController);
    _translationControllers.add(translationController);
    _isLoadingTranslation.add(false);
    _isLoadingWordTranslation.add(false);
    _hasTranslationOptions.add(false);
    _translationOptions.add(null);
    _translationMarkedFilled.add(false);
    _wordMarkedFilled.add(false);
    _wordFocusNodes.add(wordFocusNode);
    _translationFocusNodes.add(translationFocusNode);
  }

  /// Replaces the placeholder row from initState() with the persisted list,
  /// the first time it resolves (see the `ref.listen` in build()). Rebuilds
  /// every parallel per-row list from scratch, exactly like initState() does
  /// for a single row, then re-runs the same "always one trailing blank row"
  /// and initial-focus logic a fresh launch would.
  void _restoreFromStore(List<WordPair> pairs) {
    for (final c in _wordControllers) {
      c.dispose();
    }
    for (final c in _translationControllers) {
      c.dispose();
    }
    for (final n in _wordFocusNodes) {
      n.dispose();
    }
    for (final n in _translationFocusNodes) {
      n.dispose();
    }

    setState(() {
      _wordPairs
        ..clear()
        ..addAll(pairs.map((p) => WordPair(word: p.word, translation: p.translation)));
      _wordControllers.clear();
      _translationControllers.clear();
      _isLoadingTranslation.clear();
      _isLoadingWordTranslation.clear();
      _hasTranslationOptions.clear();
      _translationOptions.clear();
      _translationMarkedFilled.clear();
      _wordMarkedFilled.clear();
      _wordFocusNodes.clear();
      _translationFocusNodes.clear();
      _popupControllers.clear();

      for (var i = 0; i < _wordPairs.length; i++) {
        _addControllersForIndex(i);
      }
      _checkAndAddNewPair();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wordFocusNodes.isNotEmpty) {
        _wordFocusNodes.last.requestFocus();
      }
    });
  }

  /// Hot-reload-only safety net. Hot reload keeps this State object alive
  /// and just patches in new code, but it does NOT re-run initState() on
  /// that live instance -- so a per-row list field added in a later edit
  /// (like _wordFocusNodes) resets to its empty initializer while older
  /// fields (like _wordControllers) keep the values they already had,
  /// leaving the lists out of sync and causing a RangeError when the UI
  /// indexes into the short one. A full app restart never hits this
  /// (initState() runs normally and populates everything in lockstep), so
  /// this is skipped entirely in release builds, where hot reload doesn't
  /// happen.
  void _ensureRowStateSynced() {
    if (kReleaseMode) return;

    final target = _wordControllers.length;
    while (_wordFocusNodes.length < target) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _wordFocusNodes.add(node);
    }
    while (_translationFocusNodes.length < target) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _translationFocusNodes.add(node);
    }
    while (_translationMarkedFilled.length < target) {
      _translationMarkedFilled.add(false);
    }
    while (_translationOptions.length < target) {
      _translationOptions.add(null);
    }
    while (_isLoadingWordTranslation.length < target) {
      _isLoadingWordTranslation.add(false);
    }
    while (_wordMarkedFilled.length < target) {
      _wordMarkedFilled.add(false);
    }
  }

  void _checkAndAddNewPair() {
    if (_wordPairs.isEmpty) return;

    final lastPair = _wordPairs.last;
    if (lastPair.word.trim().isNotEmpty || lastPair.translation.trim().isNotEmpty) {
      final newPair = WordPair(word: '', translation: '');
      setState(() {
        _wordPairs.add(newPair);
        _addControllersForIndex(_wordPairs.length - 1);
      });
      ref.read(wordInputNotifierProvider.notifier).addAll([newPair]);
    }
  }

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
  // visible -- no focus or length gating, and no loading state of its own.
  // Empty (outlined) dots by default; full (solid) dots once a translate
  // has produced options for this row (`_hasTranslationOptions`) -- opens
  // the "more options" popup. See _buildTranslationDotsButton.

  /// "Translation filled" per docs/lightning_icon_rules.md: more than 5
  /// characters, OR auto-populated (AI translate, a picked popup option, or
  /// photo recognition) regardless of length. Gates only the Translation
  /// icon's own hide condition -- see _shouldShowWordIcon for the separate,
  /// lower "2+ letters" threshold that triggers the Word icon.
  bool _isTranslationFilled(int index) {
    return _translationControllers[index].text.length > 5 ||
        _translationMarkedFilled[index];
  }

  /// "Item in focus" per docs/lightning_icon_rules.md: true while either
  /// the Word or the Translation field of this row currently has focus.
  bool _isItemFocused(int index) {
    return _wordFocusNodes[index].hasFocus ||
        _translationFocusNodes[index].hasFocus;
  }

  bool _shouldShowWordIcon(int index) {
    if (!_isItemFocused(index)) return false;
    final wordIsFullyEmpty = _wordControllers[index].text.isEmpty;
    final translationHasTwoLetters =
        _translationControllers[index].text.length >= 2;
    return wordIsFullyEmpty && translationHasTwoLetters;
  }

  bool _shouldShowTranslationIcon(int index) {
    if (!_isItemFocused(index)) return false;
    final wordHasTwoLetters = _wordControllers[index].text.length >= 2;
    return wordHasTwoLetters && !_isTranslationFilled(index);
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

    setState(() {
      _isLoadingWordTranslation[index] = true;
    });

    // Почекати поки UI завершить рендер поточного frame
    await SchedulerBinding.instance.endOfFrame;

    try {
      // Google Translate: auto-detect source language -> English.
      final translation =
          await ref.read(googleTranslateServiceProvider).translate(
                translationText,
                from: 'auto',
                to: 'en',
              );

      _wordControllers[index].text = translation.text;

      final gotRealTranslation =
          isRealTranslation(translationText, translation.text);

      setState(() {
        _isLoadingWordTranslation[index] = false;
        // The Word field just changed, so whatever dictionary the dots
        // popup held described a different word.
        _translationOptions[index] = null;
        if (gotRealTranslation) {
          // Got an actual translation (not just an echo of the input) ->
          // both fields count as "filled" per docs/lightning_icon_rules.md.
          _wordMarkedFilled[index] = true;
          _translationMarkedFilled[index] = true;
        }
      });
    } catch (e) {
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
        final translation =
            await translateService.translateWord(word, from: 'en', to: 'uk');

        _translationControllers[index].text = translation.best;

        final gotRealTranslation = isRealTranslation(word, translation.best);

        setState(() {
          _isLoadingTranslation[index] = false;
          _hasTranslationOptions[index] = true;
          // The whole set the request brought back, for the dots popup.
          _translationOptions[index] = translation.result;
          if (gotRealTranslation) {
            // Got an actual translation (not just an echo of the input) ->
            // both fields count as "filled" per docs/lightning_icon_rules.md.
            _translationMarkedFilled[index] = true;
            _wordMarkedFilled[index] = true;
          }
        });
      } else {
        // Word doesn't start with an English letter -> auto-detect its
        // language and translate to English instead.
        final translation =
            await translateService.translate(word, from: 'auto', to: 'en');
        final gotRealTranslation = isRealTranslation(word, translation.text);

        if (gotRealTranslation) {
          // Swap: what the user typed becomes the Translation, the
          // English result becomes the Word.
          _translationControllers[index].text = word;
          _wordControllers[index].text = translation.text;

          setState(() {
            _isLoadingTranslation[index] = false;
            // A real translation came back here too -> offer the same
            // "more options" popup as the plain English->Ukrainian path
            // (e.g. translation-in-context alternatives), not just a
            // literal swap.
            _hasTranslationOptions[index] = true;
            // The Word field now holds the English result, so the popup has
            // no dictionary for it until the lightning is tapped again.
            _translationOptions[index] = null;
            _wordMarkedFilled[index] = true;
            _translationMarkedFilled[index] = true;
          });
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

  void _selectTranslationOption(int index, String selectedTranslation) {
    _translationControllers[index].text = selectedTranslation;
    // Auto-populated -> counts as "filled" regardless of length.
    setState(() {
      _translationMarkedFilled[index] = selectedTranslation.isNotEmpty;
    });
    // Popup закривається автоматично
  }

  void _navigateToTableScreen() {
    const WordsTableRoute().go(context);
  }

  Future<void> _takeScreenshot() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to capture screenshot')),
          );
        }
        return;
      }

      // Save to temporary file and share
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final filePath = '${directory.path}/vocabulary_screenshot_$dateStr.png';

      final file = File(filePath);
      await file.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Vocabulary Screenshot',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking screenshot: $e')),
        );
      }
    }
  }

  Future<void> _takePhotoForVocabulary() async {
    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      // On some Android devices (notably MIUI/Xiaomi, which logs
      // "checkCallerLegality: Unknown caller" for third-party camera
      // callers) the camera intent can fail instead of just returning null.
      // Without this catch, that exception was silently swallowed — the
      // screen would flash black and land back on the app with no feedback.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the camera: $e')),
        );
      }
      return;
    }
    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photo was taken')),
        );
      }
      return;
    }
    await _processPickedPhoto(picked);
  }

  Future<void> _processPickedPhoto(XFile picked) async {
    setState(() {
      _isAnalyzingPhoto = true;
    });

    try {
      final compressStopwatch = Stopwatch()..start();
      final bytes = await PhotoScaler.instance.resizeFileToMinSide(
        picked.path,
        minSide: 640,
        quality: 85,
      );
      compressStopwatch.stop();

      final requestStopwatch = Stopwatch()..start();
      final result = await ref.read(vocabPhotoServiceProvider).analyzePhoto(
        bytes,
        mediaType: 'image/jpeg',
        translation: true,
        withDesc: true,
        shortifyDefinition: true,
        limit: 20,
      );
      requestStopwatch.stop();

      if (mounted) {
        showVocabResultDialog(
          context,
          result.words,
          compressDuration: compressStopwatch.elapsed,
          requestDuration: requestStopwatch.elapsed,
          aiDuration: result.aiDuration,
        ).then((selected) {
          if (selected != null && selected.isNotEmpty) {
            _addWordsFromPhoto(selected);
          }
        });
      }
    } on VocabPhotoException catch (e) {
      debugPrint('VOCAB: analyze failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      debugPrint('VOCAB: processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingPhoto = false;
        });
      }
    }
  }

  /// Appends words kept in the photo-results dialog to the main word list,
  /// reusing the still-empty first row if the screen hasn't been touched yet.
  void _addWordsFromPhoto(List<VocabWord> words) {
    var reusedFirstRow = false;
    final appendedPairs = <WordPair>[];

    setState(() {
      for (final w in words) {
        final translation = w.translation ?? w.description ?? '';
        if (_wordPairs.length == 1 && _wordPairs[0].isEmpty) {
          _wordPairs[0] = WordPair(word: w.word, translation: translation);
          _wordControllers[0].text = w.word;
          _translationControllers[0].text = translation;
          // Photo recognition auto-populated this row -> "filled".
          _translationMarkedFilled[0] = translation.isNotEmpty;
          _wordMarkedFilled[0] = w.word.isNotEmpty;
          reusedFirstRow = true;
        } else {
          _wordPairs.add(WordPair(word: w.word, translation: translation));
          _addControllersForIndex(_wordPairs.length - 1);
          _translationMarkedFilled[_wordPairs.length - 1] =
              translation.isNotEmpty;
          _wordMarkedFilled[_wordPairs.length - 1] = w.word.isNotEmpty;
          appendedPairs.add(_wordPairs[_wordPairs.length - 1]);
        }
      }
      _checkAndAddNewPair();
    });

    if (reusedFirstRow) {
      ref.read(wordInputNotifierProvider.notifier).updateAt(
            0,
            word: _wordPairs[0].word,
            translation: _wordPairs[0].translation,
          );
    }
    if (appendedPairs.isNotEmpty) {
      ref.read(wordInputNotifierProvider.notifier).addAll(appendedPairs);
    }
  }

  void _removeItem(int index) {
    setState(() {
      if (index == 0) {
        // Для першого айтема тільки очищуємо поля
        _wordControllers[0].clear();
        _translationControllers[0].clear();
        _wordPairs[0] = WordPair(word: '', translation: '');
        _isLoadingTranslation[0] = false;
        _isLoadingWordTranslation[0] = false;
        _hasTranslationOptions[0] = false;
        _translationOptions[0] = null;
        _translationMarkedFilled[0] = false;
        _wordMarkedFilled[0] = false;
        ref.read(wordInputNotifierProvider.notifier).updateAt(0, word: '', translation: '');
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
        _hasTranslationOptions.removeAt(index);
        _translationOptions.removeAt(index);
        _translationMarkedFilled.removeAt(index);
        _wordMarkedFilled.removeAt(index);
        _wordFocusNodes[index].dispose();
        _wordFocusNodes.removeAt(index);
        _translationFocusNodes[index].dispose();
        _translationFocusNodes.removeAt(index);

        // Видаляємо з popup controllers якщо є
        _popupControllers.remove(index);
        ref.read(wordInputNotifierProvider.notifier).removeAt(index);
      }
    });
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      // Flutter quirk: якщо переміщуємо вниз, треба зменшити newIndex на 1
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Синхронізуємо всі списки
      // 1. _wordPairs
      final wordPair = _wordPairs.removeAt(oldIndex);
      _wordPairs.insert(newIndex, wordPair);

      // 2. _wordControllers
      final wordController = _wordControllers.removeAt(oldIndex);
      _wordControllers.insert(newIndex, wordController);

      // 3. _translationControllers
      final translationController = _translationControllers.removeAt(oldIndex);
      _translationControllers.insert(newIndex, translationController);

      // 4. _isLoadingTranslation
      final isLoading = _isLoadingTranslation.removeAt(oldIndex);
      _isLoadingTranslation.insert(newIndex, isLoading);

      // 4b. _isLoadingWordTranslation
      final isLoadingWord = _isLoadingWordTranslation.removeAt(oldIndex);
      _isLoadingWordTranslation.insert(newIndex, isLoadingWord);

      // 5. _hasTranslationOptions
      final hasOptions = _hasTranslationOptions.removeAt(oldIndex);
      _hasTranslationOptions.insert(newIndex, hasOptions);

      // 5b. _translationOptions
      final options = _translationOptions.removeAt(oldIndex);
      _translationOptions.insert(newIndex, options);

      // 6. _translationMarkedFilled
      final markedFilled = _translationMarkedFilled.removeAt(oldIndex);
      _translationMarkedFilled.insert(newIndex, markedFilled);

      // 6b. _wordMarkedFilled
      final wordMarkedFilled = _wordMarkedFilled.removeAt(oldIndex);
      _wordMarkedFilled.insert(newIndex, wordMarkedFilled);

      // 7. _wordFocusNodes / _translationFocusNodes
      final wordFocusNode = _wordFocusNodes.removeAt(oldIndex);
      _wordFocusNodes.insert(newIndex, wordFocusNode);
      final translationFocusNode = _translationFocusNodes.removeAt(oldIndex);
      _translationFocusNodes.insert(newIndex, translationFocusNode);

      // 8. _popupControllers - очищуємо Map (найпростіше рішення)
      _popupControllers.clear();

      ref.read(wordInputNotifierProvider.notifier).reorder(oldIndex, newIndex);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    for (var controller in _translationControllers) {
      controller.dispose();
    }
    for (var node in _wordFocusNodes) {
      node.dispose();
    }
    for (var node in _translationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _buildRowItem(int index) {
    return WordRowItem(
      key: ValueKey(index),
      index: index,
      isDragMode: _isDragMode,
      wordController: _wordControllers[index],
      translationController: _translationControllers[index],
      wordFocusNode: _wordFocusNodes[index],
      translationFocusNode: _translationFocusNodes[index],
      isLoadingWordTranslation: _isLoadingWordTranslation[index],
      isLoadingTranslation: _isLoadingTranslation[index],
      shouldShowWordIcon: _shouldShowWordIcon(index),
      shouldShowTranslationIcon: _shouldShowTranslationIcon(index),
      hasTranslationOptions: _hasTranslationOptions[index],
      translationOptions: _translationOptions[index],
      popupController: _popupControllers.putIfAbsent(index, () => CustomPopupMenuController()),
      onRemove: () => _removeItem(index),
      onFillWordWithAI: () => _fillWordWithAI(index),
      onFillWithAI: () => _fillWithAI(index),
      onSelectTranslation: (translation) => _selectTranslationOption(index, translation),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureRowStateSynced(); // hot-reload safety net, see method doc above

    // One-time restore: once the persisted list first resolves, replace the
    // placeholder row created in initState() with what was saved. Later
    // notifier updates (all driven by this screen's own mutations, via
    // updateAt/removeAt/reorder/addAll below) must not re-trigger this.
    ref.listen<AsyncValue<List<WordPair>>>(wordInputNotifierProvider, (previous, next) {
      if (_restoredFromStore) return;
      next.whenData((pairs) {
        _restoredFromStore = true;
        if (pairs.isNotEmpty) _restoreFromStore(pairs);
      });
    });

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('English Vocabulary'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _navigateToTableScreen,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              child: const Text(
                'Меню',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Головний екран'),
              selected: !_isDragMode,
              onTap: () {
                setState(() {
                  _isDragMode = false;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drag_indicator),
              title: const Text('Drag and Drop мод'),
              selected: _isDragMode,
              onTap: () {
                setState(() {
                  _isDragMode = true;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Screenshot(
            controller: _screenshotController,
            child: _isDragMode
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _wordPairs.length,
                    onReorder: _reorderItems,
                    itemBuilder: (context, index) => _buildRowItem(index),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        child: child,
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _wordPairs.length,
                    itemBuilder: (context, index) => _buildRowItem(index),
                  ),
          ),
          if (_isAnalyzingPhoto)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analyzing photo...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: WordInputSpeedDial(
        onTakePhoto: _takePhotoForVocabulary,
        onScreenshot: _takeScreenshot,
      ),
    );
  }
}
