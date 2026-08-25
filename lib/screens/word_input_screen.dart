import 'package:flutter/material.dart';
import '../models/word_pair.dart';
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

  @override
  void initState() {
    super.initState();
    _addControllersForIndex(0);
  }

  void _addControllersForIndex(int index) {
    final wordController = TextEditingController(text: _wordPairs[index].word);
    final translationController =
        TextEditingController(text: _wordPairs[index].translation);

    wordController.addListener(() {
      _wordPairs[index].word = wordController.text;
      _checkAndAddNewPair();
    });

    translationController.addListener(() {
      _wordPairs[index].translation = translationController.text;
      _checkAndAddNewPair();
    });

    _wordControllers.add(wordController);
    _translationControllers.add(translationController);
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wordControllers[index],
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Word',
                        border: OutlineInputBorder(),
                        hintText: 'Enter English word',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _translationControllers[index],
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Translation',
                        border: OutlineInputBorder(),
                        hintText: 'Переклад',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
