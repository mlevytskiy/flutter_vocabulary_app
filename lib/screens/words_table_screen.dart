import 'package:flutter/material.dart';
import '../models/word_pair.dart';

class WordsTableScreen extends StatelessWidget {
  final List<WordPair> wordPairs;

  const WordsTableScreen({super.key, required this.wordPairs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Words Table'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
