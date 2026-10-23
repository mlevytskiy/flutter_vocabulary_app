import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/dialogues/dialogue_rules.dart' show afterPublish;
import '../../core/theme/app_theme.dart';
import '../../core/models/collection_name.dart';
import '../../core/models/word_collection.dart';
import '../../core/models/session_source.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/collection_publish_service.dart';
import '../../core/story/word_grouping.dart' show wordsToLearn;
import '../learn/entry/learn_sheet.dart';
import '../../core/story/word_groups_notifier.dart';
import '../../router/routes.dart';
import '../notes/notes_screen.dart';
import '../words/photo_panel/photo_panel.dart';
import '../words/photo_panel/photo_panel_host.dart';
import '../words/photo_panel/photos_with_words.dart';
import '../words/words_notifier.dart';
import 'include_photos.dart';
import 'safe_file_name.dart';
import 'share_formats.dart';
import 'widgets/learn_share_bar.dart';

class WordsTableScreen extends ConsumerStatefulWidget {
  const WordsTableScreen({super.key, this.collectionId});

  /// Null for the current session (the words the input screen is editing);
  /// set when the screen was opened from a History row, in which case the
  /// words are read from the store instead of the notifier (task-10).
  final String? collectionId;

  @override
  ConsumerState<WordsTableScreen> createState() => _WordsTableScreenState();
}

class _WordsTableScreenState extends ConsumerState<WordsTableScreen>
    with PhotoPanelHost<WordsTableScreen> {
  /// True while `POST /sessions` is in flight. Disables the Share button so a
  /// double tap cannot publish twice; the request itself times out (AC-16).
  bool _isPublishing = false;

  /// words-photo-panel: the table's vertical scrolling. The table stays a
  /// table while the photo panel is open (owner, 2026-10-19): a selected
  /// source's rows are highlighted in it and its first row scrolls to the
  /// top. The key sits in the first row's "#" cell, to find the table.
  final ScrollController _tableScroll = ScrollController();
  final GlobalKey _firstCellKey = GlobalKey(debugLabel: 'first table cell');

  /// The table's sources with words, each with its rows as table rows: the
  /// table lists only the filled rows. Set in build.
  List<SourceWithWords> _tableSources = const [];

  /// A source was selected in the half-open panel: the table scrolls its
  /// first row to the top, as on the main screen (spec AC-04), or as near
  /// the top as the table's end allows. Sideways it stays where it is.
  void _onPhotoSelected(String? id) {
    if (id == null) return;
    final source =
        _tableSources.where((p) => p.source.id == id).firstOrNull;
    if (source == null || source.rows.isEmpty) return;
    final cell = _firstCellKey.currentContext?.findRenderObject();
    if (cell == null || !_tableScroll.hasClients) return;
    RenderObject? table = cell;
    while (table != null && table is! RenderTable) {
      table = table.parent;
    }
    if (table is! RenderTable) return;
    // Row 0 of the table is the heading.
    final row = table.getRowBox(source.rows.first + 1);
    final top = RenderAbstractViewport.of(table)
        .getOffsetToReveal(table, 0, rect: row)
        .offset;
    final position = _tableScroll.position;
    _tableScroll.animateTo(
      top.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  /// Notes edits the current collection, so it opens only for that one; a
  /// History collection's panel expands to its large photos instead.
  Future<void> _openNotes(String? id) =>
      NotesRoute(selectedId: id).push<void>(context);

  @override
  void dispose() {
    _tableScroll.dispose();
    super.dispose();
  }

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
      // Group the words quietly when they changed (mnemonic-story AC-03).
      if (!mounted) return;
      ref
          .read(wordGroupsNotifierProvider(widget.collectionId).notifier)
          .ensureGrouped()
          .catchError((_) {});
    });
  }

  Future<void> _shareWords(List<WordPair> wordPairs) async {
    if (wordPairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No words to share')),
      );
      return;
    }

    final format = await showModalBottomSheet<ShareFormat>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final format in ShareFormat.values)
                ListTile(
                  leading: Icon(format == ShareFormat.pdf
                      ? Icons.picture_as_pdf_outlined
                      : format == ShareFormat.csv
                          ? Icons.table_chart_outlined
                          : Icons.insert_drive_file_outlined),
                  title: Text(format.title),
                  subtitle: Text(format.subtitle),
                  onTap: () => Navigator.pop(sheetContext, format),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || format == null) return;

    final origin = _shareOrigin(context);
    final detail = ref.read(wordDetailModeProvider);
    try {
      // Named after the collection, the name the subject (AC-32).
      final made = await makeShareFile(format, wordPairs,
          name: _collectionName(_collection()), detail: detail);

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${made.fileName}';
      await File(filePath).writeAsBytes(made.bytes);

      // Share file
      await Share.shareXFiles(
        [XFile(filePath, mimeType: made.mimeType)],
        subject: made.subject,
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  /// Where the iOS share sheet points. On iOS 26 iPhones present it as a
  /// popover too, and share_plus 7 refuses to share without this rect.
  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Learn (learn-redesign AC-01, AC-03): the Learn sheet; nothing to learn
  /// without a word that has a translation.
  void _learn(List<WordPair> wordPairs) {
    final collection = _collection();
    if (collection == null || wordsToLearn(collection).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add words with a translation to start learning')),
      );
      return;
    }
    showLearnSheet(context, ref,
        collectionId: widget.collectionId,
        collection: collection,
        onSettings: () =>
            LearnSettingsRoute(collectionId: widget.collectionId).push(context),
        onTalk: (split) =>
            TalkRoute(collectionId: widget.collectionId, split: split).push(context));
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
    final collection = _collection();
    final includePhotos =
        ref.read(includePhotosProvider(widget.collectionId)) &&
            linkedPhotos(linkedSources(collection, wordPairs)).isNotEmpty;
    final publishedBefore = collection?.publishedId != null;
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
          // Scrolls only when the warnings do not fit a short screen.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('Share file'),
                  subtitle: const Text('Anki, CSV, PDF, Quizlet or word list'),
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
                // The name goes on the public page (AC-31).
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  subtitle:
                      Text(publicNameWarning(_collectionName(collection))),
                ),
              ],
            ),
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

  Future<void> _shareLink(List<WordPair> wordPairs,
      {required bool includePhotos}) async {
    if (_isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      final collection = _collection();
      final published =
          await ref.read(collectionPublishServiceProvider).publish(wordPairs,
              detail: ref.read(wordDetailModeProvider),
              // Switched off, no photo reaches the page (AC-24); a set
              // always does (AC-15).
              sources: [
                for (final source
                    in collection?.sources ?? const <SessionSource>[])
                  if (includePhotos || source.kind == SourceKind.set) source,
              ],
              publishedId: collection?.publishedId,
              editToken: collection?.editToken,
              dialogues: collection?.dialogues ?? const [],
              title: collection == null ? null : _collectionName(collection));
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
    } on CollectionPublishException catch (e) {
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
  /// The collection's name; one not yet backfilled shows its default name
  /// (AC-03), and with no collection the file falls back to "collection".
  String _collectionName(WordCollection? collection) => collection == null
      ? ''
      : collection.name ?? defaultCollectionName(collection.updatedAt);

  WordCollection? _collection() {
    final collectionId = widget.collectionId;
    return collectionId == null
        ? ref.read(wordsNotifierProvider).valueOrNull
        : ref.read(collectionByIdProvider(collectionId)).valueOrNull;
  }

  /// Asks before making this History session the current one
  /// (edit-session-from-history, AC-02..AC-04, AC-08). Yes replaces the whole
  /// stack with the main screen, so Back leaves the app.
  Future<void> _confirmEdit(String collectionId) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Do you want to edit this list of words?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final switched = await ref
        .read(wordsNotifierProvider.notifier)
        .switchTo(collectionId);
    if (!mounted) return;
    if (switched) {
      const WordsRoute().go(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("This collection can't be opened for editing")),
      );
    }
  }

  /// Keeps the published id and edit token so the next publish overwrites the
  /// same link (ADR-0008). `markShared` also flags the current session; a
  /// History row is written to the store without restamping anything.
  Future<void> _rememberPublished(PublishedCollection published) async {
    final collectionId = widget.collectionId;
    // A History row may be the session the notifier holds: update it there,
    // or its next save would write the old id and token back.
    final current = ref.exists(wordsNotifierProvider)
        ? ref.read(wordsNotifierProvider).valueOrNull
        : null;
    if (collectionId == null || current?.collectionId == collectionId) {
      final notifier = ref.read(wordsNotifierProvider.notifier);
      await notifier.markShared(
          publishedId: published.id, editToken: published.editToken);
      await notifier.markDialoguesPublished(
          {for (final d in published.declaredDialogues) d.id});
      return;
    }
    // The link dialog does not wait for opening the store.
    unawaited(_rememberForHistoryRow(collectionId, published));
  }

  Future<void> _rememberForHistoryRow(
      String collectionId, PublishedCollection published) async {
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final stored = await store.byId(collectionId);
      if (stored == null) return;
      stored
        ..publishedId = published.id
        ..editToken = published.editToken
        ..dialogues = afterPublish(stored.dialogues,
            sent: {for (final d in published.declaredDialogues) d.id});
      await store.put(stored);
      ref.invalidate(collectionByIdProvider(collectionId));
    } catch (_) {
      // The link is out already; missing the token only means the next
      // publish makes a new link instead of overwriting this one.
    }
  }

  Future<void> _showPublishedLinkDialog(PublishedCollection published) {
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
            onPressed: () => Share.share(published.url,
                subject: 'English Vocabulary',
                sharePositionOrigin: _shareOrigin(dialogContext)),
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
      opened =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    final collectionId = widget.collectionId;
    final collection = collectionId == null
        ? ref.watch(wordsNotifierProvider).valueOrNull
        : ref.watch(collectionByIdProvider(collectionId)).valueOrNull;
    // definition-mode: every filled row -- a word plus a translation or a
    // definition -- whatever the mode (spec AC-12); the mode picks columns.
    final wordPairs = filledPairs(collection);
    // words-photo-panel: the switch lives in the Words settings now; watched
    // here so it lasts as long as this screen, as it did in its State.
    ref.watch(includePhotosProvider(collectionId));
    final detailMode = ref.watch(wordDetailModeProvider);
    final showTranslation = detailMode != WordDetailMode.definition;
    final showDefinition = detailMode != WordDetailMode.translation;
    // edit-session-from-history AC-06: no Edit button for the session the main
    // screen is already editing.
    final currentId = ref.exists(wordsNotifierProvider)
        ? ref.watch(wordsNotifierProvider).valueOrNull?.collectionId
        : null;
    final canEdit = collectionId != null && collectionId != currentId;

    // words-photo-panel: the photo panel lists this collection's sources with
    // words, as on the main screen; a vanished selected one is unselected,
    // none left closes it (side-bar-for-main-screen AC-15, AC-21).
    final sourcesProvider = collectionId == null
        ? sourcesWithWordsProvider
        : storedSourcesWithWordsProvider(collectionId);
    ref.listen(sourcesProvider, (_, sources) {
      photoPanel.retain([for (final s in sources) s.source.id]);
    });
    _tableSources = _asTableRows(ref.watch(sourcesProvider), collection);
    final (highlightedRows, highlight) = photoHighlight(_tableSources);
    final highlightColor = (highlight as BoxDecoration?)?.color;

    // Back steps the open photo panel back one stop and never leaves the
    // screen while it is open (spec AC-10). Closed, Back is as before.
    return PopScope(
      canPop: !photoPanel.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) photoPanel.stepBack();
      },
      child: Scaffold(
      // Settings bottom-left, like the main screen's settings button (same
      // size, elevation and colours); Edit, when there is one, stays bottom-right.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: closesOpenPhotoPanel(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              heroTag: null,
              onPressed: () =>
                  WordsSettingsRoute(collectionId: collectionId).push(context),
              tooltip: 'Settings',
              elevation: 8.0,
              shape: const CircleBorder(),
              backgroundColor: AppDecor.of(context).fabAlt,
              foregroundColor: AppDecor.of(context).onFabAlt,
              child: const Icon(Icons.settings),
            ),
            if (canEdit)
              FloatingActionButton(
                heroTag: null,
                onPressed: () => _confirmEdit(collectionId),
                tooltip: 'Edit',
                backgroundColor: AppDecor.of(context).fab,
                foregroundColor: AppDecor.of(context).onFab,
                shape: const CircleBorder(),
                child: const Icon(Icons.edit),
              ),
          ],
        ),
      )),
      appBar: photoPanelGuardedAppBar(LearnShareBar(
        title: 'Words',
        onLearn: () => _learn(wordPairs),
        onShare: _isPublishing ? null : () => _showShareOptions(wordPairs),
        isSharing: _isPublishing,
      )),
      body: wordPairs.isEmpty
          ? Center(
              child: Text(
                'No words added yet',
                style: TextStyle(fontSize: 18, color: AppDecor.of(context).muted),
              ),
            )
          : Stack(
              children: [
                // Open photo panel: a tap or a sideways swipe on the words
                // closes it and does nothing else (AC-06, AC-11). The table
                // stays as it is and still scrolls (owner, 2026-10-19).
                Positioned.fill(
                  child: GestureDetector(
                    onTap: photoPanel.isOpen ? photoPanel.close : null,
                    onHorizontalDragStart:
                        photoPanel.isOpen ? (_) => photoPanel.close() : null,
                    child: _table(
                      wordPairs,
                      showTranslation: showTranslation,
                      showDefinition: showDefinition,
                      highlightFor: (index) => highlightedRows.contains(index)
                          ? highlightColor
                          : null,
                    ),
                  ),
                ),
                // The photo tab and panel paint above the route through an
                // overlay; this child only marks the words' place (ADR-0001).
                Positioned.fill(
                  child: PhotoPanel(
                    controller: photoPanel,
                    // Kept free for the floating-button row (spec AC-01).
                    bottomReserve: 80,
                    scrollController: _tableScroll,
                    onSelected: _onPhotoSelected,
                    collectionId: collectionId,
                    onOpenNotes: collectionId == null || collectionId == currentId
                        ? _openNotes
                        : null,
                    notesPage: collectionId == null || collectionId == currentId
                        ? (id) => NotesScreen(selectedId: id, preview: true)
                        : null,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  /// [sources] with their rows as rows of the table, which lists only the
  /// filled rows of [collection]; a row the table does not list is dropped.
  static List<SourceWithWords> _asTableRows(
      List<SourceWithWords> sources, WordCollection? collection) {
    final tableRow = <int, int>{};
    var n = 0;
    for (final (i, pair)
        in (collection?.words ?? const <WordPair>[]).indexed) {
      if (pair.isFilled) tableRow[i] = n++;
    }
    return [
      for (final s in sources)
        (
          source: s.source,
          rows: [
            for (final r in s.rows)
              if (tableRow[r] != null) tableRow[r]!,
          ],
        ),
    ];
  }

  Widget _table(
    List<WordPair> wordPairs, {
    required bool showTranslation,
    required bool showDefinition,
    required Color? Function(int index) highlightFor,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        controller: _tableScroll,
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
              color: AppDecor.of(context).placeholder,
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
                // words-photo-panel: the selected source's rows.
                color: switch (highlightFor(index)) {
                  final color? => WidgetStatePropertyAll(color),
                  null => null,
                },
                cells: [
                  DataCell(Text('${index + 1}',
                      key: index == 0 ? _firstCellKey : null)),
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
