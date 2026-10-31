import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('AC-04 empty store reads as an empty profile', () async {
    final p = await LearnerProfileStore().read();
    expect(p.level, isNull);
    expect(p.goal, isNull);
    expect(p.daily, isNull);
    expect(p.round, isEmpty);
    expect(p.grammarCounter, 0);
    expect(p.talksCounter, 0);
  });

  test('a bad stored value reads as empty', () async {
    for (final bad in ['not json', '[1,2]', '{"v":99,"level":"Advanced"}', '{"v":1,"level":5}']) {
      SharedPreferences.setMockInitialValues({LearnerProfileStore.key: bad});
      final p = await LearnerProfileStore().read();
      expect(p.level, isNull, reason: bad);
    }
  });

  test('values survive a new store (one versioned JSON value)', () async {
    final s = LearnerProfileStore();
    await s.setLevel('Advanced');
    await s.setGoal('Travel confidently');
    await s.setDaily('Working');
    await s.setRound(['a', 'b']);
    await s.setGrammarCounter(3);
    await s.setTalksCounter(2);
    final p = await LearnerProfileStore().read();
    expect([p.level, p.goal, p.daily], ['Advanced', 'Travel confidently', 'Working']);
    expect(p.round, ['a', 'b']);
    expect([p.grammarCounter, p.talksCounter], [3, 2]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {LearnerProfileStore.key});
  });

  test('AC-04 answers of 1-2 characters are saved only into an empty field', () async {
    final s = LearnerProfileStore();
    await s.saveGoalAnswer('no');
    expect((await s.read()).goal, 'no');
    await s.saveGoalAnswer('Make friends');
    await s.saveGoalAnswer('ok');
    expect((await s.read()).goal, 'Make friends');
    await s.saveDailyAnswer('  Studying ');
    expect((await s.read()).daily, 'Studying');
    await s.saveDailyAnswer('x');
    expect((await s.read()).daily, 'Studying');
  });

  test('AC-04 empty or over 80 characters is never saved', () async {
    final s = LearnerProfileStore();
    await s.saveGoalAnswer('   ');
    await s.saveGoalAnswer('x' * 81);
    expect((await s.read()).goal, isNull);
    await s.saveGoalAnswer('y' * 80);
    expect((await s.read()).goal, 'y' * 80);
  });

  test('AC-03 clearing a field keeps the round and the counters', () async {
    final s = LearnerProfileStore();
    await s.setLevel('Beginner');
    await s.setGoal('Make friends');
    await s.setDaily('Working');
    await s.setRound(['b']);
    await s.setGrammarCounter(4);
    await s.setTalksCounter(1);
    await s.setLevel(null);
    await s.setGoal(null);
    await s.setDaily(null);
    final p = await s.read();
    expect([p.level, p.goal, p.daily], [null, null, null]);
    expect(p.round, ['b']);
    expect([p.grammarCounter, p.talksCounter], [4, 1]);
  });

  test('AC-03 markMainAnswered drops the question from the round', () async {
    final s = LearnerProfileStore();
    await s.setRound(['a', 'b', 'c']);
    await s.markMainAnswered('a');
    expect((await s.read()).round, ['b', 'c']);
    await s.markMainAnswered('zzz');
    expect((await s.read()).round, ['b', 'c']);
  });
}
