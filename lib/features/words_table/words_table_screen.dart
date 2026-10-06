import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/session.dart';
import '../../core/models/session_source.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/session_publish_service.dart';
import '../word_input/word_input_notifier.dart';
import 'anki_export.dart';
import 'photo_viewer.dart';

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

  /// The "Include photos (N)" switch above the table; on until switched off.
  bool _includePhotos = true;

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
      generateAnkiFile(wordPairs, detail: ref.read(wordDetailModeProvider));

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
    final session = _session();
    final includePhotos =
        _includePhotos && _linkedPhotos(session, wordPairs).isNotEmpty;
    final publishedBefore = session?.publishedId != null;
    // The warning names what sharing again does: replacing the partner's
    // edits (ADR-0008) and, with photos, putting them on a public page.
    const photosNote =
        'Included photos are visible to anyone with the link for 30 days.';
    final String? warning = switch ((publishedBefore, includePhotos)) {
      (true, true) => 'This list was shared before. Sharing it again replaces '
          'the edits made on the shared page. $photosNote',
      (true, false) => 'This list was shared before. Sharing it again '
          'replaces the edits made on the shared page.',
      (false, true) => photosNote,
      (false, false) => null,
    };
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
                subtitle:
                    const Text('A web page anyone with the link can read'),
                onTap: () => Navigator.pop(sheetContext, _ShareChoice.link),
              ),
              if (warning != null)
                ListTile(
                  leading: Icon(publishedBefore
                      ? Icons.warning_amber_outlined
                      : Icons.photo_library_outlined),
                  subtitle: Text(warning),
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
        await _shareLink(wordPairs, includePhotos: includePhotos);
    }
  }

  /// The photos a link would carry: "include photos (N)" counts only photos
  /// with a linked row that will be published; with none the switch is not
  /// shown (AC-23).
  List<SessionSource> _linkedPhotos(Session? session, List<WordPair> wordPairs) {
    final linkedIds = {for (final pair in wordPairs) pair.sourceId};
    return (session?.sources ?? const <SessionSource>[])
        .where((photo) => linkedIds.contains(photo.id))
        .toList();
  }

  Future<void> _shareLink(List<WordPair> wordPairs,
      {required bool includePhotos}) async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      final session = _session();
      final published =
          await ref.read(sessionPublishServiceProvider).publish(wordPairs,
              detail: ref.read(wordDetailModeProvider),
              // Switched off, no photo reaches the page (AC-24).
              sources: includePhotos ? session?.sources ?? const [] : const [],
              publishedId: session?.publishedId,
              editToken: session?.editToken);
      // Never awaited: the link dialog does not wait for photos (AC-37).
      ref
          .read(photoUploadServiceProvider)
          .enqueue(published.id, published.declaredSources);
      // The point is handing the URL over in the next five seconds: it is on
      // the clipboard before the dialog even opens.
      await Clipboard.setData(ClipboardData(text: published.url));
      await _rememberPublished(published);
      if (!mounted) return;
      // Publishing is over: the button stops spinning while the dialog is up.
      setState(() => _isPublishing = false);
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

  /// The session this screen shows: the notifier's for the current one, the
  /// stored one for a History row.
  Session? _session() {
    final sessionId = widget.sessionId;
    return sessionId == null
        ? ref.read(wordInputNotifierProvider).valueOrNull
        : ref.read(sessionByIdProvider(sessionId)).valueOrNull;
  }

  /// Keeps the published id and edit token so the next publish overwrites the
  /// same link (ADR-0008). `markShared` also flags the current session; a
  /// History row is written to the store without restamping anything.
  Future<void> _rememberPublished(PublishedSession published) async {
    final sessionId = widget.sessionId;
    // A History row may be the session the notifier holds: update it there,
    // or its next save would write the old id and token back.
    final current = ref.exists(wordInputNotifierProvider)
        ? ref.read(wordInputNotifierProvider).valueOrNull
        : null;
    if (sessionId == null || current?.sessionId == sessionId) {
      await ref.read(wordInputNotifierProvider.notifier).markShared(
          publishedId: published.id, editToken: published.editToken);
      return;
    }
    // The link dialog does not wait for opening the store.
    unawaited(_rememberForHistoryRow(sessionId, published));
  }

  Future<void> _rememberForHistoryRow(
      String sessionId, PublishedSession published) async {
    try {
      final store = await ref.read(sessionStoreProvider.future);
      final stored = await store.byId(sessionId);
      if (stored == null) return;
      stored
        ..publishedId = published.id
        ..editToken = published.editToken;
      await store.put(stored);
      ref.invalidate(sessionByIdProvider(sessionId));
    } catch (_) {
      // The link is out already; missing the token only means the next
      // publish makes a new link instead of overwriting this one.
    }
  }

  Future<void> _showPublishedLinkDialog(PublishedSession published) {
    final expiresAt = published.expiresAt;
    final leftOut = published.leftOutSources.length;
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
            // Past the first 10 taken, photos stay off the page (spec OQ-3).
            if (leftOut > 0) ...[
              const SizedBox(height: 12),
              Text(leftOut == 1
                  ? '1 photo was left out: a page holds the first '
                      '${SessionPublishService.maxSources} photos taken.'
                  : '$leftOut photos were left out: a page holds the first '
                      '${SessionPublishService.maxSources} photos taken.'),
            ],
            const SizedBox(height: 12),
            // Tapping the link opens the page in the browser.
            Semantics(
              link: true,
              child: InkWell(
                onTap: () => _openLink(published.url),
                child: Text(
                  published.url,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(dialogContext).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
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

  Future<void> _openLink(String url) async {
    bool opened;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final session = sessionId == null
        ? ref.watch(wordInputNotifierProvider).valueOrNull
        : ref.watch(sessionByIdProvider(sessionId)).valueOrNull;
    // definition-mode: every filled row -- a word plus a translation or a
    // definition -- whatever the mode (spec AC-12); the mode picks columns.
    final wordPairs = (session?.words ?? const <WordPair>[])
        .where((pair) => pair.isFilled)
        .toList();
    final photos = _linkedPhotos(session, wordPairs);
    final detailMode = ref.watch(wordDetailModeProvider);
    final showTranslation = detailMode != WordDetailMode.definition;
    final showDefinition = detailMode != WordDetailMode.translation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Words'),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photos.isNotEmpty)
                  SwitchListTile(
                    // Tapping the stack opens the photos, as on the page.
                    secondary: Semantics(
                      button: true,
                      label: 'Show photos',
                      child: GestureDetector(
                        onTap: () => showPhotoViewer(context, photos),
                        child: _PhotoStack(photos: photos),
                      ),
                    ),
                    title: Text('Include photos (${photos.length})'),
                    value: _includePhotos,
                    onChanged: (value) =>
                        setState(() => _includePhotos = value),
                  ),
                Expanded(
                    child: _table(wordPairs,
                        showTranslation: showTranslation,
                        showDefinition: showDefinition)),
              ],
            ),
    );
  }

  Widget _table(List<WordPair> wordPairs,
      {required bool showTranslation, required bool showDefinition}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable(
            // Wrapped definitions need taller rows; translation mode
            // keeps the table's default fixed row height.
            dataRowMaxHeight: showDefinition ? double.infinity : null,
            headingRowColor: WidgetStateProperty.all(
              Theme.of(context).colorScheme.primaryContainer,
            ),
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            columns: [
              const DataColumn(
                label: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const DataColumn(
                label: Text(
                  'Word',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (showTranslation)
                const DataColumn(
                  label: Text(
                    'Translation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (showDefinition)
                const DataColumn(
                  label: Text(
                    'Definition',
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
                  if (showTranslation)
                    DataCell(Text(wordPairs[index].translation)),
                  if (showDefinition)
                    // Definitions run long: wrap within a column
                    // instead of stretching the table sideways.
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(wordPairs[index].definition),
                    )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ShareChoice { file, link }

/// Up to three of the kept photos as small stacked thumbnails, the way the
/// shared page's photo button shows them.
class _PhotoStack extends ConsumerStatefulWidget {
  const _PhotoStack({required this.photos});

  final List<SessionSource> photos;

  @override
  ConsumerState<_PhotoStack> createState() => _PhotoStackState();
}

class _PhotoStackState extends ConsumerState<_PhotoStack> {
  static const _size = 40.0;
  static const _turns = [-7.0, 5.0, 0.0];

  late List<Future<Uint8List?>> _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PhotoStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.photos.map((p) => p.id).join(',');
    if (ids != oldWidget.photos.map((p) => p.id).join(',')) _load();
  }

  void _load() {
    final store = ref.read(sourcePhotoStoreProvider);
    _bytes = widget.photos.take(3).map(store.read).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stacked = _bytes.length > 1;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          for (final (i, bytes) in _bytes.indexed)
            Transform.rotate(
              angle: stacked ? _turns[i] * math.pi / 180 : 0,
              child: _thumb(bytes),
            ),
        ],
      ),
    );
  }

  Widget _thumb(Future<Uint8List?> bytes) => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FutureBuilder<Uint8List?>(
            future: bytes,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return data == null
                  ? const SizedBox.expand()
                  : Image.memory(data,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.expand());
            },
          ),
        ),
      );
}
