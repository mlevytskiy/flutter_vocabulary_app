import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/MyCustomPopupMenuController.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../core/theme/app_theme.dart';

import '../../core/models/collection_name.dart';
import '../../core/models/definition_result.dart';
import '../../core/models/name_kind.dart';
import '../../core/models/session_source.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/vocab_word.dart';
import '../../core/models/word_origin.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/pronunciation_service.dart';
import '../../core/services/vocab_photo_service.dart';
import '../../router/routes.dart';
import '../app_menu/app_drawer.dart';
import '../collections/collection_details_sheet.dart';
import '../notes/notes_screen.dart';
import 'collection_tag_line.dart';
import 'lightning_rules.dart';
import 'photo_panel/looks/look_a.dart';
import 'photo_panel/photo_panel.dart';
import 'photo_panel/photo_panel_host.dart';
import 'photo_panel/photos_with_words.dart';
import 'photo_panel/row_jump.dart';
import 'quizlet_import_flow.dart';
import 'subtitle_import_flow.dart';
import 'widgets/photo_source_dialog.dart';
import 'widgets/quizlet_progress_dialog.dart';
import 'widgets/vocab_result_dialog.dart';
import 'widgets/collection_title.dart';
import 'widgets/words_speed_dial.dart';
import 'widgets/word_row_item.dart';
import 'widgets/anchored_scroll_controller.dart';
import 'widgets/dashed_add_button.dart';
import 'widgets/word_row_morph.dart';
import 'widgets/still_body.dart';
import 'words_notifier.dart';

part 'source_words_dialog.dart';
part 'word_rows.dart';

/// Cap on how many marked words one photo may contribute. Not a quota: the
/// Worker returns only the words the photo shows as marked, and this bounds a
/// runaway response (a page scribbled over end to end) instead of filling the
/// list. `docs/idea-brief.md` puts a session at 5-10 words, so 20 leaves room
/// for a generous session while keeping the result dialog scannable; over the
/// cap the Worker keeps the first 20 in reading order (D2 in docs/roadmap.md).
const int _photoWordCap = 20;

/// A gallery photo the picker or the scaler could not use
/// (photo-from-gallery AC-07, AC-08).
const String _galleryPhotoUnusable =
    'The photo from the gallery could not be used. Try another one.';

/// One photo word as a word row (definition-mode T9). The photo analysis's
/// context description is the row's definition in every mode -- the mode only
/// decides what is shown -- and it no longer stands in for a missing
/// translation (spec AC-09, AC-10). Pure: the photo path makes no dictionary
/// lookups. [sourceId] links the row to the photo it came from, when the app
/// kept that photo (good-looking-web T17, AC-25).
WordPair wordPairFromPhoto(VocabWord w, {String? sourceId}) {
  final translation = w.translation ?? '';
  final definition = w.description ?? '';
  return WordPair(
    word: w.word,
    translation: translation,
    definition: definition,
    wordMarkedFilled: w.word.isNotEmpty,
    translationMarkedFilled: translation.isNotEmpty,
    definitionMarkedFilled: definition.isNotEmpty,
    sourceId: sourceId,
  );
}

/// One word of a photo analysis as a word row (word-context AC-02, AC-10):
/// [wordPairFromPhoto] with the image origin and the word's context, a line
/// of the photo (`source`) or one the AI wrote (`ai`); no context, no kind.
WordPair wordPairFromPhotoAnalysis(VocabWord w, {String? sourceId}) {
  final pair = wordPairFromPhoto(w, sourceId: sourceId);
  final context = (w.context ?? '').trim();
  pair.origin.typeOfSource = SourceType.image;
  pair.context = context;
  pair.contextKind = context.isEmpty
      ? ContextKind.none
      : w.contextSource == 'ai'
          ? ContextKind.ai
          : ContextKind.source;
  return pair;
}

WordPair _sameRow(WordPair row) => row;

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key, this.quizletDriverFactory});

  /// Stands in for the Quizlet web view in tests; null in the app.
  @visibleForTesting
  final QuizletPageDriverFactory? quizletDriverFactory;

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen>
    with
        WidgetsBindingObserver,
        PhotoPanelHost<WordsScreen>,
        SingleTickerProviderStateMixin,
        _WordRows<WordsScreen> {
  @override
  final List<WordPair> _wordPairs = [
    WordPair(word: '', translation: ''),
  ];

  bool _isAnalyzingPhoto = false;

  /// side-bar-for-main-screen: the word list's scroll position (both the
  /// plain and the drag-mode list) and one key per row index, so the list can
  /// jump to a photo's first row (spec AC-04). Keyed by index like the row's
  /// former `ValueKey(index)`, so row identity is unchanged. While the rows
  /// morph with the photo panel it keeps the top row in place.
  final AnchoredScrollController _listScroll = AnchoredScrollController();
  final List<GlobalKey> _rowKeys = [];

  GlobalKey _rowKey(int index) {
    while (_rowKeys.length <= index) {
      _rowKeys.add(GlobalKey(debugLabel: 'word row ${_rowKeys.length}'));
    }
    return _rowKeys[index];
  }

  /// Row [index]'s key, or null past the last row (for `jumpToRow`).
  GlobalKey? _rowKeyOrNull(int index) =>
      index < _wordPairs.length ? _rowKey(index) : null;

  /// The drawer is open: the photo tab hides behind it (ADR-0001).
  bool _drawerOpen = false;

  /// Holds the body as one picture while the drawer is on screen, so a frame
  /// of its slide does not draw Aurora's row blurs again (Android; StillBody).
  final _bodyStill = SnapshotController();

  /// Kept free at the end of a row's one line: the half-open panel covers the
  /// list's right side past its 16 px padding. Set in build from the look.
  double _compactEndInset = 0;

  /// The rows morph while the panel is between closed and half-open; the
  /// list keeps the row on top in place from the first frame of a move until
  /// the panel rests (or the list is scrolled by hand).
  bool _rowsResting = true;
  void _onPhotoPanelOpenness() {
    final t = photoPanel.openness.value;
    final resting = t <= 0 || t >= 0.5;
    if (resting == _rowsResting) return;
    _rowsResting = resting;
    if (resting) {
      _listScroll.release();
    } else {
      _listScroll.holdTopItem();
    }
  }

  /// A photo or a set was selected in the half-open panel: the list scrolls
  /// its first row in the list's current order to the top (spec AC-04,
  /// AC-21; owner, 2026-10-15). Unselecting never scrolls (spec AC-05).
  void _onPhotoSelected(String? id) {
    if (id == null) return;
    final photo = ref
        .read(sourcesWithWordsProvider)
        .where((p) => p.source.id == id)
        .firstOrNull;
    if (photo == null || photo.rows.isEmpty) return;
    jumpToRow(_listScroll, photo.rows.first, _rowKeyOrNull);
  }
  bool _isRecoveringLostPhoto = false;

  /// Which session the rows on screen were built from. Tracked as an id rather
  /// than a bool because a resume can swap one session for another and the screen
  /// has to rebuild its rows for the second one too.
  String? _restoredCollectionId;

  /// Read once in initState: dispose() may not touch `ref` (Riverpod forbids
  /// it once the element is torn down), yet it still has to stop speech.
  late final PronunciationService _pronunciation;

  /// 0 with no collection tags, 1 with some: drives the tag line's height so
  /// the app bar grows and shrinks over 200 ms instead of jumping (owner V8).
  late final AnimationController _tagLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(() {
      if (mounted) setState(() {});
    });
  bool? _tagLineOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    photoPanel.openness.addListener(_onPhotoPanelOpenness);
    _pronunciation = ref.read(pronunciationServiceProvider);
    // No field takes focus here: the screen opens without the keyboard
    // (owner, 2026-10-18).
    _addControllersForIndex(0);
    _pollForLostPhoto();
  }

  /// words-photo-panel: Notes can also be opened from the Words screen above
  /// this one. Once this screen is on top again, its rows are built again
  /// from the collection if Notes changed its words, as after its own Notes.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The side menu's `go` disposes this screen; coming back builds a new
    // State while the kept-alive collection is already loaded, so the
    // `ref.listen` in build() never fires. Build the rows after the first
    // frame instead (the restore writes to the notifier, which a lifecycle
    // method may not).
    if (_restoredCollectionId == null) {
      final collection = ref.read(wordsProvider).value;
      if (collection != null) {
        _restoredCollectionId = collection.collectionId;
        if (collection.words.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restoreFromStore(collection.words);
          });
        }
      }
      return;
    }
    if (
        ModalRoute.isCurrentOf(context) != true) {
      return;
    }
    final notifier = ref.read(wordsProvider.notifier);
    final collection = ref.read(wordsProvider).value;
    if (collection == null || !notifier.takeEditedElsewhere()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreFromStore(collection.words);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Android can kill our process while the system camera app is in the
    // foreground (verified in logcat: the app comes back with a new PID), and
    // the pending pickImage() future dies with it — the photo is taken, but
    // nothing happens when we return. Android delivers onActivityResult
    // before onResume, so resuming is the race-free point to claim it.
    if (state == AppLifecycleState.resumed) {
      _pollForLostPhoto();
      ref.read(wordsProvider.notifier).resume();
    }
    // The OS can kill the process while the camera is open; `paused` is the
    // last guaranteed callback before that happens, so flush immediately
    // instead of waiting on the debounce timer.
    if (state == AppLifecycleState.paused) {
      ref.read(wordsProvider.notifier).flush();
      ref.read(pronunciationServiceProvider).stop();
    }
  }

  /// Android can restart our process just to serve [ImagePickerFileProvider]
  /// while the camera is still writing the photo, so the result may only reach
  /// the plugin a moment after we start up — and on a cold start we never get a
  /// `resumed` callback to retry on. Polling briefly covers both orderings.
  Future<void> _pollForLostPhoto() async {
    if (!Platform.isAndroid) return;
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 400),
      Duration(milliseconds: 600),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 3),
    ];
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      if (!mounted) return;
      if (_isAnalyzingPhoto) return;
      if (await _recoverLostPhoto()) return;
    }
  }

  /// Returns true once a lost photo has been claimed (or definitively failed),
  /// so the caller can stop polling.
  Future<bool> _recoverLostPhoto() async {
    // retrieveLostData is an Android-only concern.
    if (!Platform.isAndroid) return true;
    if (_isRecoveringLostPhoto || _isAnalyzingPhoto) return true;
    _isRecoveringLostPhoto = true;
    final collectionId = _collectionIdNow;
    try {
      final LostDataResponse response = await ref.read(imagePickerProvider).retrieveLostData();
      if (_collectionIdNow != collectionId) return true;
      if (response.isEmpty) return false;
      if (response.exception != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lost the photo: ${response.exception}')),
          );
        }
        return true;
      }
      final XFile? file = response.file;
      if (file == null) return false;
      await _processPickedPhoto(file);
      return true;
    } catch (e, stack) {
      debugPrint('VOCAB: recovery failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovering the photo failed: $e')),
        );
      }
      return true;
    } finally {
      _isRecoveringLostPhoto = false;
    }
  }

  /// Replaces the placeholder row from initState() with the persisted list,
  /// the first time it resolves (see the `ref.listen` in build()). Rebuilds
  /// every parallel per-row list from scratch, exactly like initState() does
  /// for a single row, then re-runs the same "always one trailing blank row"
  /// logic a fresh launch would. No row takes focus: the keyboard stays down
  /// (owner, 2026-10-18).
  void _restoreFromStore(List<WordPair> pairs) {
    for (final c in _wordControllers) {
      c.dispose();
    }
    for (final c in _translationControllers) {
      c.dispose();
    }
    for (final n in _wordFocusNodes) {
      n.dispose();
    }
    for (final n in _translationFocusNodes) {
      n.dispose();
    }
    for (final c in _definitionControllers) {
      c.dispose();
    }
    for (final n in _definitionFocusNodes) {
      n.dispose();
    }

    setState(() {
      _wordPairs
        ..clear()
        ..addAll(pairs.map((p) => p.copy()));
      _wordControllers.clear();
      _translationControllers.clear();
      _isLoadingTranslation.clear();
      _isLoadingWordTranslation.clear();
      _translationOptions.clear();
      _optionsWord.clear();
      _translationMarkedFilled.clear();
      _wordMarkedFilled.clear();
      _wordFocusNodes.clear();
      _translationFocusNodes.clear();
      _definitionControllers.clear();
      _definitionFocusNodes.clear();
      _isLoadingDefinition.clear();
      _definitionMarkedFilled.clear();
      _definitionSenses.clear();
      _sensesWord.clear();
      // Keep each surviving row's popup controller. CustomPopupMenu binds the
      // controller it is first handed in its own initState and never rebinds
      // (no didUpdateWidget), so a row whose State outlives this rebuild -- row
      // 0 is keyed ValueKey(0) and always does -- must be given back the very
      // same controller instance. Clearing the map handed that live State a
      // fresh controller it never adopted, so its popup showed on the old one
      // while the close icon hid the new one (the split hashCodes in the logs).
      // Drop only controllers for indices that no longer exist.
      _popupControllers.removeWhere((index, _) => index >= _wordPairs.length);
      _definitionPopupControllers.removeWhere((index, _) => index >= _wordPairs.length);

      for (var i = 0; i < _wordPairs.length; i++) {
        _addControllersForIndex(i);
        // The parallel lists are what the UI actually indexes into, so the
        // persisted extras have to land in them, not just in _wordPairs.
        final pair = _wordPairs[i];
        _translationOptions[i] = pair.translationOptions;
        // A block is only ever persisted while it matched the row's Word (see
        // _pushRow), so the restored block is keyed to the restored Word.
        _optionsWord[i] = pair.translationOptions != null ? pair.word.trim() : null;
        _wordMarkedFilled[i] = pair.wordMarkedFilled;
        _translationMarkedFilled[i] = pair.translationMarkedFilled;
        // Senses are only persisted while they match the Word (see _pushRow).
        final senses = DefinitionResult.decodeSenses(pair.definitionOptionsJson);
        _definitionSenses[i] = senses.isEmpty ? null : senses;
        _sensesWord[i] = senses.isEmpty ? null : pair.word.trim();
        _definitionMarkedFilled[i] = pair.definitionMarkedFilled;
      }
      _checkAndAddNewPair();
    });
  }

  /// Hot-reload-only safety net. Hot reload keeps this State object alive
  /// and just patches in new code, but it does NOT re-run initState() on
  /// that live instance -- so a per-row list field added in a later edit
  /// (like _wordFocusNodes) resets to its empty initializer while older
  /// fields (like _wordControllers) keep the values they already had,
  /// leaving the lists out of sync and causing a RangeError when the UI
  /// indexes into the short one. A full app restart never hits this
  /// (initState() runs normally and populates everything in lockstep), so
  /// this is skipped entirely in release builds, where hot reload doesn't
  /// happen.
  void _ensureRowStateSynced() {
    if (kReleaseMode) return;

    final target = _wordControllers.length;
    while (_wordFocusNodes.length < target) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _wordFocusNodes.add(node);
    }
    while (_translationFocusNodes.length < target) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _translationFocusNodes.add(node);
    }
    while (_translationMarkedFilled.length < target) {
      _translationMarkedFilled.add(false);
    }
    while (_translationOptions.length < target) {
      _translationOptions.add(null);
    }
    while (_optionsWord.length < target) {
      _optionsWord.add(null);
    }
    while (_isLoadingWordTranslation.length < target) {
      _isLoadingWordTranslation.add(false);
    }
    while (_wordMarkedFilled.length < target) {
      _wordMarkedFilled.add(false);
    }
    while (_definitionControllers.length < target) {
      _definitionControllers.add(TextEditingController());
    }
    while (_definitionFocusNodes.length < target) {
      final node = FocusNode();
      node.addListener(() {
        if (mounted) setState(() {});
      });
      _definitionFocusNodes.add(node);
    }
    while (_isLoadingDefinition.length < target) {
      _isLoadingDefinition.add(false);
    }
    while (_definitionMarkedFilled.length < target) {
      _definitionMarkedFilled.add(false);
    }
    while (_definitionSenses.length < target) {
      _definitionSenses.add(null);
    }
    while (_sensesWord.length < target) {
      _sensesWord.add(null);
    }
  }

  @override
  void _checkAndAddNewPair() {
    if (_wordPairs.isEmpty) return;

    final lastPair = _wordPairs.last;
    // Any content -- a definition-only row too -- earns a fresh blank row.
    if (!lastPair.isEmpty) {
      final newPair = WordPair(word: '', translation: '');
      setState(() {
        _wordPairs.add(newPair);
        _addControllersForIndex(_wordPairs.length - 1);
      });
      ref.read(wordsProvider.notifier).addAll([newPair]);
    }
  }

  void _navigateToTableScreen() {
    // The table has nothing to type into; drop the field's focus here so the
    // keyboard does not follow the navigation (it otherwise can, since this
    // screen stays in the stack underneath).
    FocusManager.instance.primaryFocus?.unfocus();
    const WordsTableRoute().go(context);
  }

  /// "Get words from photo": one photo import at a time, then the
  /// Camera/Gallery choice (photo-from-gallery sad §4, AC-01, AC-05, AC-10).
  Future<void> _takePhotoForVocabulary() async {
    if (_isAnalyzingPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The current photo is still being analysed')),
      );
      return;
    }
    final source = await showPhotoSourceDialog(context);
    if (source == null || !mounted) return;
    switch (source) {
      case ImageSource.camera:
        await _takePhotoFromCamera();
      case ImageSource.gallery:
        await _pickPhotoFromGallery();
    }
  }

  /// Gallery: the phone's own picker, one photo, no metadata, so iOS never
  /// asks for library access (photo-from-gallery sad §4, AC-06, AC-07, AC-09).
  Future<void> _pickPhotoFromGallery() async {
    final picker = ref.read(imagePickerProvider);
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } catch (e) {
      // For example an online-only photo that fails to download.
      debugPrint('VOCAB: gallery pick failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(_galleryPhotoUnusable)),
        );
      }
      return;
    }
    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photo was picked')),
        );
      }
      return;
    }
    await _processPickedPhoto(picked, source: ImageSource.gallery);
  }

  Future<void> _takePhotoFromCamera() async {
    final picker = ref.read(imagePickerProvider);
    XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      // On some Android devices (notably MIUI/Xiaomi, which logs
      // "checkCallerLegality: Unknown caller" for third-party camera
      // callers) the camera intent can fail instead of just returning null.
      // Without this catch, that exception was silently swallowed — the
      // screen would flash black and land back on the app with no feedback.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the camera: $e')),
        );
      }
      return;
    }
    if (picked == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No photo was taken')),
        );
      }
      return;
    }
    await _processPickedPhoto(picked);
  }

  /// [source] only picks the text when the photo cannot be read: the gallery
  /// text for a gallery photo, "Error analyzing photo" for a camera one.
  Future<void> _processPickedPhoto(XFile picked,
      {ImageSource source = ImageSource.camera}) async {
    final collectionId = _collectionIdNow;
    final notifier = ref.read(wordsProvider.notifier);
    setState(() {
      _isAnalyzingPhoto = true;
    });

    // The kept copy, started once the /analyze copy is done so it runs while
    // the request is out. Null when it could not be made: the words still
    // arrive, only without a photo (good-looking-web T17).
    Future<SessionSource?>? kept;
    var keptHandedOver = false;
    try {
      final compressStopwatch = Stopwatch()..start();
      final bytes = await ref.read(photoScalerProvider).resizeFileToMinSide(
        picked.path,
        minSide: 640,
        quality: 85,
      );
      compressStopwatch.stop();
      kept = _keepSourcePhoto(picked.path);

      final requestStopwatch = Stopwatch()..start();
      final result = await ref.read(vocabPhotoServiceProvider).analyzePhoto(
            bytes,
            mediaType: 'image/jpeg',
            translation: true,
            context: true,
            withDesc: true,
            shortifyDefinition: true,
            limit: _photoWordCap,
          );
      requestStopwatch.stop();

      if (mounted) {
        showVocabResultDialog(
          context,
          result.words,
          compressDuration: compressStopwatch.elapsed,
          requestDuration: requestStopwatch.elapsed,
          aiDuration: result.aiDuration,
        ).then((selected) async {
          final source = await kept;
          // The photo keeps all the text read on it (word-context AC-10).
          source?.fullText = result.fullText;
          if (selected != null && selected.isNotEmpty && collectionId != null && _collectionIdNow != collectionId) {
            // Another collection was opened since the photo was taken: the
            // words go to the one it was taken in (ADR-0006, AC-11).
            final delivered = await notifier.addWordsTo(collectionId,
                [for (final w in selected) wordPairFromPhotoAnalysis(w)],
                photo: source);
            if (!delivered && source != null) await ref.read(sourcePhotoStoreProvider).delete(source);
          } else if (selected != null && selected.isNotEmpty && mounted) {
            _addWordsFromPhoto(selected, source: source, fromPhoto: true);
          } else if (source != null) {
            // No row came from it, so it is not a source photo.
            await ref.read(sourcePhotoStoreProvider).delete(source);
          }
        });
        keptHandedOver = true;
      }
    } on VocabPhotoException catch (e) {
      debugPrint('VOCAB: analyze failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      debugPrint('VOCAB: processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(source == ImageSource.gallery
                  ? _galleryPhotoUnusable
                  : 'Error analyzing photo: $e')),
        );
      }
    } finally {
      if (!keptHandedOver && kept != null) {
        final store = ref.read(sourcePhotoStoreProvider);
        kept.then((source) {
          if (source != null) store.delete(source);
        });
      }
      if (mounted) {
        setState(() {
          _isAnalyzingPhoto = false;
        });
      }
    }
  }

  Future<SessionSource?> _keepSourcePhoto(String path) async {
    final takenAt = DateTime.now();
    final store = ref.read(sourcePhotoStoreProvider);
    try {
      final bytes = await ref.read(photoScalerProvider).keptCopy(path);
      return await store.keep(bytes, takenAt: takenAt);
    } catch (e) {
      debugPrint('VOCAB: kept photo copy failed: $e');
      return null;
    }
  }

  /// Appends words kept in the photo-results dialog to the main word list,
  /// reusing the still-empty first row if the screen hasn't been touched yet.
  /// With a kept [source], the photo joins the session first and every row
  /// added here points at it.
  /// collections-screen T14: the current collection's stored name, or its date
  /// name until the backfill has given it one (AC-01).
  String _collectionTitle() {
    final collection = ref.watch(wordsProvider).value;
    if (collection == null) return '';
    final stored = ref
        .watch(collectionNamingProvider(collection.collectionId))
        .value
        ?.name;
    return stored ??
        defaultCollectionName(
            creationMomentOf(collection.collectionId) ?? collection.updatedAt);
  }

  /// The kind of name the title shows and the one it showed before
  /// (collection-naming): the title animates when the AI's name replaces an
  /// undefined one.
  NameKind? _shownNameKind;
  bool _titleReveals() {
    final collection = ref.watch(wordsProvider).value;
    final kind = collection == null
        ? null
        : ref
            .watch(collectionNamingProvider(collection.collectionId))
            .value
            ?.kind;
    final reveals = kind == NameKind.auto && _shownNameKind == NameKind.undefined;
    _shownNameKind = kind;
    return reveals;
  }

  /// The pencil button: opens the Collection details sheet (name, description,
  /// tags) and saves through the store; the title follows the stored name
  /// (collection-tags AC-05).
  Future<void> _renameCollection() async {
    final collection = ref.read(wordsProvider).value;
    if (collection == null) return;
    // A name or description nobody gave is still AI's to fill: the field
    // starts empty with New collection's AI hint and note (owner, 2026-10-18).
    final naming = ref
        .read(collectionNamingProvider(collection.collectionId))
        .value;
    final title = _collectionTitle();
    final aiName = naming?.kind == NameKind.undefined;
    final description = collection.description ?? '';
    final aiDescription = collection.descriptionKind == NameKind.undefined &&
        description.trim().isEmpty;
    final details = await showCollectionDetailsSheet(
      context,
      mode: DetailsMode.edit,
      aiNameUntil: aiName ? title : null,
      aiDescription: aiDescription,
      initial: (
        name: aiName ? '' : title,
        description: description,
        origin: [...collection.originTags],
        topic: [...collection.topicTags],
      ),
    );
    if (details == null) return;
    await ref.read(wordsProvider.notifier).saveDetails(
          // Left blank: the name stays AI's to give.
          name: details.name.trim().isEmpty ? null : details.name,
          description: details.description,
          origin: details.origin,
          topic: details.topic,
        );
  }

  /// words-from-subtitles: the "From subtitles" speed-dial item. Kept words
  /// go through [_addWordsFromPhoto] with no source photo, so they are
  /// ordinary rows (AC-17).
  Future<void> _importFromSubtitles() => runSubtitleImport(
        context: context,
        ref: ref,
        currentCollectionId: () => ref.read(wordsProvider).value?.collectionId,
        collectionWords: () => [
          for (final pair in ref.read(wordsProvider).value?.words ?? const <WordPair>[])
            if (pair.word.trim().isNotEmpty && pair.word.trim().length <= 500) pair.word.trim(),
        ].take(500).toList(),
        addWords: (words, film, poster, filmRow) {
          if (!mounted) return;
          // side-panel-sources AC-22: the film joins the session's sources
          // (or the one already there is reused), and the rows point at it.
          final sourceId =
              ref.read(wordsProvider.notifier).upsertSubtitlesSource(film, poster: poster);
          _addWordsFromPhoto(words, sourceId: sourceId, filmRow: filmRow);
        },
        addDialogues: (dialogues, keptCount) {
          if (mounted) ref.read(wordsProvider.notifier).addImportDialogues(dialogues, keptCount);
        },
        addWordsTo: (collectionId, words, film, poster, dialogues, filmRow) async {
          if (!mounted) return;
          await ref.read(wordsProvider.notifier).addWordsTo(
                collectionId,
                [for (final w in words) filmRow(wordPairFromPhoto(w))],
                film: film,
                poster: poster,
                dialogues: dialogues,
              );
        },
      );

  /// import-from-quizlet: the "Import from Quizlet" speed-dial item. On Done
  /// the set joins the session's sources first (or renames the one already
  /// there for this set), then the kept words are appended in set order,
  /// each pointing at it (AC-03, AC-13b).
  Future<void> _importFromQuizlet() => runQuizletImport(
        context: context,
        currentCollectionId: () => ref.read(wordsProvider).value?.collectionId,
        collectionWords: () => [
          for (final pair in ref.read(wordsProvider).value?.words ?? const <WordPair>[])
            if (pair.word.trim().isNotEmpty) pair.word.trim(),
        ],
        addWords: (words, set) {
          if (!mounted) return;
          final sourceId = ref
              .read(wordsProvider.notifier)
              .upsertSetSource(set.id, set.name, set.url);
          _addWordsFromPhoto(words, sourceId: sourceId);
        },
        addWordsTo: (collectionId, words, set) async {
          if (!mounted) return;
          await ref.read(wordsProvider.notifier).addWordsTo(
                collectionId,
                [for (final w in words) wordPairFromPhoto(w)],
                set: set,
              );
        },
        driverFactory: widget.quizletDriverFactory,
      );

  /// [fromPhoto]: the words come from a photo analysis, so the rows get the
  /// image origin and the words' context (word-context AC-02, AC-10).
  /// [filmRow]: the words come from subtitles, so it gives each row its movie
  /// origin, time and context (AC-06 – AC-09).
  void _addWordsFromPhoto(List<VocabWord> words,
      {SessionSource? source, String? sourceId, bool fromPhoto = false, SubtitleFilmRow? filmRow}) {
    var reusedFirstRow = false;
    final appendedPairs = <WordPair>[];
    if (source != null) {
      ref.read(wordsProvider.notifier).addSource(source);
    }
    // The new words go after the last word, not after the trailing blank row:
    // drop it here, and _checkAndAddNewPair below adds a fresh one at the end.
    if (words.isNotEmpty && _wordPairs.length > 1 && _wordPairs.last.isEmpty) {
      _removeItem(_wordPairs.length - 1);
    }

    setState(() {
      for (final w in words) {
        final pair = fromPhoto
            ? wordPairFromPhotoAnalysis(w, sourceId: source?.id ?? sourceId)
            : (filmRow ?? _sameRow)(wordPairFromPhoto(w, sourceId: source?.id ?? sourceId));
        if (_wordPairs.length == 1 && _wordPairs[0].isEmpty) {
          // The row already holds the texts, so the controller listeners see
          // no change; the single _pushRow below persists everything.
          _wordPairs[0] = pair;
          _wordControllers[0].text = pair.word;
          _translationControllers[0].text = pair.translation;
          _definitionControllers[0].text = pair.definition;
          // Photo recognition auto-populated this row -> "filled".
          _translationMarkedFilled[0] = pair.translationMarkedFilled;
          _wordMarkedFilled[0] = pair.wordMarkedFilled;
          _definitionMarkedFilled[0] = pair.definitionMarkedFilled;
          reusedFirstRow = true;
        } else {
          // The marks travel on the pair itself: these objects are handed to
          // the notifier by addAll() below, so they must already carry them.
          _wordPairs.add(pair);
          _addControllersForIndex(_wordPairs.length - 1);
          _translationMarkedFilled[_wordPairs.length - 1] = pair.translationMarkedFilled;
          _wordMarkedFilled[_wordPairs.length - 1] = pair.wordMarkedFilled;
          _definitionMarkedFilled[_wordPairs.length - 1] = pair.definitionMarkedFilled;
          appendedPairs.add(_wordPairs[_wordPairs.length - 1]);
        }
      }
    });

    if (reusedFirstRow) {
      _pushRow(0,
          word: _wordPairs[0].word,
          translation: _wordPairs[0].translation,
          definition: _wordPairs[0].definition,
          sourceId: _wordPairs[0].sourceId);
      // The blank row the words went into takes their origin and context too.
      ref.read(wordsProvider.notifier).updateAt(_storeIndex(0),
          origin: _wordPairs[0].origin,
          context: _wordPairs[0].context,
          contextKind: _wordPairs[0].contextKind);
    }
    if (appendedPairs.isNotEmpty) {
      ref.read(wordsProvider.notifier).addAll(appendedPairs);
    }
    // After addAll, so the notifier gets the new blank row after the words too.
    _checkAndAddNewPair();
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      // Flutter quirk: якщо переміщуємо вниз, треба зменшити newIndex на 1
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      // Синхронізуємо всі списки
      // 1. _wordPairs
      final wordPair = _wordPairs.removeAt(oldIndex);
      _wordPairs.insert(newIndex, wordPair);

      // 2. _wordControllers
      final wordController = _wordControllers.removeAt(oldIndex);
      _wordControllers.insert(newIndex, wordController);

      // 3. _translationControllers
      final translationController = _translationControllers.removeAt(oldIndex);
      _translationControllers.insert(newIndex, translationController);

      // 4. _isLoadingTranslation
      final isLoading = _isLoadingTranslation.removeAt(oldIndex);
      _isLoadingTranslation.insert(newIndex, isLoading);

      // 4b. _isLoadingWordTranslation
      final isLoadingWord = _isLoadingWordTranslation.removeAt(oldIndex);
      _isLoadingWordTranslation.insert(newIndex, isLoadingWord);

      // 5. _translationOptions
      final options = _translationOptions.removeAt(oldIndex);
      _translationOptions.insert(newIndex, options);

      // 5b. _optionsWord (travels with its block)
      final optionsWord = _optionsWord.removeAt(oldIndex);
      _optionsWord.insert(newIndex, optionsWord);

      // 6. _translationMarkedFilled
      final markedFilled = _translationMarkedFilled.removeAt(oldIndex);
      _translationMarkedFilled.insert(newIndex, markedFilled);

      // 6b. _wordMarkedFilled
      final wordMarkedFilled = _wordMarkedFilled.removeAt(oldIndex);
      _wordMarkedFilled.insert(newIndex, wordMarkedFilled);

      // 7. _wordFocusNodes / _translationFocusNodes
      final wordFocusNode = _wordFocusNodes.removeAt(oldIndex);
      _wordFocusNodes.insert(newIndex, wordFocusNode);
      final translationFocusNode = _translationFocusNodes.removeAt(oldIndex);
      _translationFocusNodes.insert(newIndex, translationFocusNode);

      // 7b. The definition lists travel with their row (definition-mode).
      void move<T>(List<T> list) => list.insert(newIndex, list.removeAt(oldIndex));
      move(_definitionControllers);
      move(_definitionFocusNodes);
      move(_isLoadingDefinition);
      move(_definitionMarkedFilled);
      move(_definitionSenses);
      move(_sensesWord);

      // 8. _popupControllers: prune only out-of-range indices, never clear.
      // Clearing handed each surviving row's live State (kept alive across the
      // reorder by its ValueKey) a fresh controller the package never rebinds
      // to -- see _restoreFromStore. Row count is unchanged here, so this drops
      // nothing; it just stops orphaning the controllers those States hold.
      _popupControllers.removeWhere((index, _) => index >= _wordPairs.length);
      _definitionPopupControllers.removeWhere((index, _) => index >= _wordPairs.length);

      ref.read(wordsProvider.notifier).reorder(oldIndex, newIndex);
    });
  }

  @override
  void dispose() {
    _tagLine.dispose();
    _bodyStill.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pronunciation.stop();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    for (var controller in _translationControllers) {
      controller.dispose();
    }
    for (var node in _wordFocusNodes) {
      node.dispose();
    }
    for (var node in _translationFocusNodes) {
      node.dispose();
    }
    for (var controller in _definitionControllers) {
      controller.dispose();
    }
    for (var node in _definitionFocusNodes) {
      node.dispose();
    }
    _listScroll.dispose();
    photoPanel.openness.removeListener(_onPhotoPanelOpenness);
    super.dispose();
  }

  Widget _buildRowItem(int index,
      {required bool isDragMode,
      required WordDetailMode detailMode,
      Decoration? highlight}) {
    // While the photo panel is open the rows ignore touches (spec AC-11),
    // and each one turns into its one line, "word — translation", as the
    // panel slides in.
    final compact = photoPanel.isOpen;
    return IgnorePointer(
      key: _rowKey(index),
      ignoring: compact,
      child: WordRowMorph(
      index: index,
      openness: photoPanel.openness,
      // The word and the translation fly between their fields and the line;
      // a definition (usually several lines) only fades.
      word: _wordControllers[index],
      detail: detailMode != WordDetailMode.definition &&
              _translationControllers[index].text.trim().isNotEmpty
          ? _translationControllers[index]
          : null,
      line: (hideWord, hideDetail) => CompactWordLine(
        index: index,
        word: _wordControllers[index].text,
        detail: compactDetail(
          mode: detailMode,
          translation: _translationControllers[index].text,
          definition: _definitionControllers[index].text,
        ),
        highlight: highlight,
        endInset: _compactEndInset,
        hideWord: hideWord,
        hideDetail: hideDetail,
      ),
      full: _wordRowItem(index,
          isDragMode: isDragMode, detailMode: detailMode, highlight: highlight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureRowStateSynced(); // hot-reload safety net, see method doc above

    // Restore: once a session resolves, replace the placeholder row created in
    // initState() with that session's words. Keyed on the session id, so the
    // ordinary notifier updates below (all driven by this screen's own
    // mutations, via updateAt/removeAt/reorder/addAll) never re-trigger it,
    // while another session being swapped in does.
    ref.listen(wordsProvider, (previous, next) {
      next.whenData((collection) {
        if (_restoredCollectionId == collection.collectionId) return;
        final swapped = _restoredCollectionId != null;
        _restoredCollectionId = collection.collectionId;
        // Another session: the photo panel closes and nothing stays
        // selected (side-bar-for-main-screen, spec AC-15b).
        photoPanel.close();
        if (collection.words.isNotEmpty) {
          _restoreFromStore(collection.words);
        } else if (swapped) {
          // This screen stays alive in the menu shell, so an empty
          // collection opened later gets the one blank row a new screen
          // starts with, not the previous collection's rows.
          _restoreFromStore([WordPair(word: '', translation: '')]);
        }
        debugPrint('VOCAB: session ${collection.collectionId} on screen');
      });
    });

    // The one place the reorder preference is read. Written by the Settings
    // screen (task-13); this screen only reads it.
    final isDragMode = ref.watch(dragModeProvider);
    final detailMode = ref.watch(wordDetailModeProvider);

    // side-bar-for-main-screen: the panel follows the sources with words
    // (photos and sets); a vanished selected one is unselected, none left
    // closes it (AC-15, AC-21).
    ref.listen(sourcesWithWordsProvider, (_, photos) {
      photoPanel.retain([for (final p in photos) p.source.id]);
    });
    _compactEndInset = const LookA().halfOpenWidth - 16;
    final (highlightedRows, highlight) =
        photoHighlight(ref.watch(sourcesWithWordsProvider));
    Decoration? highlightFor(int index) =>
        highlightedRows.contains(index) ? highlight : null;

    final originTags = _originTags(), topicTags = _topicTags();
    final hasTags = originTags.isNotEmpty || topicTags.isNotEmpty;
    if (_tagLineOpen == null) {
      _tagLine.value = hasTags ? 1 : 0;
    } else if (_tagLineOpen != hasTags) {
      _tagLine.animateTo(hasTags ? 1 : 0, curve: Curves.easeInOut);
    }
    _tagLineOpen = hasTags;

    // Back steps the open photo panel back one stop and never leaves the
    // screen while it is open (spec AC-10). Closed, Back goes to Collections,
    // the start screen (navigation, owner 2026-10-18).
    // While the drawer is open Back only closes it.
    return PopScope(
      canPop: _drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (photoPanel.isOpen) {
          photoPanel.stepBack();
        } else {
          const CollectionsRoute().go(context);
        }
      },
      child: Scaffold(
      appBar: photoPanelGuardedAppBar(AppBar(
        automaticallyImplyLeading: true,
        // The title starts right after the menu button, the edit button right
        // after the title; the free space goes before Next.
        centerTitle: false,
        leadingWidth: 48,
        // The menu button takes the edit icon's colour.
        iconTheme: IconThemeData(color: AppDecor.of(context).onBarButtonOf(context)),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: CollectionTitle(
                text: _collectionTitle(),
                collectionId: ref.watch(wordsProvider).value?.collectionId,
                animate: _titleReveals(),
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Rename collection',
              onPressed: _renameCollection,
              // Narrow, so the pencil sits right after the title; the tap
              // area keeps the full bar height.
              padding: const EdgeInsets.symmetric(horizontal: 4),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 48),
              style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              color: AppDecor.of(context).onBarButtonOf(context),
              icon: const Icon(Icons.edit, size: 20),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: CollectionTagLine(
          originTags: originTags,
          topicTags: topicTags,
          height: CollectionTagLine.lineHeight * _tagLine.value,
          onTap: (kind, text) =>
              CollectionsRoute(tagKind: kind, tag: text).push(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _navigateToTableScreen,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDecor.of(context).barButton,
                foregroundColor: AppDecor.of(context).onBarButtonOf(context),
              ),
            ),
          ),
        ],
      )),
      // The drawer's edge swipe is off while the photo panel is open (AC-11).
      drawerEnableOpenDragGesture: !photoPanel.isOpen,
      onDrawerChanged: (open) {
        setState(() => _drawerOpen = open);
        if (open) photoPanel.close();
      },
      drawer: AppDrawer(
        current: AppMenuItem.words,
        // In the tree exactly while the drawer is on screen (StillBody).
        wrap: (list) =>
            StillBodyWhileMounted(controller: _bodyStill, child: list),
      ),
        // The theme's backdrop, behind the list (app-themes).
      body: StillBody(
          controller: _bodyStill,
          child: AppBackdrop(
            child: Stack(
        children: [
      Stack(
        children: [
          // Open photo panel: a tap or a sideways swipe on the list closes it
          // and does nothing else; a vertical drag still scrolls (AC-06, AC-11).
          // The rows' blurs share one backdrop read (see DecorSurface).
          BackdropGroup(
            child: GestureDetector(
            onTap: photoPanel.isOpen ? photoPanel.close : null,
            onHorizontalDragStart:
                photoPanel.isOpen ? (_) => photoPanel.close() : null,
            child: isDragMode
            ? ReorderableListView.builder(
                scrollController: _listScroll,
                padding: const EdgeInsets.all(16.0),
                itemCount: _wordPairs.length,
                onReorder: _reorderItems,
                itemBuilder: (context, index) => _buildRowItem(index,
                    isDragMode: true, detailMode: detailMode, highlight: highlightFor(index)),
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    // Dragged over the other rows: frosted on Android too.
                    child: LiveBlur(child: child),
                  );
                },
              )
            : ListView.builder(
                controller: _listScroll,
                padding: const EdgeInsets.all(16.0),
                itemCount: _wordPairs.length,
                itemBuilder: (context, index) => _buildRowItem(index,
                    isDragMode: false, detailMode: detailMode, highlight: highlightFor(index)),
              ),
            ),
          ),
          if (_isAnalyzingPhoto)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Analyzing photo...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
          // The photo tab and panel paint above the route through an overlay;
          // this child only marks the main screen's place (ADR-0001).
          Positioned.fill(
            child: PhotoPanel(
              controller: photoPanel,
              busy: _isAnalyzingPhoto,
              hidden: _drawerOpen,
              // Kept free for the floating-button row (spec AC-01).
              bottomReserve: 80,
              // The tag line is the top bar's: the tab stands where it
              // does on the Words screen, which has none.
              tabTopInset: CollectionTagLine.lineHeight * _tagLine.value,
              scrollController: _listScroll,
              onSelected: _onPhotoSelected,
              onOpenNotes: _openNotes,
              notesPage: (id) => NotesScreen(selectedId: id, preview: true),
            ),
          ),
        ],
        ))),
      // Both round buttons share the Scaffold's FAB slot, so the Scaffold moves
      // them together: above a snackbar, above the keyboard, above the bottom
      // safe area -- always on one line. A full-width row, centred, puts the
      // settings button bottom-left and the speed dial bottom-right (D9 (c) in
      // docs/roadmap.md), each 16px from its edge like endFloat's margin. The
      // gap between them is not hit-testable, so rows underneath stay tappable.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: closesOpenPhotoPanel(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Mirrors the speed dial's plus button: same elevation, same white
            // glyph on a filled circle, purple instead of red. The plain
            // constructor, not `.small`, because `.small` switches the default
            // shape to a 12px RoundedRectangleBorder and a square button would
            // not read as the same control.
            FloatingActionButton(
              heroTag: null,
              onPressed: () => const SettingsRoute().push(context),
              tooltip: 'Settings',
              elevation: 8.0,
              shape: const CircleBorder(),
              backgroundColor: AppDecor.of(context).fabAlt,
              foregroundColor: AppDecor.of(context).onFabAlt,
              child: const Icon(Icons.settings),
            ),
            WordsSpeedDial(
              onTakePhoto: _takePhotoForVocabulary,
              onFromSubtitles: _importFromSubtitles,
              onImportFromQuizlet: _importFromQuizlet,
            ),
          ],
        ),
      )),
      ),
    );
  }

  /// Opens Notes for the source [id]. The Notes words dialog edits the
  /// session's words directly, so the rows are built again from the session
  /// when Notes closes after it did (notes-editing).
  Future<void> _openNotes(String? id) async {
    await NotesRoute(selectedId: id).push<void>(context);
    if (!mounted) return;
    final notifier = ref.read(wordsProvider.notifier);
    final collection = ref.read(wordsProvider).value;
    if (!notifier.takeEditedElsewhere() || collection == null) return;
    _restoreFromStore(collection.words);
  }

  /// The current collection's typed tags; a collection from before the typed
  /// tags shows its legacy tags as topic tags.
  bool get _legacyOnly {
    final c = ref.watch(wordsProvider).value;
    return c != null &&
        c.originTags.isEmpty &&
        c.topicTags.isEmpty &&
        c.tags.isNotEmpty;
  }

  List<String> _originTags() =>
      ref.watch(wordsProvider).value?.originTags ?? const [];

  List<String> _topicTags() {
    final c = ref.watch(wordsProvider).value;
    if (c == null) return const [];
    return _legacyOnly ? c.tags : c.topicTags;
  }
}
