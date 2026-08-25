import 'package:flutter/material.dart';
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
  final List<bool> _wasAutoFilled = [];
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

      // Якщо translation повністю видалений, скинути wasAutoFilled
      if (translationController.text.isEmpty && _wasAutoFilled[index]) {
        setState(() {
          _wasAutoFilled[index] = false;
        });
      }
    });

    _wordControllers.add(wordController);
    _translationControllers.add(translationController);
    _isLoadingTranslation.add(false);
    _wasAutoFilled.add(false);
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

    // Дати UI час відрендерити loader перед запитом
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // Google Translate: English -> Ukrainian
      final translator = GoogleTranslator();
      final translation =
          await translator.translate(word, from: 'en', to: 'uk');

      _translationControllers[index].text = translation.text;

      setState(() {
        _isLoadingTranslation[index] = false;
        _wasAutoFilled[index] = true;
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
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            elevation: 2,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SyncedTextFieldRow(
                    leftController: _wordControllers[index],
                    rightController: _translationControllers[index],
                    leftLabel: 'Word',
                    rightLabel: 'Translation',
                    leftHint: 'Word',
                    rightHint: 'Translation',
                    leftFocusNode: index == 0 ? _firstFieldFocusNode : null,
                  ),
                ),
                if (_wordControllers[index].text.length >= 2)
                  Positioned(
                    top: 16,
                    right: 8,
                    child: _isLoadingTranslation[index]
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        : _wasAutoFilled[index]
                            ? Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.edit),
                                  color: Colors.grey[600],
                                  iconSize: 24,
                                  tooltip: 'Edit Translation',
                                  onPressed: () => _fillWithAI(index),
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
          );
        },
      ),
    );
  }
}
