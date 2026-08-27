import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:translator/translator.dart';

import '../models/word_pair.dart';
import '../services/google_translate_dictionary_service.dart';
import '../services/translation_alternatives_service.dart'
    show selectAndNormalizeTranslations;
import '../widgets/animated_bolt_icon.dart' show BoltState;
import '../widgets/lottie_bolt_icon.dart';
import '../widgets/synced_text_field_row.dart';
import 'words_table_screen.dart';

class WordInputScreen extends StatefulWidget {
  const WordInputScreen({super.key});

  @override
  State<WordInputScreen> createState() => _WordInputScreenState();
}

class _WordInputScreenState extends State<WordInputScreen> {
  final List<WordPair> _wordPairs = [
    WordPair(word: '', translation: ''),
  ];

  final List<TextEditingController> _wordControllers = [];
  final List<TextEditingController> _translationControllers = [];
  final List<bool> _isLoadingTranslation = [];
  final List<bool> _isFetchingAdditionalInfo = [];
  final List<bool> _hasTranslationOptions = [];
  // Defaults to 4 until an AI-fill cycle actually resolves and picks a real
  // value; only ever set to 0, 2, 3, 4, or 5 afterwards (see _fillWithAI --
  // 1 alternative is treated as "0 popup-worthy options", and the bolt
  // animation has no dedicated single-star variant).
  final List<int> _starCount = [];
  // Real alternative translations, shown in the ready-state popup menu.
  // Sourced from Google Translate's combined dictionary call and then
  // cleaned up/trimmed by selectAndNormalizeTranslations (see
  // _fillWithAI). Empty until an AI-fill cycle resolves.
  final List<List<String>> _translationAlternatives = [];
  // Keeps the bolt icon's element (and its Lottie AnimationController/
  // composition) alive across state changes, since the icon's tap target is
  // rebuilt each time `_boltStateFor`/`onTap` change (and, for the ready
  // state, the wrapper widget type itself changes to `CustomPopupMenu`). A
  // stable GlobalKey is cheap defense-in-depth against ever silently
  // skipping the bloom-into-stars animation.
  final Map<int, GlobalKey> _boltIconKeys = {};
  final Map<int, CustomPopupMenuController> _popupControllers = {};
  final FocusNode _firstFieldFocusNode = FocusNode();
  // Whatever field had focus (and thus had the keyboard up) right before the
  // translation-alternatives popup opened, so it can be restored once the
  // popup closes. Null whenever no popup is currently open.
  FocusNode? _focusBeforePopup;
  bool _isDragMode = false;

  @override
  void initState() {
    super.initState();
    _addControllersForIndex(0);
    // Request focus on the first field after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFieldFocusNode.requestFocus();
    });
  }

  void _addControllersForIndex(int index) {
    final wordController = TextEditingController(text: _wordPairs[index].word);
    final translationController =
        TextEditingController(text: _wordPairs[index].translation);

    wordController.addListener(() {
      _wordPairs[index].word = wordController.text;
      _checkAndAddNewPair();
      setState(() {}); // Оновити для показу іконки при >= 2 літерах
    });

    translationController.addListener(() {
      _wordPairs[index].translation = translationController.text;
      _checkAndAddNewPair();

      // Якщо translation повністю видалений, скинути опції
      if (translationController.text.isEmpty && _hasTranslationOptions[index]) {
        setState(() {
          _hasTranslationOptions[index] = false;
        });
      }
    });

    _wordControllers.add(wordController);
    _translationControllers.add(translationController);
    _isLoadingTranslation.add(false);
    _isFetchingAdditionalInfo.add(false);
    _hasTranslationOptions.add(false);
    _starCount.add(4);
    _translationAlternatives.add([]);
  }

  void _checkAndAddNewPair() {
    if (_wordPairs.isEmpty) return;

    final lastPair = _wordPairs.last;
    if (lastPair.word.trim().isNotEmpty ||
        lastPair.translation.trim().isNotEmpty) {
      setState(() {
        _wordPairs.add(WordPair(word: '', translation: ''));
        _addControllersForIndex(_wordPairs.length - 1);
      });
    }
  }

  Future<void> _fillWithAI(int index) async {
    final word = _wordControllers[index].text.trim();
    if (word.isEmpty) return;

    setState(() {
      _isLoadingTranslation[index] = true;
    });

    // Почекати поки UI завершить рендер поточного frame
    await SchedulerBinding.instance.endOfFrame;

    // Translation source: a single call to the unofficial Google Translate
    // endpoint (fetchTranslationWithDictionary below), requesting both the
    // normal translation and dictionary/alternate-senses data in one
    // round-trip -- Azure Translator's Dictionary Lookup is no longer
    // needed for this at all (fetchAlternativeTranslations in
    // translation_alternatives_service.dart is superseded and unused; kept
    // only for reference). The plain translator-package call further below
    // is only a fallback for if this combined call itself fails.
    //
    // Cleanup pass: Google's raw dictionary list can be large/messy
    // (inflected forms, multi-word phrases, near-duplicates across parts
    // of speech), so it's run through selectAndNormalizeTranslations,
    // which uses Azure OpenAI to normalize+select the best few distinct
    // senses IF configured, or a simple non-AI heuristic otherwise -- see
    // that function's doc comment. Safe to call unconditionally either way.
    try {
      // One call gets both the primary translation and raw dictionary
      // alternates (see fetchTranslationWithDictionary's doc comment for
      // the verified response shape). Returns null on any failure --
      // never throws -- so the plain translator-package call below acts
      // as a fallback with zero alternatives rather than leaving the
      // field unfilled.
      //
      // ANIMATION NOTE: because this is now a single call, there's no
      // natural second network call left to drive the bolt animation's
      // loadingSecondary ("wandering star") phase, so it's simply never
      // triggered anymore -- _isFetchingAdditionalInfo stays false
      // throughout, and the icon goes straight from the loadingPrimary
      // shatter/hold state to the ready bloom once this resolves. Flagged
      // for product-owner input rather than papering over it (e.g. with a
      // fake delay); a possible future option is a time-based fallback
      // that switches into the wandering-star loop only if this call is
      // still pending after N seconds.
      final combined = await fetchTranslationWithDictionary(word);

      final String translationText;
      final List<String> rawAlternatives;
      if (combined != null) {
        translationText = combined.primaryTranslation;
        rawAlternatives = combined.alternatives;
      } else {
        final translator = GoogleTranslator();
        final translation =
            await translator.translate(word, from: 'en', to: 'uk');
        translationText = translation.text;
        rawAlternatives = const [];
      }

      final alternatives =
          await selectAndNormalizeTranslations(rawAlternatives, word);

      _translationControllers[index].text = translationText;

      if (!mounted) return;

      // A single alternative isn't worth a popup of its own (there's also
      // no dedicated single-star animation variant), so it's folded into
      // the 0-star/"no options" outcome. Otherwise, the bloom animation
      // only has pre-baked variants for 2-5 stars, so cap at 5 even if the
      // dictionary returns more senses than that.
      final starCount = alternatives.length <= 1 ? 0 : min(alternatives.length, 5);

      setState(() {
        _isLoadingTranslation[index] = false;
        _hasTranslationOptions[index] = true;
        _starCount[index] = starCount;
        _translationAlternatives[index] = alternatives;
      });
    } catch (e) {
      // Помилка перекладу - показати повідомлення
      setState(() {
        _isLoadingTranslation[index] = false;
        _isFetchingAdditionalInfo[index] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
    }
  }

  BoltState _boltStateFor(int index) {
    if (_isLoadingTranslation[index]) return BoltState.loadingPrimary;
    if (_isFetchingAdditionalInfo[index]) return BoltState.loadingSecondary;
    if (_hasTranslationOptions[index]) return BoltState.ready;
    return BoltState.idle;
  }

  void _selectTranslationOption(int index, String selectedTranslation) {
    _translationControllers[index].text = selectedTranslation;
  }

  /// Called via `CustomPopupMenu.menuOnChange` (see `_buildItem`), which
  /// fires both when the popup shows and whenever it hides -- including via
  /// `.hideMenu()` (X/check/item-selection) and via the package's own
  /// outside-tap dismissal (which also routes through the controller's
  /// `hideMenu()` internally, so it's covered here too).
  void _handlePopupVisibilityChanged(bool isShowing) {
    if (isShowing) {
      // Dismiss the keyboard right as the popup opens, since an anchored
      // popup can end up hidden behind/pushed off-screen by the keyboard
      // when a text field has focus (it's positioned relative to an anchor
      // point that the keyboard may cover).
      _focusBeforePopup = FocusManager.instance.primaryFocus;
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      final focusToRestore = _focusBeforePopup;
      _focusBeforePopup = null;
      if (focusToRestore != null && focusToRestore.context != null) {
        focusToRestore.requestFocus();
      }
    }
  }

  /// Builds the translation-alternatives picker's content, shown inside a
  /// `CustomPopupMenu` anchored to the bolt icon (see `_buildItem`).
  Widget _buildTranslationAlternativesMenu(int index) {
    final translations = _translationAlternatives[index];
    final selectedItems = List<bool>.generate(translations.length, (_) => false);

    return StatefulBuilder(
      builder: (context, setMenuState) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: Colors.black87,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (translations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No alternative translations found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
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
                                  activeColor: Colors.purple[300],
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
                            color: Colors.purple[300],
                            iconSize: 24,
                            onPressed: () {
                              final selected = <String>[
                                for (int i = 0; i < translations.length; i++)
                                  if (selectedItems[i]) translations[i],
                              ];

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

      // 5. _isFetchingAdditionalInfo
      final isFetchingAdditionalInfo =
          _isFetchingAdditionalInfo.removeAt(oldIndex);
      _isFetchingAdditionalInfo.insert(newIndex, isFetchingAdditionalInfo);

      // 6. _hasTranslationOptions
      final hasOptions = _hasTranslationOptions.removeAt(oldIndex);
      _hasTranslationOptions.insert(newIndex, hasOptions);

      // 7. _starCount
      final starCount = _starCount.removeAt(oldIndex);
      _starCount.insert(newIndex, starCount);

      // 8. _translationAlternatives
      final alternatives = _translationAlternatives.removeAt(oldIndex);
      _translationAlternatives.insert(newIndex, alternatives);

      // 9. _boltIconKeys - simplest to just clear the Map.
      _boltIconKeys.clear();

      // 10. _popupControllers - simplest to just clear the Map.
      _popupControllers.clear();
    });
  }

  @override
  void dispose() {
    _firstFieldFocusNode.dispose();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    for (var controller in _translationControllers) {
      controller.dispose();
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
                  color: Colors.purple[600],
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
                    color: Colors.purple[600],
                    onPressed: () {
                      // TODO: функціонал видалення
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Row з drag handle та Stack з полями
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dragHandle != null) ...[
                dragHandle,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Stack(
                  children: [
                    SyncedTextFieldRow(
                      leftController: _wordControllers[index],
                      rightController: _translationControllers[index],
                      leftLabel: 'Word',
                      rightLabel: 'Translation',
                      leftHint: 'Word',
                      rightHint: 'Translation',
                      leftFocusNode: index == 0 ? _firstFieldFocusNode : null,
                    ),
                    if (_wordControllers[index].text.length >= 2)
                      Positioned(
                        // Tucked snugly into the field's top-right corner
                        // (just past the field's own ~4px border radius).
                        top: 2,
                        right: 2,
                        child: _hasTranslationOptions[index]
                            ? CustomPopupMenu(
                                controller: _popupControllers.putIfAbsent(
                                    index, () => CustomPopupMenuController()),
                                pressType: PressType.singleClick,
                                showArrow: true,
                                arrowColor: Colors.black87,
                                arrowSize: 10,
                                barrierColor: Colors.transparent,
                                verticalMargin: 6,
                                menuOnChange: _handlePopupVisibilityChanged,
                                menuBuilder: () =>
                                    _buildTranslationAlternativesMenu(index),
                                child: LottieBoltIcon(
                                    key: _boltIconKeys.putIfAbsent(
                                        index, () => GlobalKey()),
                                    state: _boltStateFor(index),
                                    starCount: _starCount[index]),
                              )
                            : Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: (_isLoadingTranslation[index] ||
                                          _isFetchingAdditionalInfo[index])
                                      ? null
                                      : () => _fillWithAI(index),
                                  child: LottieBoltIcon(
                                      key: _boltIconKeys.putIfAbsent(
                                          index, () => GlobalKey()),
                                      state: _boltStateFor(index),
                                      starCount: _starCount[index]),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keeps the body's layout pixel-stable across the popup's
      // unfocus()/requestFocus() cycle (see _handlePopupVisibilityChanged):
      // by default Flutter resizes the body to avoid the keyboard, so
      // hiding/restoring it would otherwise reflow/"shake" the whole list
      // and momentarily desync the popup's anchor from the bolt icon. The
      // keyboard now overlays the content instead of resizing around it,
      // which also means normal typing no longer auto-shrinks the body to
      // reveal a focused field -- acceptable here since rows are compact
      // and users are typically already scrolled to what they're typing.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
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
      body: _isDragMode
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
    );
  }
}
