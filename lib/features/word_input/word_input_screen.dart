import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/MyCustomPopupMenuController.dart';
import 'package:image_picker/image_picker.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../core/models/collection_name.dart';
import '../../core/models/definition_result.dart';
import '../../core/models/session_source.dart';
import '../../core/models/translation_result.dart';
import '../../core/models/vocab_word.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/services/pronunciation_service.dart';
import '../../core/services/vocab_photo_service.dart';
import '../../router/routes.dart';
import '../collections/name_dialog.dart';
import '../notes/notes_screen.dart';
import 'lightning_rules.dart';
import 'photo_panel/looks/look_a.dart';
import 'photo_panel/photo_panel.dart';
import 'photo_panel/photo_panel_controller.dart';
import 'photo_panel/photos_with_words.dart';
import 'photo_panel/row_jump.dart';
import 'quizlet_import_flow.dart';
import 'subtitle_import_flow.dart';
import 'widgets/photo_source_dialog.dart';
import 'widgets/quizlet_progress_dialog.dart';
import 'widgets/vocab_result_dialog.dart';
import 'widgets/word_input_speed_dial.dart';
import 'widgets/word_row_item.dart';
import 'widgets/anchored_scroll_controller.dart';
import 'widgets/dashed_add_button.dart';
import 'widgets/word_row_morph.dart';
import 'word_input_notifier.dart';

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

class WordInputScreen extends ConsumerStatefulWidget {
  const WordInputScreen({super.key, this.quizletDriverFactory});

  /// Stands in for the Quizlet web view in tests; null in the app.
  @visibleForTesting
  final QuizletPageDriverFactory? quizletDriverFactory;

  @override
  ConsumerState<WordInputScreen> createState() => _WordInputScreenState();
}

class _WordInputScreenState extends ConsumerState<WordInputScreen>
    with WidgetsBindingObserver, _WordRows<WordInputScreen> {
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

  /// side-bar-for-main-screen: the photo panel's stop and selected photo
  /// (sad §4 "State placement"); read for Back and the rows' highlight.
  final PhotoPanelController _photoPanel = PhotoPanelController();

  /// The drawer is open: the photo tab hides behind it (ADR-0001).
  bool _drawerOpen = false;

  /// Kept free at the end of a row's one line: the half-open panel covers the
  /// list's right side past its 16 px padding. Set in build from the look.
  double _compactEndInset = 0;

  void _onPhotoPanelChanged() {
    if (mounted) setState(() {});
  }

  /// The rows morph while the panel is between closed and half-open; the
  /// list keeps the row on top in place from the first frame of a move until
  /// the panel rests (or the list is scrolled by hand).
  bool _rowsResting = true;
  void _onPhotoPanelOpenness() {
    final t = _photoPanel.openness.value;
    final resting = t <= 0 || t >= 0.5;
    if (resting == _rowsResting) return;
    _rowsResting = resting;
    if (resting) {
      _listScroll.release();
    } else {
      _listScroll.holdTopItem();
    }
  }

  /// While the photo panel is open the main screen is only for looking: a
  /// touch on a row, the top bar or the floating buttons closes the panel
  /// and does nothing else; the list still scrolls (spec AC-11). Closed,
  /// [child] is exactly as before.
  Widget _closesOpenPhotoPanel(Widget child) {
    final open = _photoPanel.isOpen;
    return GestureDetector(
      onTap: open ? _photoPanel.close : null,
      child: AbsorbPointer(absorbing: open, child: child),
    );
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
  /// than a bool because RESTORE swaps one session for another and the screen
  /// has to rebuild its rows for the second one too.
  String? _restoredCollectionId;

  /// True only while the "words from your last session are saved" snackbar is
  /// up, so the first edit dismisses that one and never someone else's.
  bool _restoreSnackBarVisible = false;

  /// Read once in initState: dispose() may not touch `ref` (Riverpod forbids
  /// it once the element is torn down), yet it still has to stop speech.
  late final PronunciationService _pronunciation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _photoPanel.addListener(_onPhotoPanelChanged);
    _photoPanel.openness.addListener(_onPhotoPanelOpenness);
    _pronunciation = ref.read(pronunciationServiceProvider);
    _addControllersForIndex(0);
    // Request focus on the first field after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wordFocusNodes[0].requestFocus();
    });
    _pollForLostPhoto();
    _startSeenTimer();
  }

  /// While the app is open, the current session is recorded as seen every
  /// [WordInputNotifier.seenEvery], so a launch soon after counts it as
  /// touched (owner, 2026-10-16).
  Timer? _seenTimer;

  void _startSeenTimer() {
    _seenTimer?.cancel();
    _seenTimer = Timer.periodic(WordInputNotifier.seenEvery,
        (_) => ref.read(wordInputNotifierProvider.notifier).markSeen());
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
      ref.read(wordInputNotifierProvider.notifier).markSeen();
      _startSeenTimer();
    }
    // The OS can kill the process while the camera is open; `paused` is the
    // last guaranteed callback before that happens, so flush immediately
    // instead of waiting on the debounce timer.
    if (state == AppLifecycleState.paused) {
      _seenTimer?.cancel();
      ref.read(wordInputNotifierProvider.notifier)
        ..markSeen()
        ..flush();
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

  /// The launch rule started a new session because the previous one had gone
  /// cold (> 5 minutes). Offer it back for 7 seconds; ignoring it or typing
  /// leaves the new session current and the old one in history.
  void _showRestoreSnackBar() {
    log("_showRestoreSnackBar called");
    if (!mounted) return;
    // Shown straight from the `ref.listen` callback rather than from a
    // post-frame callback: that callback only ever runs if something else
    // schedules a frame, which is not guaranteed here.
    _restoreSnackBarVisible = true;
    log("_showRestoreSnackBar context is mounted");
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: const Text('We kept the words you typed before'),
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'RESTORE',
              onPressed: () {
                _restoreSnackBarVisible = false;
                ref.read(wordInputNotifierProvider.notifier).restorePrevious();
              },
            ),
          ),
        )
        .closed
        .then((_) => _restoreSnackBarVisible = false);
  }

  /// Takes the RESTORE snackbar down on the first edit, so tapping RESTORE can
  /// never discard words the user has already typed. Guarded by a flag so it
  /// only ever hides that snackbar, not a translation error.
  @override
  void _dismissRestoreSnackBar() {
    if (!_restoreSnackBarVisible) return;
    _restoreSnackBarVisible = false;
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Replaces the placeholder row from initState() with the persisted list,
  /// the first time it resolves (see the `ref.listen` in build()). Rebuilds
  /// every parallel per-row list from scratch, exactly like initState() does
  /// for a single row, then re-runs the same "always one trailing blank row"
  /// and initial-focus logic a fresh launch would.
  void _restoreFromStore(List<WordPair> pairs, {bool focusLast = true}) {
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

    if (!focusLast) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wordFocusNodes.isNotEmpty) {
        _wordFocusNodes.last.requestFocus();
      }
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
      ref.read(wordInputNotifierProvider.notifier).addAll([newPair]);
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
            withDesc: true,
            shortifyDefinition: true,
            limit: _photoWordCap,
          );
      requestStopwatch.stop();
      if (_collectionIdNow != collectionId) return;

      if (mounted) {
        showVocabResultDialog(
          context,
          result.words,
          compressDuration: compressStopwatch.elapsed,
          requestDuration: requestStopwatch.elapsed,
          aiDuration: result.aiDuration,
        ).then((selected) async {
          final source = await kept;
          if (selected != null && selected.isNotEmpty && mounted && _collectionIdNow == collectionId) {
            _addWordsFromPhoto(selected, source: source);
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
    final collection = ref.watch(wordInputNotifierProvider).valueOrNull;
    if (collection == null) return '';
    final stored =
        ref.watch(collectionNameProvider(collection.collectionId)).valueOrNull;
    return stored ??
        defaultCollectionName(
            creationMomentOf(collection.collectionId) ?? collection.updatedAt);
  }

  /// The pencil button: asks for a new name and renames through the store; the
  /// title follows the stored name (AC-02, AC-03).
  Future<void> _renameCollection() async {
    final collection = ref.read(wordInputNotifierProvider).valueOrNull;
    if (collection == null) return;
    final name = await showNameDialog(
      context,
      mode: NameDialogMode.renameCollection,
      initial: _collectionTitle(),
    );
    if (name == null) return;
    final store = await ref.read(collectionStoreProvider.future);
    await store.rename(collection.collectionId, name);
  }

  /// words-from-subtitles: the "From subtitles" speed-dial item. Kept words
  /// go through [_addWordsFromPhoto] with no source photo, so they are
  /// ordinary rows (AC-17).
  Future<void> _importFromSubtitles() => runSubtitleImport(
        context: context,
        ref: ref,
        currentCollectionId: () => ref.read(wordInputNotifierProvider).valueOrNull?.collectionId,
        collectionWords: () => [
          for (final pair in ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const <WordPair>[])
            if (pair.word.trim().isNotEmpty && pair.word.trim().length <= 500) pair.word.trim(),
        ].take(500).toList(),
        addWords: (words, film, poster) {
          if (!mounted) return;
          // side-panel-sources AC-22: the film joins the session's sources
          // (or the one already there is reused), and the rows point at it.
          final sourceId =
              ref.read(wordInputNotifierProvider.notifier).upsertSubtitlesSource(film, poster: poster);
          _addWordsFromPhoto(words, sourceId: sourceId);
        },
        addDialogues: (dialogues, keptCount) {
          if (mounted) ref.read(wordInputNotifierProvider.notifier).addImportDialogues(dialogues, keptCount);
        },
      );

  /// import-from-quizlet: the "Import from Quizlet" speed-dial item. On Done
  /// the set joins the session's sources first (or renames the one already
  /// there for this set), then the kept words are appended in set order,
  /// each pointing at it (AC-03, AC-13b).
  Future<void> _importFromQuizlet() => runQuizletImport(
        context: context,
        currentCollectionId: () => ref.read(wordInputNotifierProvider).valueOrNull?.collectionId,
        collectionWords: () => [
          for (final pair in ref.read(wordInputNotifierProvider).valueOrNull?.words ?? const <WordPair>[])
            if (pair.word.trim().isNotEmpty) pair.word.trim(),
        ],
        addWords: (words, set) {
          if (!mounted) return;
          final sourceId = ref
              .read(wordInputNotifierProvider.notifier)
              .upsertSetSource(set.id, set.name, set.url);
          _addWordsFromPhoto(words, sourceId: sourceId);
        },
        driverFactory: widget.quizletDriverFactory,
      );

  void _addWordsFromPhoto(List<VocabWord> words, {SessionSource? source, String? sourceId}) {
    var reusedFirstRow = false;
    final appendedPairs = <WordPair>[];
    if (source != null) {
      ref.read(wordInputNotifierProvider.notifier).addSource(source);
    }
    // The new words go after the last word, not after the trailing blank row:
    // drop it here, and _checkAndAddNewPair below adds a fresh one at the end.
    if (words.isNotEmpty && _wordPairs.length > 1 && _wordPairs.last.isEmpty) {
      _removeItem(_wordPairs.length - 1);
    }

    setState(() {
      for (final w in words) {
        final pair = wordPairFromPhoto(w, sourceId: source?.id ?? sourceId);
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
    }
    if (appendedPairs.isNotEmpty) {
      ref.read(wordInputNotifierProvider.notifier).addAll(appendedPairs);
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

      ref.read(wordInputNotifierProvider.notifier).reorder(oldIndex, newIndex);
    });
  }

  @override
  void dispose() {
    _seenTimer?.cancel();
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
    _photoPanel.openness.removeListener(_onPhotoPanelOpenness);
    _photoPanel.dispose();
    super.dispose();
  }

  Widget _buildRowItem(int index,
      {required bool isDragMode,
      required WordDetailMode detailMode,
      Decoration? highlight}) {
    // While the photo panel is open the rows ignore touches (spec AC-11),
    // and each one turns into its one line, "word — translation", as the
    // panel slides in.
    final compact = _photoPanel.isOpen;
    return IgnorePointer(
      key: _rowKey(index),
      ignoring: compact,
      child: WordRowMorph(
      index: index,
      openness: _photoPanel.openness,
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

  /// The selected photo's rows and the look's highlight for them (spec AC-04);
  /// with nothing selected every row is today's row.
  (Set<int>, Decoration?) _photoHighlight(List<SourceWithWords> photos) {
    final id = _photoPanel.selectedId;
    if (id == null) return (const {}, null);
    final rows = photos.where((p) => p.source.id == id).firstOrNull?.rows;
    if (rows == null) return (const {}, null);
    return (rows.toSet(), const LookA().rowHighlight(context));
  }

  @override
  Widget build(BuildContext context) {
    _ensureRowStateSynced(); // hot-reload safety net, see method doc above

    // Restore: once a session resolves, replace the placeholder row created in
    // initState() with that session's words. Keyed on the session id, so the
    // ordinary notifier updates below (all driven by this screen's own
    // mutations, via updateAt/removeAt/reorder/addAll) never re-trigger it,
    // while RESTORE swapping in the previous session does.
    ref.listen(wordInputNotifierProvider, (previous, next) {
      next.whenData((collection) {
        if (_restoredCollectionId == collection.collectionId) return;
        _restoredCollectionId = collection.collectionId;
        // Another session: the photo panel closes and nothing stays
        // selected (side-bar-for-main-screen, spec AC-15b).
        _photoPanel.close();
        // Read before restoring: rebuilding the rows can itself mutate the
        // notifier, which clears this.
        final restorable = ref.read(wordInputNotifierProvider.notifier).restorableCollectionId;
        // A switch from History cancels the offer (edit-session-from-history).
        if (restorable == null) _dismissRestoreSnackBar();
        if (collection.words.isNotEmpty) _restoreFromStore(collection.words);
        debugPrint('VOCAB: session ${collection.collectionId} on screen, '
            'RESTORE ${restorable == null ? 'not offered' : 'offered for $restorable'}');
        if (restorable != null) _showRestoreSnackBar();
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
      _photoPanel.retain([for (final p in photos) p.source.id]);
    });
    _compactEndInset = const LookA().halfOpenWidth - 16;
    final (highlightedRows, highlight) =
        _photoHighlight(ref.watch(sourcesWithWordsProvider));
    Decoration? highlightFor(int index) =>
        highlightedRows.contains(index) ? highlight : null;

    // Back steps the open photo panel back one stop and never leaves the
    // screen while it is open (spec AC-10). Closed, Back is as before.
    return PopScope(
      canPop: !_photoPanel.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _photoPanel.stepBack();
      },
      child: Scaffold(
      appBar: _photoPanelGuardedAppBar(AppBar(
        automaticallyImplyLeading: true,
        title: Text(_collectionTitle(), maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Tooltip(
              message: 'Rename collection',
              child: ElevatedButton(
                onPressed: _renameCollection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Icon(Icons.edit),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _navigateToTableScreen,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      )),
      // The drawer's edge swipe is off while the photo panel is open (AC-11).
      drawerEnableOpenDragGesture: !_photoPanel.isOpen,
      onDrawerChanged: (open) {
        setState(() => _drawerOpen = open);
        if (open) _photoPanel.close();
      },
      drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    child: const Text(
                      'Меню',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text('Main'),
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Collections'),
                    onTap: () {
                      Navigator.pop(context);
                      const CollectionsRoute().go(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('History'),
                    onTap: () {
                      Navigator.pop(context);
                      const HistoryRoute().go(context);
                    },
                  ),
                ],
              ),
            ),
      body: Stack(
        children: [
      Stack(
        children: [
          // Open photo panel: a tap or a sideways swipe on the list closes it
          // and does nothing else; a vertical drag still scrolls (AC-06, AC-11).
          GestureDetector(
            onTap: _photoPanel.isOpen ? _photoPanel.close : null,
            onHorizontalDragStart:
                _photoPanel.isOpen ? (_) => _photoPanel.close() : null,
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
                    child: child,
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
              controller: _photoPanel,
              busy: _isAnalyzingPhoto,
              hidden: _drawerOpen,
              // Kept free for the floating-button row, and the RESTORE
              // SnackBar while it is up (spec AC-01).
              bottomReserve: 80 + (_restoreSnackBarVisible ? 56 : 0),
              scrollController: _listScroll,
              onSelected: _onPhotoSelected,
              onOpenNotes: _openNotes,
              notesPage: (id) => NotesScreen(selectedId: id, preview: true),
            ),
          ),
        ],
      ),
      // Both round buttons share the Scaffold's FAB slot, so the Scaffold moves
      // them together: above a snackbar, above the keyboard, above the bottom
      // safe area -- always on one line. A full-width row, centred, puts the
      // settings button bottom-left and the speed dial bottom-right (D9 (c) in
      // docs/roadmap.md), each 16px from its edge like endFloat's margin. The
      // gap between them is not hit-testable, so rows underneath stay tappable.
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _closesOpenPhotoPanel(Padding(
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
              backgroundColor: const Color(0xff954ef3), //const Color(0xff904ae6),
              foregroundColor: Colors.white,
              child: const Icon(Icons.settings),
            ),
            WordInputSpeedDial(
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
    final notifier = ref.read(wordInputNotifierProvider.notifier);
    final collection = ref.read(wordInputNotifierProvider).valueOrNull;
    if (!notifier.takeEditedElsewhere() || collection == null) return;
    _restoreFromStore(collection.words, focusLast: false);
  }

  /// The top bar, which an open photo panel owns like the rest of the screen
  /// (spec AC-11).
  PreferredSizeWidget _photoPanelGuardedAppBar(AppBar appBar) => PreferredSize(
        preferredSize: appBar.preferredSize,
        child: _closesOpenPhotoPanel(appBar),
      );
}
