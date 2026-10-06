// photo-from-gallery: the "Get words from photo" flow on the real
// WordInputScreen, with the image picker, the photo scaler, the Worker call
// and the kept-photo store faked (sad §6 flow 1).
//
// T4: the one-import-at-a-time guard, the source choice, Camera, and a closed
// choice. T5: the Gallery cases (pick, nothing picked, unusable photo, kept
// or dropped source photo) and the camera scaler text, on the same harness.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/vocab_word.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/photo_scaler.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';
import 'package:flutter_vocabulary_app/core/services/vocab_photo_service.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_screen.dart';

/// Records every pick; answers with [next] (a file, null for "closed", or an
/// error to throw).
class FakePicker extends ImagePicker {
  final sources = <ImageSource>[];
  final calls = <Map<String, Object?>>[];
  XFile? next = XFile('photo.jpg');
  Object? error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    calls.add({'source': source, 'requestFullMetadata': requestFullMetadata});
    if (error != null) throw error!;
    return next;
  }
}

/// Hands back fixed bytes, or throws [error] (an unreadable photo).
class FakeScaler implements PhotoScaler {
  final paths = <String>[];
  Object? error;

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> resizeFileToMinSide(String path,
      {int minSide = 640, int quality = 85}) async {
    paths.add(path);
    if (error != null) throw error!;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<Uint8List> keptCopy(String path) =>
      resizeFileToMinSide(path, minSide: 1600, quality: 80);
}

/// The Worker call, held open until the test completes [pending].
class FakeVocabPhotoService extends VocabPhotoService {
  final limits = <int?>[];
  Completer<VocabAnalysisResult>? pending;

  @override
  Future<VocabAnalysisResult> analyzePhoto(
    Uint8List imageBytes, {
    required String mediaType,
    bool translation = true,
    bool context = false,
    bool withDesc = false,
    bool shortifyDefinition = false,
    int? limit,
  }) {
    limits.add(limit);
    pending = Completer();
    return pending!.future;
  }
}

/// Keeps nothing on disk: file I/O would not finish inside the widget test's
/// fake-async zone. Records what it was asked to keep and delete.
class FakeSourcePhotoStore extends SourcePhotoStore {
  int kept = 0;
  final deleted = <SessionSource>[];

  @override
  Future<SessionSource?> keep(Uint8List bytes, {DateTime? takenAt}) async {
    kept++;
    return SessionSource()
      ..id = 'photo-$kept'
      ..fileName = 'photo-$kept.jpg'
      ..takenAt = takenAt ?? DateTime(2026);
  }

  @override
  Future<void> delete(SessionSource photo) async => deleted.add(photo);
}

VocabAnalysisResult result(List<String> words) => VocabAnalysisResult(
      words: [for (final w in words) VocabWord(word: w, translation: 'т-$w')],
      aiDuration: const Duration(seconds: 1),
    );

const stillAnalysing = 'The current photo is still being analysed';
const galleryUnusable =
    'The photo from the gallery could not be used. Try another one.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late SessionStore store;

  // One Isar store for the whole file (SessionStore.open reuses the 'vocab'
  // instance anyway), opened outside fake async because Isar needs real I/O.
  // The tests never write to it.
  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('photo_import_flow_test');
    store = await SessionStore.open(directory: dir.path);
    final session = Session.create()..words = [WordPair(word: 'harbour')];
    await store.put(session);
    await store.setCurrentSessionId(session.sessionId);
  });

  tearDownAll(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  late FakePicker picker;
  late FakeScaler scaler;
  late FakeVocabPhotoService worker;
  late FakeSourcePhotoStore photos;
  late ProviderContainer container;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The screen stops speech when it goes away; there is no TTS plugin here.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_tts'), (_) async => null);
    picker = FakePicker();
    scaler = FakeScaler();
    worker = FakeVocabPhotoService();
    photos = FakeSourcePhotoStore();
    container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((ref) async => store),
      imagePickerProvider.overrideWithValue(picker),
      photoScalerProvider.overrideWithValue(scaler),
      vocabPhotoServiceProvider.overrideWithValue(worker),
      sourcePhotoStoreProvider.overrideWithValue(photos),
    ]);
    await tester
        .runAsync(() => container.read(wordInputNotifierProvider.future));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WordInputScreen()),
    ));
    await tester.pump();
  }

  /// Unmounts the screen (its dispose() still reads providers) and disposes
  /// the container, which cancels the notifier's debounced save timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  List<String> sessionWords() => [
        for (final p in container.read(wordInputNotifierProvider).value!.words)
          p.word
      ];

  /// Opens the speed dial and taps "Get words from photo".
  Future<void> tapGetWordsFromPhoto(WidgetTester tester) async {
    // Fixed pumps, not pumpAndSettle: the analysing overlay's spinner never
    // settles.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Get words from photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> choose(WidgetTester tester, String source) async {
    await tester.tap(find.text(source));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  final sourceChoice = find.byType(SimpleDialog);
  final resultsDialog = find.byType(AlertDialog);

  SessionSnapshot snapshot() {
    final s = container.read(wordInputNotifierProvider).value!;
    return SessionSnapshot(
      [for (final p in s.words) p.word],
      [for (final p in s.words) p.sourceId],
      [for (final p in s.sources) p.id],
    );
  }

  /// Gallery, then the Worker answers with [words] and the results dialog
  /// opens.
  Future<void> pickFromGalleryAndAnswer(
      WidgetTester tester, List<String> words) async {
    picker.next = XFile('page.jpg');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');
    expect(worker.limits, [20]);
    worker.pending!.complete(result(words));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(resultsDialog, findsOneWidget);
  }

  Future<void> settleDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a tap opens the source choice and nothing else (AC-01)',
      (tester) async {
    await pumpScreen(tester);
    await tapGetWordsFromPhoto(tester);

    expect(sourceChoice, findsOneWidget);
    expect(find.descendant(of: sourceChoice, matching: find.text('Camera')),
        findsOneWidget);
    expect(find.descendant(of: sourceChoice, matching: find.text('Gallery')),
        findsOneWidget);
    expect(picker.sources, isEmpty);
    expect(worker.limits, isEmpty);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'closing the choice: no message, no picker, session unchanged (AC-05)',
      (tester) async {
    await pumpScreen(tester);
    final before = sessionWords();
    await tapGetWordsFromPhoto(tester);
    expect(sourceChoice, findsOneWidget);

    // Tap outside the dialog, on the barrier.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(sourceChoice, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(picker.sources, isEmpty);
    expect(worker.limits, isEmpty);
    expect(sessionWords(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'Camera opens the camera and the shot reaches analyzePhoto(limit: 20) '
      '(AC-02)', (tester) async {
    await pumpScreen(tester);
    picker.next = XFile('shot.jpg');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Camera');

    expect(sourceChoice, findsNothing);
    expect(picker.sources, [ImageSource.camera]);
    expect(scaler.paths.first, 'shot.jpg');
    expect(worker.limits, [20]);
    expect(find.text('Analyzing photo...'), findsOneWidget);

    worker.pending!.complete(result(['reluctant']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Analyzing photo...'), findsNothing);
    expect(find.text('reluctant'), findsWidgets);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'while a photo is analysed, a second tap opens nothing and says so '
      '(AC-10)', (tester) async {
    await pumpScreen(tester);
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Camera');
    expect(worker.limits, [20], reason: 'the first import is analysing');
    expect(find.text('Analyzing photo...'), findsOneWidget);

    await tapGetWordsFromPhoto(tester);

    expect(sourceChoice, findsNothing);
    expect(find.text(stillAnalysing), findsOneWidget);
    expect(picker.sources, [ImageSource.camera], reason: 'no second pick');
    expect(worker.limits, [20], reason: 'no second import');

    worker.pending!.completeError(VocabPhotoException('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  // ---- T5: Gallery ----

  testWidgets(
      'a gallery photo reaches analyzePhoto(limit: 20) and Done keeps its words '
      'with the photo as their source, as for the camera (AC-03, AC-04)',
      (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    picker.next = XFile('page.jpg');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    expect(sourceChoice, findsNothing);
    expect(picker.sources, [ImageSource.gallery]);
    expect(scaler.paths.first, 'page.jpg');
    expect(worker.limits, [20]);
    expect(find.text('Analyzing photo...'), findsOneWidget);

    worker.pending!.complete(result(['reluctant', 'candid']));
    await settleDialog(tester);
    expect(find.text('Analyzing photo...'), findsNothing);
    expect(resultsDialog, findsOneWidget);
    expect(
        find.descendant(of: resultsDialog, matching: find.text('reluctant')),
        findsOneWidget);

    await tester.tap(find.text('Done'));
    await settleDialog(tester);

    final after = snapshot();
    expect(after.sources, [...before.sources, 'photo-1']);
    expect(after.words, containsAll(['reluctant', 'candid']));
    for (final w in ['reluctant', 'candid']) {
      expect(after.sourceIds[after.words.indexOf(w)], 'photo-1',
          reason: '$w points at the gallery photo');
    }
    expect(photos.kept, 1);
    expect(photos.deleted, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the gallery pick asks for no metadata (AC-09)', (tester) async {
    await pumpScreen(tester);
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    expect(picker.calls, [
      {'source': ImageSource.gallery, 'requestFullMetadata': false},
    ]);
    worker.pending!.completeError(VocabPhotoException('offline'));
    await settleDialog(tester);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'removing every word from a gallery photo keeps no source photo (AC-11)',
      (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    await pickFromGalleryAndAnswer(tester, ['reluctant']);

    await tester.tap(find.descendant(
        of: resultsDialog, matching: find.byTooltip('Skip this word')));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await settleDialog(tester);

    expect(resultsDialog, findsNothing);
    expect(photos.deleted.map((p) => p.id), ['photo-1']);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'cancelling the results dialog of a gallery photo keeps no source photo '
      '(AC-11)', (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    await pickFromGalleryAndAnswer(tester, ['reluctant']);

    // Tap outside the dialog, on the barrier.
    await tester.tapAt(const Offset(10, 10));
    await settleDialog(tester);

    expect(resultsDialog, findsNothing);
    expect(photos.deleted.map((p) => p.id), ['photo-1']);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'nothing picked says "No photo was picked", never the camera, and '
      'changes nothing (AC-06)', (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    picker.next = null;
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    expect(picker.sources, [ImageSource.gallery]);
    expect(find.text('No photo was picked'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(SnackBar),
            matching:
                find.textContaining(RegExp('camera|taken', caseSensitive: false))),
        findsNothing);
    expect(worker.limits, isEmpty);
    expect(photos.kept, 0);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'a throwing gallery picker shows the gallery text, adds nothing and '
      'keeps no photo (AC-07)', (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    picker.error = PlatformException(code: 'invalid_image');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    expect(find.text(galleryUnusable), findsOneWidget);
    expect(find.textContaining('camera'), findsNothing);
    expect(worker.limits, isEmpty);
    expect(photos.kept, 0);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'a gallery photo the scaler cannot read shows the gallery text, adds '
      'nothing and keeps no photo (AC-07, AC-08)', (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    scaler.error = Exception('cannot decode');
    picker.next = XFile('tall.png');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    expect(scaler.paths, ['tall.png']);
    expect(find.text(galleryUnusable), findsOneWidget);
    expect(find.textContaining('Error analyzing photo'), findsNothing);
    expect(find.text('Analyzing photo...'), findsNothing);
    expect(worker.limits, isEmpty);
    expect(photos.kept, 0);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'a Worker failure on a gallery photo keeps its own message and deletes '
      'the kept copy (sad §4)', (tester) async {
    await pumpScreen(tester);
    final before = snapshot();
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Gallery');

    worker.pending!.completeError(VocabPhotoException('No connection'));
    await settleDialog(tester);

    expect(find.text('No connection'), findsOneWidget);
    expect(find.text(galleryUnusable), findsNothing);
    expect(photos.deleted.map((p) => p.id), ['photo-1']);
    expect(snapshot(), before);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets(
      'a camera photo the scaler cannot read still says "Error analyzing '
      'photo" (camera texts unchanged)', (tester) async {
    await pumpScreen(tester);
    scaler.error = Exception('cannot decode');
    await tapGetWordsFromPhoto(tester);
    await choose(tester, 'Camera');

    expect(find.text('Error analyzing photo: Exception: cannot decode'),
        findsOneWidget);
    expect(find.text(galleryUnusable), findsNothing);
    await unmount(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

/// What a test compares before and after an import: the session's words, the
/// source each row points at, and the session's source photos.
class SessionSnapshot {
  SessionSnapshot(this.words, this.sourceIds, this.sources);
  final List<String> words;
  final List<String?> sourceIds;
  final List<String> sources;

  @override
  bool operator ==(Object other) =>
      other is SessionSnapshot &&
      _eq(words, other.words) &&
      _eq(sourceIds, other.sourceIds) &&
      _eq(sources, other.sources);

  @override
  int get hashCode => Object.hashAll([...words, ...sourceIds, ...sources]);

  @override
  String toString() => 'words=$words sourceIds=$sourceIds sources=$sources';

  static bool _eq(List<Object?> a, List<Object?> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
}
