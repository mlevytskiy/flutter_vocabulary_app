import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:translator/translator.dart';

import '../models/word_pair.dart';
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
  final List<bool> _hasTranslationOptions = [];
  final Map<int, CustomPopupMenuController> _popupControllers = {};
  final FocusNode _firstFieldFocusNode = FocusNode();

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
    _hasTranslationOptions.add(false);
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

    try {
      // Google Translate: English -> Ukrainian
      final translator = GoogleTranslator();
      final translation =
          await translator.translate(word, from: 'en', to: 'uk');

      _translationControllers[index].text = translation.text;

      setState(() {
        _isLoadingTranslation[index] = false;
        _hasTranslationOptions[index] = true;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _wordPairs.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            padding:
                const EdgeInsets.only(top: 4, right: 8, bottom: 12, left: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Верхній рядок: кнопка видалення
                SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          icon: const Icon(Icons.close),
                          color: const Color(0xFF7F77DD),
                          onPressed: () {
                            // TODO: функціонал видалення
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Stack з полями та молнією
                Stack(
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
                        top: 12,
                        right: 4,
                        child: _isLoadingTranslation[index]
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              )
                            : _hasTranslationOptions[index]
                                ? CustomPopupMenu(
                                    controller: _popupControllers.putIfAbsent(
                                        index,
                                        () => CustomPopupMenuController()),
                                    pressType: PressType.singleClick,
                                    showArrow: true,
                                    arrowColor: Colors.black87,
                                    arrowSize: 10,
                                    barrierColor: Colors.transparent,
                                    verticalMargin: 6,
                                    menuBuilder: () {
                                      final maxWidth =
                                          MediaQuery.of(context).size.width *
                                              0.7;
                                      final translations = [
                                        'лололололо лолололо переклад 1',
                                        'переклад 2',
                                        'переклад 3',
                                      ];
                                      var selectedItems = List<bool>.generate(
                                          translations.length, (_) => false);

                                      return StatefulBuilder(
                                        builder: (context, setMenuState) {
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Material(
                                              color: Colors.black87,
                                              child: Container(
                                                constraints: BoxConstraints(
                                                    maxWidth: maxWidth),
                                                child: IntrinsicWidth(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      // Вертикальний список перекладів з checkboxами
                                                      for (int i = 0;
                                                          i <
                                                              translations
                                                                  .length;
                                                          i++)
                                                        InkWell(
                                                          onTap: () {
                                                            // Клік по тексту - вибрати тільки цей і закрити
                                                            _popupControllers[
                                                                    index]!
                                                                .hideMenu();
                                                            _selectTranslationOption(
                                                                index,
                                                                translations[
                                                                    i]);
                                                          },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical: 8,
                                                                    horizontal:
                                                                        12),
                                                            child: Row(
                                                              children: [
                                                                // Checkbox - клік toggle без закриття
                                                                SizedBox(
                                                                  width: 40,
                                                                  height: 40,
                                                                  child:
                                                                      Checkbox(
                                                                    value:
                                                                        selectedItems[
                                                                            i],
                                                                    onChanged:
                                                                        (bool?
                                                                            value) {
                                                                      setMenuState(
                                                                          () {
                                                                        selectedItems[i] =
                                                                            value ??
                                                                                false;
                                                                      });
                                                                    },
                                                                    activeColor:
                                                                        Colors.amber[
                                                                            600],
                                                                    checkColor:
                                                                        Colors
                                                                            .black,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    width: 8),
                                                                // Текст перекладу
                                                                Expanded(
                                                                  child: Text(
                                                                    translations[
                                                                        i],
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                    softWrap:
                                                                        true,
                                                                    maxLines:
                                                                        null,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),

                                                      const Divider(
                                                          color: Colors.white24,
                                                          height: 1),

                                                      // Горизонтальний ряд кнопок внизу
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
                                                            // ✕ Cancel
                                                            IconButton(
                                                              icon: const Icon(
                                                                  Icons.close),
                                                              color: Colors
                                                                  .white70,
                                                              iconSize: 24,
                                                              onPressed: () {
                                                                _popupControllers[
                                                                        index]!
                                                                    .hideMenu();
                                                              },
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            // ✓ Done
                                                            IconButton(
                                                              icon: const Icon(
                                                                  Icons.check),
                                                              color: Colors
                                                                  .amber[600],
                                                              iconSize: 24,
                                                              onPressed: () {
                                                                final selected =
                                                                    <String>[];
                                                                for (int i = 0;
                                                                    i <
                                                                        translations
                                                                            .length;
                                                                    i++) {
                                                                  if (selectedItems[
                                                                      i]) {
                                                                    selected.add(
                                                                        translations[
                                                                            i]);
                                                                  }
                                                                }

                                                                if (selected
                                                                    .isNotEmpty) {
                                                                  _popupControllers[
                                                                          index]!
                                                                      .hideMenu();
                                                                  _selectTranslationOption(
                                                                      index,
                                                                      selected.join(
                                                                          ', '));
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.electric_bolt,
                                        color: Colors.amber[600],
                                        size: 28,
                                      ),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
