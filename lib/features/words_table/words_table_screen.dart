import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/session_publish_service.dart';
import '../word_input/word_input_notifier.dart';
import 'anki_export.dart';

class WordsTableScreen extends ConsumerStatefulWidget {
  const WordsTableScreen({super.key, this.sessionId});

  /// Null for the current session (the words the input screen is editing);
  /// set when the screen was opened from a History row, in which case the
  /// words are read from the store instead of the notifier (task-10).
  final String? sessionId;

  @override
  ConsumerState<WordsTableScreen> createState() => _WordsTableScreenState();
}

class _WordsTableScreenState extends ConsumerState<WordsTableScreen> {
  /// True while `POST /sessions` is in flight. Disables the Share button so a
  /// double tap cannot publish twice; the request itself times out (AC-16).
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    // The input screen stays in the stack below this one with its last field
    // focused, so the keyboard would follow us here. There is nothing to type
    // on this screen — drop focus once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      // Belt and braces: ask the platform to hide the keyboard outright, in
      // case the input screen's field kept an open connection through the push.
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    });
  }

  // The format itself moved to anki_export.dart so the shared page's download
  // (task-07) and this file can be kept byte-identical against one spec.
  String _generateCloseUpB2Format(List<WordPair> wordPairs) =>
      generateAnkiFile(wordPairs);

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

  /// The Share button's menu: the file (the guaranteed return path, unchanged)
  /// or a public link to a read-only page (task-05).
  Future<void> _showShareOptions(List<WordPair> wordPairs) async {
    if (wordPairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words to share')),
      );
      return;
    }

    // A modal bottom sheet does not avoid the keyboard by itself: with the
    // keyboard up only the barrier is visible and the sheet sits behind it.
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('Share file'),
                subtitle: const Text('Text file for AnkiDroid'),
                onTap: () => Navigator.pop(sheetContext, _ShareChoice.file),
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Share link'),
                subtitle: const Text('A web page anyone with the link can read'),
                onTap: () => Navigator.pop(sheetContext, _ShareChoice.link),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;

    switch (choice) {
      case _ShareChoice.file:
        await _shareWords(wordPairs);
      case _ShareChoice.link:
        await _shareLink(wordPairs);
    }
  }

  Future<void> _shareLink(List<WordPair> wordPairs) async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      final published =
          await ref.read(sessionPublishServiceProvider).publish(wordPairs);
      // The point is handing the URL over in the next five seconds: it is on
      // the clipboard before the dialog even opens.
      await Clipboard.setData(ClipboardData(text: published.url));
      // `markShared` flags the session the notifier holds, so it applies only
      // when this screen is showing that session. A History row publishes the
      // words without restamping the current session.
      if (widget.sessionId == null) {
        await ref.read(wordInputNotifierProvider.notifier).markShared();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
      await _showPublishedLinkDialog(published);
    } on SessionPublishException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish the link: $e')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish the link: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _showPublishedLinkDialog(PublishedSession published) {
    final expiresAt = published.expiresAt;
    final expiry = expiresAt == null
        ? 'The page stays up for 30 days.'
        : 'The page stays up until '
            '${expiresAt.toLocal().day.toString().padLeft(2, '0')}.'
            '${expiresAt.toLocal().month.toString().padLeft(2, '0')}.'
            '${expiresAt.toLocal().year}.';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Link ready'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anyone with this link can read the words. $expiry'),
            const SizedBox(height: 12),
            SelectableText(
              published.url,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: published.url));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () =>
                Share.share(published.url, subject: 'English Vocabulary'),
            child: const Text('Share…'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final words = sessionId == null
        ? ref.watch(wordInputNotifierProvider).valueOrNull?.words
        : ref.watch(sessionByIdProvider(sessionId)).valueOrNull?.words;
    final wordPairs = (words ?? const <WordPair>[])
        .where((pair) => pair.isValid)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Words Table'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed:
                  _isPublishing ? null : () => _showShareOptions(wordPairs),
              icon: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
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

enum _ShareChoice { file, link }
