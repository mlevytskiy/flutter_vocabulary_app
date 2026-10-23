import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/features/learn/entry/learn_presets.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

Future<LearnSettingsNotifier> _settings(ProviderContainer c) async {
  final n = c.read(learnSettingsNotifierProvider.notifier);
  await n.loaded;
  return n;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pure: 11 page exercises, presets, presetFor, canTurnOff', () {
    expect(pageExerciseIds.length, 11);
    expect(pageExerciseIds, isNot(contains('mnemonic-story')));
    expect(pageExerciseIds, isNot(contains('dialogs-from-movie')));
    expect(presetExercises(LearnPreset.quick).length, 6);
    expect(presetExercises(LearnPreset.balanced).length, 10);
    expect(presetExercises(LearnPreset.deep), pageExerciseIds.toSet());
    for (final p in [LearnPreset.quick, LearnPreset.balanced, LearnPreset.deep]) {
      expect(presetFor(presetExercises(p)), p);
    }
    expect(presetFor({'quiz'}), LearnPreset.custom);
    expect(canTurnOff({'quiz'}, 'quiz'), isFalse);
    expect(LearnPreset.quick.subtitle, 'about 5 min, one-word answers only');
  });

  test('defaults: Balanced, its 10 exercises, all words', () async {
    final c = _container();
    await _settings(c);
    final s = c.read(learnSettingsNotifierProvider);
    expect(s.preset, LearnPreset.balanced);
    expect(s.enabled, presetExercises(LearnPreset.balanced));
    expect(s.wordsPerSession, WordsPerSession.all);
  });

  test('preset switches the set; a switch change gives Custom or a match',
      () async {
    final c = _container();
    final n = await _settings(c);
    await n.pickPreset(LearnPreset.quick);
    expect(c.read(learnSettingsNotifierProvider).enabled,
        presetExercises(LearnPreset.quick));
    expect(await n.setEnabled('guess-my-word', true), isTrue);
    expect(c.read(learnSettingsNotifierProvider).preset, LearnPreset.custom);
    expect(await n.setEnabled('guess-my-word', false), isTrue);
    expect(c.read(learnSettingsNotifierProvider).preset, LearnPreset.quick);
    await n.pickPreset(LearnPreset.deep);
    expect(c.read(learnSettingsNotifierProvider).enabled.length, 11);
  });

  test('the last switch of a step is refused', () async {
    final c = _container();
    final n = await _settings(c);
    // Step 3 in Quick holds only the quiz.
    await n.pickPreset(LearnPreset.quick);
    expect(await n.setEnabled('quiz', false), isFalse);
    expect(c.read(learnSettingsNotifierProvider).enabled, contains('quiz'));
    expect(c.read(learnSettingsNotifierProvider).preset, LearnPreset.quick);
  });

  test('settings persist across a new container', () async {
    final c1 = _container();
    final n = await _settings(c1);
    await n.pickPreset(LearnPreset.quick);
    await n.setEnabled('guess-my-word', true);
    await n.setWordsPerSession(WordsPerSession.twenty);
    final c2 = _container();
    await _settings(c2);
    final s = c2.read(learnSettingsNotifierProvider);
    expect(s.preset, LearnPreset.custom);
    expect(s.enabled, contains('guess-my-word'));
    expect(s.wordsPerSession, WordsPerSession.twenty);
  });

  test('split defaults true per collection and is remembered', () async {
    final c1 = _container();
    expect(c1.read(learnSplitNotifierProvider('a')), isTrue);
    await c1.read(learnSplitNotifierProvider('a').notifier).set(false);
    expect(c1.read(learnSplitNotifierProvider('b')), isTrue);
    final c2 = _container();
    final n = c2.read(learnSplitNotifierProvider('a').notifier);
    await n.loaded;
    expect(c2.read(learnSplitNotifierProvider('a')), isFalse);
    expect(c2.read(learnSplitNotifierProvider('b')), isTrue);
  });

  test('last group is stored per collection', () async {
    final c1 = _container();
    expect(c1.read(learnLastGroupNotifierProvider('a')), isNull);
    await c1.read(learnLastGroupNotifierProvider('a').notifier).set(2);
    final c2 = _container();
    final n = c2.read(learnLastGroupNotifierProvider('a').notifier);
    await n.loaded;
    expect(c2.read(learnLastGroupNotifierProvider('a')), 2);
    expect(c2.read(learnLastGroupNotifierProvider('b')), isNull);
  });
}
