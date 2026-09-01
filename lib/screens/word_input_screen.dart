import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translator/translator.dart';

import '../models/vocab_word.dart';
import '../models/word_pair.dart';
import '../services/photo_scaler.dart';
import '../services/vocab_photo_service.dart';
import '../widgets/synced_text_field_row.dart';
import 'words_table_screen.dart';

class WordInputScreen extends StatefulWidget {
  const WordInputScreen({super.key});

  @override
  State<WordInputScreen> createState() => _WordInputScreenState();
}

class _WordInputScreenState extends State<WordInputScreen> with WidgetsBindingObserver {
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
  final VocabPhotoService _vocabPhotoService = VocabPhotoService();
  bool _isAnalyzingPhoto = false;
  bool _isRecoveringLostPhoto = false;

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
      _checkAndAddNewPair();

      // Якщо word повністю видалений, скинути "filled"-мітку
      final wordIsEmptyNow = wordController.text.isEmpty;
      final shouldResetWordFilledMark =
          wordIsEmptyNow && _wordMarkedFilled[index];

      setState(() {
        if (shouldResetWordFilledMark) {
          _wordMarkedFilled[index] = false;
        }
      }); // Оновити для показу іконки при >= 2 літерах
    });

    translationController.addListener(() {
      _wordPairs[index].translation = translationController.text;
      _checkAndAddNewPair();

      // Якщо translation повністю видалений, скинути опції й "filled"-мітку
      final isEmptyNow = translationController.text.isEmpty;
      final shouldResetOptions = isEmptyNow && _hasTranslationOptions[index];
      final shouldResetFilledMark =
          isEmptyNow && _translationMarkedFilled[index];

      setState(() {
        if (shouldResetOptions) {
          _hasTranslationOptions[index] = false;
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
    _translationMarkedFilled.add(false);
    _wordMarkedFilled.add(false);
    _wordFocusNodes.add(wordFocusNode);
    _translationFocusNodes.add(translationFocusNode);
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
      setState(() {
        _wordPairs.add(WordPair(word: '', translation: ''));
        _addControllersForIndex(_wordPairs.length - 1);
      });
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

  /// Heuristic for "did we get an actual translation, or just an echo of
  /// the input back?" Google Translate (via the `translator` package)
  /// doesn't signal failure when it has no translation for the input --
  /// it silently returns the input text unchanged (seen for short or
  /// ambiguous words, proper nouns, or when there's simply no distinct
  /// translation available). Comparing the (trimmed) input and output
  /// catches that case. See docs/lightning_icon_rules.md.
  bool _isRealTranslation(String input, String output) {
    return output.trim() != input.trim();
  }

  /// Whether [char] (expected to be a single character) is an ASCII
  /// English letter. Used to guess whether the Word field's content is
  /// English by looking at just its first letter -- see
  /// docs/lightning_icon_rules.md.
  bool _isEnglishLetter(String char) {
    return RegExp(r'^[A-Za-z]$').hasMatch(char);
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

  /// Translation dots button: unlike the Translation icon, this sits
  /// *outside* the Translation field (a plain sibling in the outer Row,
  /// not overlaid via Positioned) and is always visible -- no focus or
  /// length gating, and no loading state of its own. It tracks
  /// `_hasTranslationOptions`: empty (outlined) dots by default, full
  /// (solid) dots once a translate has produced multiple options for this
  /// row -- including while a translate request is in flight, the dots
  /// just stay in their current (empty or full) state and flip once the
  /// request resolves; the Translation icon's own overlay slot is what
  /// shows the loading spinner. Tapping empty dots does nothing for now;
  /// tapping full dots opens the "more options" popup.
  Widget _buildTranslationDotsButton(int index) {
    final isFilled = _hasTranslationOptions[index];
    final dotIcon = isFilled ? Icons.circle : Icons.circle_outlined;
    final dotColor = Colors.purple[600];
    final dotsIcon = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(dotIcon, size: 6, color: dotColor),
        const SizedBox(height: 3),
        Icon(dotIcon, size: 6, color: dotColor),
        const SizedBox(height: 3),
        Icon(dotIcon, size: 6, color: dotColor),
      ],
    );

    // Both branches below share the same 22px-wide footprint and zero
    // extra padding around the dots, so toggling `isFilled` never shifts
    // the row's layout.
    if (isFilled) {
      return SizedBox(
        width: 22,
        child: CustomPopupMenu(
          controller:
              _popupControllers.putIfAbsent(index, () => CustomPopupMenuController()),
          pressType: PressType.singleClick,
          showArrow: true,
          arrowColor: Colors.black87,
          arrowSize: 10,
          barrierColor: Colors.transparent,
          verticalMargin: 6,
          menuBuilder: () {
            final maxWidth = MediaQuery.of(context).size.width * 0.7;
            final translations = [
              'лололололо лолололо переклад 1',
              'переклад 2',
              'переклад 3',
            ];
            var selectedItems = List<bool>.generate(translations.length, (_) => false);

            return StatefulBuilder(
              builder: (context, setMenuState) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Material(
                    color: Colors.black87,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < translations.length; i++)
                              InkWell(
                                onTap: () {
                                  _popupControllers[index]!.hideMenu();
                                  _selectTranslationOption(index, translations[i]);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: Checkbox(
                                          value: selectedItems[i],
                                          onChanged: (bool? value) {
                                            setMenuState(() {
                                              selectedItems[i] = value ?? false;
                                            });
                                          },
                                          activeColor: Colors.amber[600],
                                          checkColor: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          translations[i],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                          softWrap: true,
                                          maxLines: null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const Divider(color: Colors.white24, height: 1),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Colors.white70,
                                    iconSize: 24,
                                    onPressed: () {
                                      _popupControllers[index]!.hideMenu();
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    color: Colors.amber[600],
                                    iconSize: 24,
                                    onPressed: () {
                                      final selected = <String>[];
                                      for (int i = 0; i < translations.length; i++) {
                                        if (selectedItems[i]) {
                                          selected.add(translations[i]);
                                        }
                                      }

                                      if (selected.isNotEmpty) {
                                        _popupControllers[index]!.hideMenu();
                                        _selectTranslationOption(
                                            index, selected.join(', '));
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          child: Center(child: dotsIcon),
        ),
      );
    }

    // Empty -- nothing to do yet, so tapping is a no-op.
    return SizedBox(
      width: 22,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
        icon: dotsIcon,
        onPressed: null,
      ),
    );
  }

  /// Translate Translation -> Word. The Translation field can be in any
  /// language Google Translate supports (auto-detected -- from: 'auto'),
  /// translated to English for the Word field. See
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
      final translator = GoogleTranslator();
      final translation = await translator.translate(
        translationText,
        from: 'auto',
        to: 'en',
      );

      _wordControllers[index].text = translation.text;

      final gotRealTranslation =
          _isRealTranslation(translationText, translation.text);

      setState(() {
        _isLoadingWordTranslation[index] = false;
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
  /// as before: English -> Ukrainian. Otherwise the Word field probably
  /// holds what should have been the Translation (typed into the wrong
  /// field), so instead this auto-detects its language, translates to
  /// English, and -- only on a real translation -- swaps the two fields:
  /// the text the user typed moves to Translation, the English result
  /// moves to Word. See docs/lightning_icon_rules.md.
  Future<void> _fillWithAI(int index) async {
    final word = _wordControllers[index].text.trim();
    if (word.isEmpty) return;

    final wordStartsWithEnglishLetter = _isEnglishLetter(word[0]);

    setState(() {
      _isLoadingTranslation[index] = true;
    });

    // Почекати поки UI завершить рендер поточного frame
    await SchedulerBinding.instance.endOfFrame;

    try {
      final translator = GoogleTranslator();

      if (wordStartsWithEnglishLetter) {
        // Google Translate: English -> Ukrainian
        final translation =
            await translator.translate(word, from: 'en', to: 'uk');

        _translationControllers[index].text = translation.text;

        final gotRealTranslation = _isRealTranslation(word, translation.text);

        setState(() {
          _isLoadingTranslation[index] = false;
          _hasTranslationOptions[index] = true;
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
            await translator.translate(word, from: 'auto', to: 'en');
        final gotRealTranslation = _isRealTranslation(word, translation.text);

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
    final validPairs = _wordPairs.where((pair) => pair.isValid).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordsTableScreen(wordPairs: validPairs),
      ),
    );
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
      final result = await _vocabPhotoService.analyzePhoto(
        bytes,
        mediaType: 'image/jpeg',
        translation: true,
        withDesc: true,
        shortifyDefinition: true,
        limit: 20,
      );
      requestStopwatch.stop();

      if (mounted) {
        _showVocabResultDialog(
          result.words,
          compressDuration: compressStopwatch.elapsed,
          requestDuration: requestStopwatch.elapsed,
          aiDuration: result.aiDuration,
        );
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

  String _formatDuration(Duration d) {
    final seconds = d.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(2)}s';
  }

  void _showVocabResultDialog(
    List<VocabWord> words, {
    required Duration compressDuration,
    required Duration requestDuration,
    Duration? aiDuration,
  }) {
    final timingLines = <String>[
      'Compressing photo: ${_formatDuration(compressDuration)}',
      'Sending & receiving response: ${_formatDuration(requestDuration)}',
      if (aiDuration != null) '  \u2514 AI processing on server: ${_formatDuration(aiDuration)}',
    ];

    // Words the user hasn't crossed out; whatever is left here when the
    // dialog is closed gets added to the main screen.
    final remainingWords = List<VocabWord>.of(words);

    showDialog<List<VocabWord>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Vocabulary Found'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timingLines.join('\n'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: remainingWords.isEmpty
                          ? const Text('No vocabulary words found in this photo.')
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: remainingWords.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final w = remainingWords[index];
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              w.word,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            if (w.translation != null) Text('Translation: ${w.translation}'),
                                            if (w.description != null) Text('Description: ${w.description}'),
                                            if (w.context != null)
                                              Text(
                                                'Context: ${w.context}',
                                                style: const TextStyle(fontStyle: FontStyle.italic),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.black),
                                      tooltip: 'Skip this word',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setDialogState(() {
                                          remainingWords.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, remainingWords),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    ).then((selected) {
      if (selected != null && selected.isNotEmpty) {
        _addWordsFromPhoto(selected);
      }
    });
  }

  /// Appends words kept in the photo-results dialog to the main word list,
  /// reusing the still-empty first row if the screen hasn't been touched yet.
  void _addWordsFromPhoto(List<VocabWord> words) {
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
        } else {
          _wordPairs.add(WordPair(word: w.word, translation: translation));
          _addControllersForIndex(_wordPairs.length - 1);
          _translationMarkedFilled[_wordPairs.length - 1] =
              translation.isNotEmpty;
          _wordMarkedFilled[_wordPairs.length - 1] = w.word.isNotEmpty;
        }
      }
      _checkAndAddNewPair();
    });
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
        _translationMarkedFilled[0] = false;
        _wordMarkedFilled[0] = false;
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
        _translationMarkedFilled.removeAt(index);
        _wordMarkedFilled.removeAt(index);
        _wordFocusNodes[index].dispose();
        _wordFocusNodes.removeAt(index);
        _translationFocusNodes[index].dispose();
        _translationFocusNodes.removeAt(index);

        // Видаляємо з popup controllers якщо є
        _popupControllers.remove(index);
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

  Widget _buildItem(BuildContext context, int index) {
    final dragHandle = _isDragMode
        ? ReorderableDragStartListener(
            index: index,
            child: SizedBox(
              width: 32,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.drag_indicator,
                  color: const Color(0xFF7F77DD),
                  size: 32,
                ),
              ),
            ),
          )
        : null;

    return Container(
      key: ValueKey(index),
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.only(top: 4, right: 8, bottom: 12, left: 8),
      decoration: BoxDecoration(
        color: const Color(0x57d9c1ff),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Верхній рядок: кнопка видалення
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    splashRadius: 16,
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    color: const Color(0xFFa883ca),
                    onPressed: () => _removeItem(index),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Row з drag handle та Stack з полями
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (dragHandle != null) ...[
                dragHandle,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Must match the `spacing` passed to SyncedTextFieldRow
                    // below, so the Word icon's right edge lines up with the
                    // boundary between the Word and Translation fields (same
                    // padding pattern the Translation icon uses on the
                    // stack's own right edge).
                    const fieldSpacing = 16.0;
                    final wordFieldRightEdge =
                        (constraints.maxWidth - fieldSpacing) / 2;
                    return Stack(
                  children: [
                    SyncedTextFieldRow(
                      leftController: _wordControllers[index],
                      rightController: _translationControllers[index],
                      leftLabel: 'Word',
                      rightLabel: 'Translation',
                      leftHint: 'Word',
                      rightHint: 'Translation',
                      leftFocusNode: _wordFocusNodes[index],
                      rightFocusNode: _translationFocusNodes[index],
                      spacing: fieldSpacing,
                    ),
                    if (_isLoadingWordTranslation[index] ||
                        _shouldShowWordIcon(index))
                      Positioned(
                        top: 2,
                        // End of the Word field, mirroring the Translation
                        // icon's `right: 2` (see docs/lightning_icon_rules.md).
                        right: constraints.maxWidth - wordFieldRightEdge + 2,
                        child: _isLoadingWordTranslation[index]
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.electric_bolt),
                                  color: Colors.purple[600],
                                  iconSize: 28,
                                  tooltip: 'AI Translate (to Word)',
                                  onPressed: () => _fillWordWithAI(index),
                                ),
                              ),
                      ),
                    if (_isLoadingTranslation[index] ||
                        _shouldShowTranslationIcon(index))
                      Positioned(
                        top: 2,
                        right: 2,
                        child: _isLoadingTranslation[index]
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.electric_bolt),
                                  color: Colors.purple[600],
                                  iconSize: 28,
                                  tooltip: 'AI Translate',
                                  onPressed: () => _fillWithAI(index),
                                ),
                              ),
                      ),
                  ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              _buildTranslationDotsButton(index),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureRowStateSynced(); // hot-reload safety net, see method doc above
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
                    itemBuilder: _buildItem,
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
                    itemBuilder: _buildItem,
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
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.red[700],
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        elevation: 8.0,
        shape: const CircleBorder(),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: 'Take Photo',
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            onTap: _takePhotoForVocabulary,
          ),
          SpeedDialChild(
            child: const Icon(Icons.screenshot),
            label: 'Screenshot',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onTap: _takeScreenshot,
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            onTap: () {
              // Placeholder for future feature
            },
          ),
        ],
      ),
    );
  }
}
