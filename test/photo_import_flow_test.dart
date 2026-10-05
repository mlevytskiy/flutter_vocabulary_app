// photo-from-gallery: the "Get words from photo" flow on the real
// WordInputScreen, with the image picker, the photo scaler, the Worker call
// and the kept-photo store faked (sad §6 flow 1).
//
// T4: the one-import-at-a-time guard, the source choice, Camera, and a closed
// choice. T5 adds the Gallery cases to this file, reusing the same harness.
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
import 'package:flutter_vocabulary_app/core/models/source_photo.dart';
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
  final deleted = <SourcePhoto>[];

  @override
  Future<SourcePhoto?> keep(Uint8List bytes, {DateTime? takenAt}) async {
    kept++;
    return SourcePhoto()
      ..id = 'photo-$kept'
      ..fileName = 'photo-$kept.jpg'
      ..takenAt = takenAt ?? DateTime(2026);
  }

  @override
  Future<void> delete(SourcePhoto photo) async => deleted.add(photo);
}

VocabAnalysisResult result(List<String> words) => VocabAnalysisResult(
      words: [for (final w in words) VocabWord(word: w, translation: 'т-$w')],
      aiDuration: const Duration(seconds: 1),
    );

const stillAnalysing = 'The current photo is still being analysed';

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
}
