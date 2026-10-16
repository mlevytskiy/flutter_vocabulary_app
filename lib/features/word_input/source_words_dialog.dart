part of 'word_input_screen.dart';

/// Shows the words of the source [sourceId] as the main screen shows its
/// rows with the photo panel closed, with every action they have there, and
/// a dashed "+ Add a word" button that adds a word to that source (Notes,
/// notes-editing, owner 2026-10-15). Edits go straight into the current
/// session; the main screen builds its rows again when Notes closes.
Future<void> showSourceWordsDialog(
  BuildContext context, {
  required String sourceId,
  required String title,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => SourceWordsDialog(sourceId: sourceId, title: title),
    );

class SourceWordsDialog extends ConsumerStatefulWidget {
  const SourceWordsDialog({
    super.key,
    required this.sourceId,
    required this.title,
  });

  final String sourceId;
  final String title;

  static const addWordKey = Key('source-words-add');
  static const closeKey = Key('source-words-close');

  @override
  ConsumerState<SourceWordsDialog> createState() => _SourceWordsDialogState();
}

class _SourceWordsDialogState extends ConsumerState<SourceWordsDialog>
    with _WordRows<SourceWordsDialog> {
  @override
  final List<WordPair> _wordPairs = [];

  /// Where each row on screen is in the session's words.
  final List<int> _rows = [];

  late final WordInputNotifier _notifier;
  late final PronunciationService _pronunciation;

  /// The words as they were when the dialog opened, to tell whether the main
  /// screen must build its rows again.
  late final String _wordsBefore;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(wordInputNotifierProvider.notifier);
    _pronunciation = ref.read(pronunciationServiceProvider);
    final words =
        ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const [];
    _wordsBefore = _wordsKey(words);
    _loadRows();
  }

  /// Builds the rows from the session: every word of the source, a blank
  /// one added here too. Run again after a removal, because each row's
  /// field listeners keep the position they were made for.
  void _loadRows() {
    final old = <ChangeNotifier>[
      ..._wordControllers,
      ..._translationControllers,
      ..._definitionControllers,
      ..._wordFocusNodes,
      ..._translationFocusNodes,
      ..._definitionFocusNodes,
    ];
    // Disposed once the fields have their new ones.
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final o in old) {
          o.dispose();
        }
      });
    }
    for (final list in <List<dynamic>>[
      _wordPairs, _rows, _wordControllers, _translationControllers,
      _isLoadingTranslation, _isLoadingWordTranslation, _translationOptions,
      _optionsWord, _translationMarkedFilled, _wordMarkedFilled,
      _wordFocusNodes, _translationFocusNodes, _definitionControllers,
      _definitionFocusNodes, _isLoadingDefinition, _definitionMarkedFilled,
      _definitionSenses, _sensesWord,
    ]) {
      list.clear();
    }
    final words =
        ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const [];
    for (var i = 0; i < words.length; i++) {
      if (words[i].sourceId != widget.sourceId) continue;
      _rows.add(i);
      _wordPairs.add(words[i].copy());
      final at = _wordPairs.length - 1;
      _addControllersForIndex(at);
      // The row's extras, as the main screen restores them.
      final pair = _wordPairs[at];
      _translationOptions[at] = pair.translationOptions;
      _optionsWord[at] =
          pair.translationOptions != null ? pair.word.trim() : null;
      _wordMarkedFilled[at] = pair.wordMarkedFilled;
      _translationMarkedFilled[at] = pair.translationMarkedFilled;
      final senses = DefinitionResult.decodeSenses(pair.definitionOptionsJson);
      _definitionSenses[at] = senses.isEmpty ? null : senses;
      _sensesWord[at] = senses.isEmpty ? null : pair.word.trim();
      _definitionMarkedFilled[at] = pair.definitionMarkedFilled;
    }
    // A row's popup keeps the controller it was first given (see the main
    // screen's _restoreFromStore): only the ones past the end go.
    _popupControllers.removeWhere((i, _) => i >= _wordPairs.length);
    _definitionPopupControllers.removeWhere((i, _) => i >= _wordPairs.length);
  }

  static String _wordsKey(List<WordPair> words) => [
        for (final w in words)
          '${w.word}\u0001${w.translation}\u0001${w.definition}\u0001${w.sourceId}',
      ].join('\u0002');

  @override
  int _storeIndex(int index) => _rows[index];

  @override
  bool get _keepsFirstRow => false;

  /// The dialog adds a row only from its "+ Add a word" button.
  @override
  void _checkAndAddNewPair() {}

  @override
  void _onRowRemoved(int index, int storeIndex) => _loadRows();

  /// A blank row for this source, right after its last word (before the
  /// main screen's blank row when the source has none left).
  void _addWord() {
    final words =
        ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const [];
    final at = _rows.isNotEmpty
        ? _rows.last + 1
        : words.length - (words.isNotEmpty && words.last.isEmpty ? 1 : 0);
    final pair = WordPair(word: '', translation: '', sourceId: widget.sourceId);
    _notifier.insertAt(at, pair);
    setState(() {
      _wordPairs.add(pair.copy());
      _rows.add(at);
      _addControllersForIndex(_wordPairs.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _wordFocusNodes.last.requestFocus();
    });
  }

  /// Rows left blank are taken out again, and the main screen is
  /// told when the words changed.
  void _onClose() {
    for (var i = _wordPairs.length - 1; i >= 0; i--) {
      if (_wordPairs[i].isEmpty) _notifier.removeAt(_rows[i]);
    }
    final words =
        ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const [];
    if (_wordsKey(words) != _wordsBefore) _notifier.markEditedElsewhere();
  }

  @override
  void dispose() {
    _pronunciation.stop();
    for (final c in [
      ..._wordControllers,
      ..._translationControllers,
      ..._definitionControllers,
    ]) {
      c.dispose();
    }
    for (final n in [
      ..._wordFocusNodes,
      ..._translationFocusNodes,
      ..._definitionFocusNodes,
    ]) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailMode = ref.watch(wordDetailModeProvider);
    final theme = Theme.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _onClose();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        clipBehavior: Clip.antiAlias,
        // Its own messenger, so a translation error shows inside the dialog.
        child: ScaffoldMessenger(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 4, 0),
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
                      IconButton(
                        key: SourceWordsDialog.closeKey,
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      for (var i = 0; i < _wordPairs.length; i++)
                        _wordRowItem(i,
                            isDragMode: false, detailMode: detailMode),
                      const SizedBox(height: 8),
                      DashedAddButton(
                        key: SourceWordsDialog.addWordKey,
                        label: '+ Add a word',
                        onPressed: _addWord,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
