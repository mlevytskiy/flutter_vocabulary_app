import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';

/// words-from-subtitles T6: the import option types and the one set of import
/// values in Settings with the "Update with each import" switch (data-model.md
/// Device preferences; sad §6 F2 and F3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SubtitleImportPrefs> readAfterLoad(ProviderContainer container) async {
    container.read(subtitleImportPrefsProvider);
    await container.read(subtitleImportPrefsProvider.notifier).loaded;
    return container.read(subtitleImportPrefsProvider);
  }

  ProviderContainer fresh([Map<String, Object> stored = const {}]) {
    SharedPreferences.setMockInitialValues(stored);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('option types', () {
    test('wire values match the contract', () {
      expect(ImportPurpose.values.map((p) => p.wire), ['understand_film', 'frequent_words']);
      expect(EnglishLevel.values.map((l) => l.wire), ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
      expect(SubtitleModel.values.map((m) => m.id),
          ['claude-sonnet-5', 'claude-sonnet-5-5', 'claude-haiku-4-5-20251001', 'claude-opus-5-5']);
    });

    test('labels are what the learner reads', () {
      expect(ImportPurpose.understandFilm.label, 'Understand this film');
      expect(ImportPurpose.frequentWords.label, 'Frequent words for the future');
      expect(SubtitleModel.haiku45.label, 'Haiku 4.5');
      expect(EnglishLevel.b2.label, 'B2');
    });

    test('the approximate cost comes from the dated price table', () {
      expect(SubtitleModel.pricesAsOf, '2026-09-25');
      // Sonnet 5: $2 in / $10 out per million tokens.
      expect(SubtitleModel.sonnet5.costUsd(inputTokens: 1000000, outputTokens: 100000), closeTo(3.0, 1e-9));
      expect(SubtitleModel.haiku45.costUsd(inputTokens: 31250, outputTokens: 2140), closeTo(0.04195, 1e-9));
      expect(SubtitleModel.opus55.costUsd(inputTokens: 1000000, outputTokens: 0), closeTo(4.0, 1e-9));
    });

    test('a model is found by its id, or not at all', () {
      expect(SubtitleModel.byId('claude-opus-5-5'), SubtitleModel.opus55);
      expect(SubtitleModel.byId('claude-fable-5-1'), isNull);
    });
  });

  test('first launch: understand this film, B2, 20, update on, Sonnet 5', () async {
    final prefs = await readAfterLoad(fresh());
    expect(prefs.purpose, ImportPurpose.understandFilm);
    expect(prefs.level, EnglishLevel.b2);
    expect(prefs.maximum, 20);
    expect(prefs.updateEachImport, isTrue);
    expect(prefs.model, SubtitleModel.sonnet5);
  });

  test('every setting survives a restart under its data-model key', () async {
    final first = fresh();
    await readAfterLoad(first);
    final n = first.read(subtitleImportPrefsProvider.notifier);
    await n.setPurpose(ImportPurpose.frequentWords);
    await n.setLevel(EnglishLevel.c1);
    expect(await n.setMaximum(35), isTrue);
    await n.setUpdateEachImport(false);
    await n.setModel(SubtitleModel.haiku45);

    final stored = await SharedPreferences.getInstance();
    expect(stored.getString('subtitle_purpose'), 'frequentWords');
    expect(stored.getString('subtitle_level'), 'C1');
    expect(stored.getInt('subtitle_maximum'), 35);
    expect(stored.getBool('subtitle_update_each_import'), isFalse);
    expect(stored.getString('subtitle_model'), 'haiku45');

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final prefs = await readAfterLoad(second);
    expect(prefs, const SubtitleImportPrefs(
      purpose: ImportPurpose.frequentWords,
      level: EnglishLevel.c1,
      maximum: 35,
      updateEachImport: false,
      model: SubtitleModel.haiku45,
    ));
  });

  test('a missing or unknown stored value falls back to its first-launch default', () async {
    final prefs = await readAfterLoad(fresh({
      'subtitle_purpose': 'everything',
      'subtitle_level': 'D1',
      'subtitle_maximum': 500,
      'subtitle_model': 'claude-3-opus',
    }));
    expect(prefs, SubtitleImportPrefs.firstLaunch);
  });

  test('a maximum outside 1–100 is refused and not saved', () async {
    final container = fresh();
    await readAfterLoad(container);
    final n = container.read(subtitleImportPrefsProvider.notifier);
    expect(await n.setMaximum(0), isFalse);
    expect(await n.setMaximum(101), isFalse);
    expect(container.read(subtitleImportPrefsProvider).maximum, 20);
    expect((await SharedPreferences.getInstance()).getInt('subtitle_maximum'), isNull);
    expect(await n.setMaximum(1), isTrue);
    expect(await n.setMaximum(100), isTrue);
  });

  test('recordUsed overwrites purpose, level and maximum only while Update with each import is on (AC-05, AC-05b)', () async {
    final container = fresh();
    await readAfterLoad(container);
    final n = container.read(subtitleImportPrefsProvider.notifier);

    await n.recordUsed(purpose: ImportPurpose.frequentWords, level: EnglishLevel.b1, maximum: 30);
    var prefs = container.read(subtitleImportPrefsProvider);
    expect([prefs.purpose, prefs.level, prefs.maximum], [ImportPurpose.frequentWords, EnglishLevel.b1, 30]);

    await n.setUpdateEachImport(false);
    await n.recordUsed(purpose: ImportPurpose.understandFilm, level: EnglishLevel.c2, maximum: 5);
    prefs = container.read(subtitleImportPrefsProvider);
    expect([prefs.purpose, prefs.level, prefs.maximum], [ImportPurpose.frequentWords, EnglishLevel.b1, 30]);
    expect(prefs.model, SubtitleModel.sonnet5, reason: 'recordUsed never touches the model');
  });
}
