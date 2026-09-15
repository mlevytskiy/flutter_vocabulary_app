import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';

class WordsTableScreen extends ConsumerStatefulWidget {
  const WordsTableScreen({super.key});

  @override
  ConsumerState<WordsTableScreen> createState() => _WordsTableScreenState();
}

class _WordsTableScreenState extends ConsumerState<WordsTableScreen> {
  String _generateCloseUpB2Format(List<WordPair> wordPairs) {
    final buffer = StringBuffer();

    // Add header
    buffer.writeln('#separator:tab');
    buffer.writeln('#html:true');
    buffer.writeln('#tags column:3');

    // Add word pairs
    for (var pair in wordPairs) {
      buffer.writeln('${pair.word}\t${pair.translation}\t');
    }

    return buffer.toString();
  }

  Future<void> _shareWords(List<WordPair> wordPairs) async {
    if (wordPairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words to share')),
      );
      return;
    }

    try {
      // Generate content
      final content = _generateCloseUpB2Format(wordPairs);

      // Get current date for filename
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/vocabulary_$dateStr.txt';

      // Create file
      final file = File(filePath);
      await file.writeAsString(content);

      // Share file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'English Vocabulary - Close-up B2 Format',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordPairs = ref.watch(validPairsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Words Table'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _shareWords(wordPairs),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: wordPairs.isEmpty
          ? const Center(
              child: Text(
                'No words added yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.primaryContainer,
                    ),
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Word',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Translation',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: List<DataRow>.generate(
                      wordPairs.length,
                      (index) => DataRow(
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(wordPairs[index].word)),
                          DataCell(Text(wordPairs[index].translation)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
