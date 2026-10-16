import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/collection_name.dart';
import '../../core/models/tag_kind.dart';
import '../../core/providers.dart';
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

/// What the sheet hands back: the name as typed, the description as typed
/// (blank means none) and the tags of each kind.
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
Future<CollectionDetails?> showCollectionDetailsSheet(
  BuildContext context, {
  required DetailsMode mode,
  CollectionDetails? initial,
}) {
  return showModalBottomSheet<CollectionDetails>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Swipe-down is handled by the sheet's own handle so it can ask first.
    enableDrag: false,
    builder: (context) => _DetailsSheet(mode: mode, initial: initial),
  );
}

class _DetailsSheet extends ConsumerStatefulWidget {
  const _DetailsSheet({required this.mode, this.initial});

  final DetailsMode mode;
  final CollectionDetails? initial;

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

  bool get _nameOk => collectionNameProblem(_name.text) == null;
  bool get _descriptionOk =>
      _description.text.runes.length <= maxDescriptionLength;

  void _submit() {
    if (!_nameOk || !_descriptionOk) return;
    Navigator.of(context).pop<CollectionDetails>((
      name: _name.text,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameError = (_nameTouched || _name.text.isNotEmpty) && !_nameOk
        ? nameProblemMessage
        : null;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askDiscard();
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                child: Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Text(widget.mode.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('details-name'),
                controller: _name,
                autofocus: widget.mode == DetailsMode.create,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _nameTouched = true,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: nameError,
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
                  border: const OutlineInputBorder(),
                  errorText: _descriptionOk ? null : descriptionProblemMessage,
                ),
              ),
              const SizedBox(height: 12),
              _tagField(TagKind.origin, _origin,
                  (tags) => setState(() => _origin = tags)),
              const SizedBox(height: 12),
              _tagField(TagKind.topic, _topic,
                  (tags) => setState(() => _topic = tags)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('details-confirm'),
                  onPressed: _nameOk && _descriptionOk ? _submit : null,
                  child: Text(widget.mode.confirmLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
