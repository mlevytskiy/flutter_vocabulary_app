import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:translator/translator.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

import '../models/word_pair.dart';
import '../models/vocab_word.dart';
import '../services/photo_scaler.dart';
import '../services/vocab_photo_service.dart';
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
  bool _isDragMode = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  final VocabPhotoService _vocabPhotoService = VocabPhotoService();
  bool _isAnalyzingPhoto = false;

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
    final XFile? picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final originalBytes = await picked.readAsBytes();

    setState(() {
      _isAnalyzingPhoto = true;
    });

    try {
      final compressStopwatch = Stopwatch()..start();
      final bytes = await PhotoScaler.instance.resizeToMinSide(
        originalBytes,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
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
      if (aiDuration != null)
        '  \u2514 AI processing on server: ${_formatDuration(aiDuration)}',
    ];

    showDialog(
      context: context,
      builder: (context) {
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
                  child: words.isEmpty
                      ? const Text('No vocabulary words found in this photo.')
                      : ListView.separated(
                    shrinkWrap: true,
                    itemCount: words.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final w = words[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.word,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (w.translation != null)
                            Text('Translation: ${w.translation}'),
                          if (w.description != null)
                            Text('Description: ${w.description}'),
                          if (w.context != null)
                            Text(
                              'Context: ${w.context}',
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      if (index == 0) {
        // Для першого айтема тільки очищуємо поля
        _wordControllers[0].clear();
        _translationControllers[0].clear();
        _wordPairs[0] = WordPair(word: '', translation: '');
        _isLoadingTranslation[0] = false;
        _hasTranslationOptions[0] = false;
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
        _hasTranslationOptions.removeAt(index);

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

      // 5. _hasTranslationOptions
      final hasOptions = _hasTranslationOptions.removeAt(oldIndex);
      _hasTranslationOptions.insert(newIndex, hasOptions);

      // 6. _popupControllers - очищуємо Map (найпростіше рішення)
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
                        top: 2,
                        right: 2,
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
                                                      for (int i = 0;
                                                          i <
                                                              translations
                                                                  .length;
                                                          i++)
                                                        InkWell(
                                                          onTap: () {
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
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
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
