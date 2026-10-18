import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/collection_name.dart';
import '../../core/models/name_kind.dart'
    show minWordsForAutoDescription, minWordsForAutoName;
import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
import '../../core/theme/app_decor.dart';
import '../../core/services/tag_rules.dart';
import '../tags/tag_suggestions.dart';
import '../tags/typed_tag_field.dart';
import 'name_dialog.dart' show nameProblemMessage;

/// Whether the Collection details sheet makes a collection or edits one
/// (collection-tags SCR-02).
enum DetailsMode {
  create('New collection', 'Create'),
  edit('Collection details', 'Save');

  const DetailsMode(this.title, this.confirmLabel);

  final String title;
  final String confirmLabel;
}

/// What the sheet hands back: the name as typed (blank means "let AI name
/// it" when the sheet left the name to AI, collection-naming), the description as
/// typed (blank means none) and the tags of each kind.
typedef CollectionDetails = ({
  String name,
  String description,
  List<String> origin,
  List<String> topic,
});

/// The most characters a description may hold (AC-03).
const maxDescriptionLength = 500;

const descriptionProblemMessage =
    'A description is at most $maxDescriptionLength characters';

/// Opens the Collection details sheet (SCR-02). Resolves with the details on
/// Create/Save, or null when it was dismissed. A dismiss after a change asks
/// "Discard changes?" first (AC-36, SCR-03); with no change it closes silently.
///
/// In [DetailsMode.edit], [aiNameUntil] is the name a collection nobody named
/// shows until AI names it ("Vocabulary 1"), and [aiDescription] says nobody
/// wrote its description yet: the field then starts empty and shows the same
/// AI hint and note as New collection (owner, 2026-10-18).
Future<CollectionDetails?> showCollectionDetailsSheet(
  BuildContext context, {
  required DetailsMode mode,
  CollectionDetails? initial,
  String? aiNameUntil,
  bool aiDescription = false,
}) {
  return showModalBottomSheet<CollectionDetails>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Swipe-down is handled by the sheet's own handle so it can ask first.
    enableDrag: false,
    builder: (context) => _DetailsSheet(
      mode: mode,
      initial: initial,
      aiNameUntil: mode == DetailsMode.create
          ? undefinedCollectionName
          : aiNameUntil,
      aiDescription: mode == DetailsMode.create || aiDescription,
    ),
  );
}

class _DetailsSheet extends ConsumerStatefulWidget {
  const _DetailsSheet({
    required this.mode,
    this.initial,
    this.aiNameUntil,
    this.aiDescription = false,
  });

  final DetailsMode mode;
  final CollectionDetails? initial;
  final String? aiNameUntil;
  final bool aiDescription;

  @override
  ConsumerState<_DetailsSheet> createState() => _DetailsSheetState();
}

class _DetailsSheetState extends ConsumerState<_DetailsSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late List<String> _origin = [...?widget.initial?.origin];
  late List<String> _topic = [...?widget.initial?.topic];
  bool _nameTouched = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _changed {
    final i = widget.initial;
    return _name.text != (i?.name ?? '') ||
        _description.text != (i?.description ?? '') ||
        !_same(_origin, i?.origin ?? const []) ||
        !_same(_topic, i?.topic ?? const []);
  }

  static bool _same(List<String> a, List<String> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// A collection nobody named may keep a blank name: AI names it once it
  /// has [minWordsForAutoName] words (collection-naming, owner 2026-10-18).
  bool get _aiName => widget.aiNameUntil != null;
  bool get _nameLeftToAi => _aiName && _name.text.trim().isEmpty;

  /// A description nobody wrote is left to AI too, from
  /// [minWordsForAutoDescription] words on (owner, 2026-10-18).
  bool get _descriptionLeftToAi =>
      widget.aiDescription && _description.text.trim().isEmpty;
  bool get _nameOk =>
      _nameLeftToAi || collectionNameProblem(_name.text) == null;
  bool get _descriptionOk =>
      _description.text.runes.length <= maxDescriptionLength;

  void _submit() {
    if (!_nameOk || !_descriptionOk) return;
    Navigator.of(context).pop<CollectionDetails>((
      name: _nameLeftToAi ? '' : _name.text,
      description: _description.text,
      origin: _origin,
      topic: _topic,
    ));
  }

  Future<void> _askDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  /// Swipe on the handle: closes silently, or asks when something changed.
  void _requestClose() {
    if (_changed) {
      _askDiscard();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _tagField(
      TagKind kind, List<String> tags, ValueChanged<List<String>> onChanged) {
    final suggestions = ref.watch(tagSuggestionsProvider(kind));
    final library = ref.watch(tagLibraryProvider).valueOrNull ?? const [];
    return TypedTagField(
      kind: kind,
      tags: tags,
      suggestions: suggestions,
      onChanged: onChanged,
      onForget: (tag) async {
        final store = await ref.read(collectionStoreProvider.future);
        await store.forgetTag(kind, tag);
      },
      knownSpellings: [
        for (final e in library)
          if (e.kind == kind) e.text,
        ...presetsFor(kind),
      ],
      fieldKey: ValueKey('details-${kind.name}-field'),
      startInEditMode: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final create = widget.mode == DetailsMode.create;
    // The AI hints are quieter than an ordinary hint (owner, 2026-10-18).
    final aiHintStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context)
            .colorScheme
            .onSurfaceVariant
            .withValues(alpha: 0.45));
    final nameError = (_nameTouched || _name.text.isNotEmpty) && !_nameOk
        ? nameProblemMessage
        : null;
    final scheme = Theme.of(context).colorScheme;
    final ai = AppDecor.of(context).aiAccent;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askDiscard();
      },
      // Header, the fields scrolling between, and the action bar pinned at
      // the bottom, so Create stays just above the keyboard (owner,
      // 2026-10-18).
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: const Key('details-handle'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 300) _requestClose();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(widget.mode.title,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('details-name'),
                      controller: _name,
                      autofocus: create,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _nameTouched = true,
                      decoration: InputDecoration(
                        labelText: _aiName ? 'Name (optional)' : 'Name',
                        hintText:
                            _aiName ? 'Leave empty to let AI name it' : null,
                        hintStyle: aiHintStyle,
                        border: const OutlineInputBorder(),
                        errorText: nameError,
                        helper: _nameLeftToAi
                            ? _AiHelper(
                                key: const Key('details-ai-name-note'),
                                color: ai,
                                text: 'AI names it at $minWordsForAutoName '
                                    'words. Until then it is '
                                    '"${widget.aiNameUntil}".',
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('details-description'),
                      controller: _description,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: maxDescriptionLength,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: widget.aiDescription
                            ? 'Leave empty to let AI write it'
                            : null,
                        hintStyle: aiHintStyle,
                        border: const OutlineInputBorder(),
                        errorText:
                            _descriptionOk ? null : descriptionProblemMessage,
                        // On the counter's line, left of "0/500".
                        helper: _descriptionLeftToAi
                            ? _AiHelper(
                                key: const Key('details-ai-description-note'),
                                color: ai,
                                text: 'AI writes it at '
                                    '$minWordsForAutoDescription words',
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _tagField(TagKind.origin, _origin,
                        (tags) => setState(() => _origin = tags)),
                    const SizedBox(height: 12),
                    _tagField(TagKind.topic, _topic,
                        (tags) => setState(() => _topic = tags)),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: FilledButton(
                  key: const Key('details-confirm'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: _nameOk && _descriptionOk ? _submit : null,
                  child: Text(widget.mode.confirmLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The helper line of one of New collection's empty fields: AI will fill it
/// from the collection's words (collection-naming). In the theme's
/// [AppDecor.aiAccent], with no box, so it is not mistaken for a tag box.
class _AiHelper extends StatelessWidget {
  const _AiHelper({super.key, required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
