import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session_source.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../word_input/photo_panel/photo_preview.dart';
import '../word_input/photo_panel/photos_with_words.dart';
import '../word_input/photo_panel/source_hero.dart';
import '../word_input/photo_panel/source_tile.dart';
import '../word_input/widgets/word_row_morph.dart';
import '../word_input/word_input_notifier.dart';
import '../word_input/word_input_screen.dart' show showSourceWordsDialog;
import '../../router/routes.dart';
import 'photo_viewer_screen.dart';
import 'tag_editor.dart';
import 'tag_suggestions.dart';

/// Notes (owner, 2026-10-15): opened from the half-open photo panel's expand
/// control. One pager per source the panel lists, in the panel's order. Each
/// pager starts on the source's picture; to the right are its words, one
/// line each as on the main screen with the panel open; to the left its
/// note — a title, a description, links and tags, kept with the session
/// (notes-editing, owner 2026-10-15). Above the list are the session's own
/// tags. Tapping the picture opens it full screen, and a pinch zooms it in
/// place; tapping the words opens them as on the main screen.
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.selectedId, this.preview = false});

  /// The source selected in the panel; the list starts with it in view.
  final String? selectedId;

  /// Drawn inside the photo panel while a drag widens it into Notes: the
  /// same page, with the back arrow the pushed page will have.
  final bool preview;

  static Key itemKey(String id) => ValueKey('notes-item-$id');
  static Key pagerKey(String id) => ValueKey('notes-pager-$id');
  static Key pictureKey(String id) => ValueKey('notes-picture-$id');
  static Key wordsKey(String id) => ValueKey('notes-words-$id');
  static const titleKey = Key('notes-title');
  static const descriptionKey = Key('notes-description');

  /// The first link field; [linkFieldKey] names each.
  static const linkKey = Key('notes-link');
  static Key linkFieldKey(int i) => i == 0 ? linkKey : ValueKey('notes-link-$i');
  static const addLinkKey = Key('notes-add-link');
  static const tagFieldKey = Key('notes-tag-field');
  static const sessionTagFieldKey = Key('notes-session-tag-field');

  /// One item's height, its title and spacing included.
  static const itemExtent = 300.0;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  ScrollController? _scroll;

  /// A picture is being pinched or is zoomed in: the list stands still.
  bool _zooming = false;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesWithWordsProvider);
    final words = ref.watch(wordInputNotifierProvider).valueOrNull?.words ??
        const <WordPair>[];
    final mode = ref.watch(wordDetailModeProvider);
    final preloader = ref.watch(photoPreloaderProvider);
    final sessionTags =
        ref.watch(wordInputNotifierProvider).valueOrNull?.tags ?? const [];
    final notifier = ref.read(wordInputNotifierProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: widget.preview ? BackButton(onPressed: () {}) : null,
        title: const Text('Notes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The whole session's tags (notes-editing).
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F2FF),
              border: Border(bottom: BorderSide(color: Color(0x33954EF3))),
            ),
            child: TagEditor(
              fieldKey: NotesScreen.sessionTagFieldKey,
              label: 'Session tags',
              tags: sessionTags,
              suggestions: ref.watch(sessionTagSuggestionsProvider),
              onChanged: notifier.setSessionTags,
            ),
          ),
          Expanded(
            child: sources.isEmpty
                ? const Center(
                    child: Text(
                      'No photos yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : LayoutBuilder(builder: (context, box) {
                    // Starts with the selected source in view, within the
                    // list's extent, so the hero lands where the item stays.
                    final at = sources
                        .indexWhere((s) => s.source.id == widget.selectedId);
                    final end =
                        sources.length * NotesScreen.itemExtent - box.maxHeight;
                    _scroll ??= ScrollController(
                      initialScrollOffset:
                          (NotesScreen.itemExtent * (at < 0 ? 0 : at))
                              .clamp(0.0, end < 0 ? 0.0 : end),
                    );
                    return ListView.builder(
                      controller: _scroll,
                      physics: _zooming
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemExtent: NotesScreen.itemExtent,
                      itemCount: sources.length,
                      itemBuilder: (context, i) => _NoteItem(
                        key: NotesScreen.itemKey(sources[i].source.id),
                        item: sources[i],
                        title: _title(sources, i),
                        preloader: preloader,
                        interactive: !widget.preview,
                        onZooming: (zooming) {
                          if (zooming != _zooming) {
                            setState(() => _zooming = zooming);
                          }
                        },
                        lines: [
                          for (final r in sources[i].rows)
                            if (r < words.length)
                              (
                                index: r,
                                word: words[r].word,
                                detail: compactDetail(
                                  mode: mode,
                                  translation: words[r].translation,
                                  definition: words[r].definition,
                                ),
                              ),
                        ],
                      ),
                    );
                  }),
          ),
        ],
      ),
    );
  }

  /// The note's title when it has one; otherwise a photo is counted among
  /// the photos, and a set or a film is named.
  static String _title(List<SourceWithWords> sources, int i) {
    final source = sources[i].source;
    final title = source.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    if (source.kind != SourceKind.photo) return source.name ?? '';
    final n = sources.take(i + 1).where((s) => s.isPhoto).length;
    return 'Photo $n';
  }
}

typedef _Line = ({int index, String word, String detail});

/// One source: its title and word count, then its three pages — note,
/// picture, words — with the neighbours peeking in at the sides.
class _NoteItem extends ConsumerStatefulWidget {
  const _NoteItem({
    super.key,
    required this.item,
    required this.title,
    required this.lines,
    required this.preloader,
    required this.interactive,
    required this.onZooming,
  });

  final SourceWithWords item;
  final String title;
  final List<_Line> lines;
  final PhotoPreloader preloader;

  /// False while drawn inside the photo panel as a preview.
  final bool interactive;

  /// The picture is pinched or zoomed in (true), or back at its size.
  final ValueChanged<bool> onZooming;

  @override
  ConsumerState<_NoteItem> createState() => _NoteItemState();
}

class _NoteItemState extends ConsumerState<_NoteItem>
    with AutomaticKeepAliveClientMixin {
  static const _picturePage = 1;

  final _pages =
      PageController(initialPage: _picturePage, viewportFraction: notesPageFraction);
  late final TextEditingController _title;
  late final TextEditingController _description;
  final _links = <TextEditingController>[];

  /// The picture is pinched or zoomed in: the pager stands still.
  bool _zooming = false;

  /// The viewer's decode of the photo, started when a finger touches it.
  Future<void>? _viewerReady;

  @override
  bool get wantKeepAlive => true;

  String get _id => widget.item.source.id;

  WordInputNotifier get _notifier =>
      ref.read(wordInputNotifierProvider.notifier);

  @override
  void initState() {
    super.initState();
    final source = widget.item.source;
    _title = TextEditingController(text: source.title ?? '');
    _description = TextEditingController(text: source.description ?? '');
    // One empty field when there is no link yet.
    for (final link in source.links.isEmpty ? [''] : source.links) {
      _links.add(TextEditingController(text: link));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    _title.dispose();
    _description.dispose();
    for (final c in _links) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveLinks() => _notifier.updateSourceNote(_id, links: [
        for (final c in _links)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ]);

  void _addLink() => setState(() => _links.add(TextEditingController()));

  void _removeLink(int i) {
    setState(() {
      final removed = _links.removeAt(i);
      // Disposed after the frame, once its field is gone.
      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      if (_links.isEmpty) _links.add(TextEditingController());
    });
    _saveLinks();
  }

  void _setZooming(bool zooming) {
    if (zooming == _zooming) return;
    setState(() => _zooming = zooming);
    widget.onZooming(zooming);
  }

  /// The page under the middle is full size; its neighbours a little smaller.
  Widget _scaled(int index, Widget child) => AnimatedBuilder(
        animation: _pages,
        builder: (context, child) {
          final page = _pages.hasClients && _pages.position.hasContentDimensions
              ? _pages.page ?? _picturePage.toDouble()
              : _picturePage.toDouble();
          final distance = (page - index).abs().clamp(0.0, 1.0);
          return Transform.scale(scale: 1 - 0.08 * distance, child: child);
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final count = widget.lines.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                count == 1 ? '1 word' : '$count words',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            key: NotesScreen.pagerKey(_id),
            controller: _pages,
            physics: _zooming ? const NeverScrollableScrollPhysics() : null,
            children: [
              _scaled(0, _page(context, _note(context))),
              _scaled(1, _picture(context)),
              _scaled(2, _page(context, _words(context))),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _page(BuildContext context, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33954EF3)),
          ),
          child:
              ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
        ),
      );

  Widget _picture(BuildContext context) {
    final source = widget.item.source;
    final picture = SourceHero(
      id: source.id,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // Decoded at this width by the panel ahead, so it is drawn in the
        // first frame.
        child: widget.item.isPhoto
            ? PhotoPreview(
                source: source,
                width: notesPictureWidth(MediaQuery.sizeOf(context).width),
                preloader: widget.preloader,
              )
            : SourceTile(source: source, wordCount: widget.item.rows.length),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: widget.item.isPhoto && widget.interactive
          ? _ZoomablePicture(
              key: NotesScreen.pictureKey(source.id),
              onZooming: _setZooming,
              // The large decode starts at the touch and is done before
              // the viewer opens, so nothing blinks.
              onPress: () => _viewerReady = PhotoViewerScreen.precache(
                  context, source, widget.preloader),
              onTap: () async {
                await (_viewerReady ??= PhotoViewerScreen.precache(
                    context, source, widget.preloader));
                _viewerReady = null;
                if (context.mounted) {
                  await PhotoViewerRoute(sourceId: source.id).push<void>(context);
                }
              },
              child: picture,
            )
          : picture,
    );
  }

  /// Tapped, the words open as on the main screen, to edit and add to.
  Widget _words(BuildContext context) {
    final list = widget.lines.isEmpty
        ? const Center(
            child: Text('No words', style: TextStyle(color: Colors.grey)))
        : ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            children: [
              for (final line in widget.lines)
                CompactWordLine(
                  index: line.index,
                  word: line.word,
                  detail: line.detail,
                ),
            ],
          );
    if (!widget.interactive) return list;
    return GestureDetector(
      key: NotesScreen.wordsKey(_id),
      behavior: HitTestBehavior.opaque,
      onTap: () => showSourceWordsDialog(context,
          sourceId: _id, title: widget.title),
      child: list,
    );
  }

  /// The note: a title, a description, links and tags, each change kept.
  Widget _note(BuildContext context) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            key: NotesScreen.titleKey,
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) => _notifier.updateSourceNote(_id, title: text),
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: NotesScreen.descriptionKey,
            controller: _description,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (text) =>
                _notifier.updateSourceNote(_id, description: text),
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          for (var i = 0; i < _links.length; i++) ...[
            const SizedBox(height: 10),
            TextField(
              key: NotesScreen.linkFieldKey(i),
              controller: _links[i],
              keyboardType: TextInputType.url,
              onChanged: (_) => _saveLinks(),
              decoration: InputDecoration(
                labelText: 'Link',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _links.length > 1 || _links[i].text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Remove link',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeLink(i),
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: NotesScreen.addLinkKey,
              onPressed: _addLink,
              icon: const Icon(Icons.add_link, size: 18),
              label: const Text('Add link'),
            ),
          ),
          TagEditor(
            fieldKey: NotesScreen.tagFieldKey,
            tags: widget.item.source.tags,
            suggestions: ref.watch(sourceTagSuggestionsProvider),
            onChanged: (tags) => _notifier.updateSourceNote(_id, tags: tags),
          ),
        ],
      );
}

/// A picture on the Notes pager that a pinch zooms in place. While two
/// fingers are down or it is zoomed in, the pager and the list stand still
/// and one finger pans; pinched back to its size, they move again. A tap
/// opens it full screen.
class _ZoomablePicture extends StatefulWidget {
  const _ZoomablePicture({
    super.key,
    required this.child,
    required this.onZooming,
    required this.onPress,
    required this.onTap,
  });

  final Widget child;
  final ValueChanged<bool> onZooming;

  /// A finger touched the picture.
  final VoidCallback onPress;
  final VoidCallback onTap;

  @override
  State<_ZoomablePicture> createState() => _ZoomablePictureState();
}

class _ZoomablePictureState extends State<_ZoomablePicture> {
  final _transform = TransformationController();
  int _pointers = 0;

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _report() => widget.onZooming(_pointers >= 2 || _zoomed);

  void _pointerUp() {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    // Pinched back to its size: straighten it out.
    if (!_zoomed) _transform.value = Matrix4.identity();
    setState(() {});
    _report();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) {
          if (_pointers == 0) widget.onPress();
          _pointers++;
          _report();
        },
        onPointerUp: (_) => _pointerUp(),
        onPointerCancel: (_) => _pointerUp(),
        child: GestureDetector(
          onTap: widget.onTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 5,
            // One finger moves the pager unless the picture is zoomed in.
            panEnabled: _zoomed,
            onInteractionEnd: (_) => setState(() {}),
            child: widget.child,
          ),
        ),
      );
}
