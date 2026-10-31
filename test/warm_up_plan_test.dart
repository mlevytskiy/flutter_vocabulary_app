import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/services/learner_profile_store.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/grammar_rules.dart';
import 'package:flutter_vocabulary_app/features/learn/flow/warm_up_plan.dart';

void main() {
  const withLevel = LearnerProfile(level: 'Intermediate');

  WarmUpPlan plan(LearnerProfile p, {bool limit = false, int seed = 1}) =>
      planWarmUp(profile: p, talkLimitReached: limit, random: Random(seed));

  group('steps', () {
    test('AC-01 no level: intro first, then main, topic, Hard/Easy (4)', () {
      final p = plan(const LearnerProfile());
      expect(p.steps, [WarmUpStep.intro, WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy]);
    });

    test('AC-02 intro and grammar never come together, grammar waits', () {
      final p = plan(const LearnerProfile(grammarCounter: 7));
      expect(p.steps.contains(WarmUpStep.intro), isTrue);
      expect(p.steps.contains(WarmUpStep.grammar), isFalse);
    });

    test('AC-02 a level, including Not sure, skips the intro', () {
      for (final l in ['Beginner', 'Not sure']) {
        expect(plan(LearnerProfile(level: l)).steps, [WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy]);
      }
    });

    test('AC-07 grammar comes at counter 4 or more, after main', () {
      expect(plan(const LearnerProfile(level: 'Advanced', grammarCounter: 3)).steps.length, 3);
      final p = plan(const LearnerProfile(level: 'Advanced', grammarCounter: 4));
      expect(p.steps, [WarmUpStep.main, WarmUpStep.grammar, WarmUpStep.topic, WarmUpStep.hardEasy]);
      expect(plan(const LearnerProfile(level: 'Advanced', grammarCounter: 9)).steps.length, 4);
    });

    test('AC-08 talk limit reached: no grammar step', () {
      final p = plan(const LearnerProfile(level: 'Advanced', grammarCounter: 5), limit: true);
      expect(p.steps, [WarmUpStep.main, WarmUpStep.topic, WarmUpStep.hardEasy]);
    });

    test('AC-06 always 3 or 4 steps', () {
      for (final level in [null, ...learnerLevels]) {
        for (final c in [0, 4]) {
          for (final limit in [false, true]) {
            final n = plan(LearnerProfile(level: level, grammarCounter: c), limit: limit).steps.length;
            expect(n, anyOf(3, 4));
          }
        }
      }
    });
  });

  group('main question round (AC-03)', () {
    test('a new round holds the three questions in some order', () {
      final p = plan(withLevel);
      expect(p.round.toSet(), MainQuestion.values.map((q) => q.name).toSet());
      expect(p.round.length, 3);
      expect(p.main.name, p.round.first);
    });

    test('a stored round is kept: its first question comes next', () {
      final p = plan(const LearnerProfile(level: 'Beginner', round: ['daily', 'mood']));
      expect(p.main, MainQuestion.daily);
      expect(p.round, ['daily', 'mood']);
    });

    test('three rounds never repeat a question inside a round', () {
      var round = <String>[];
      final seen = <String>[];
      for (var i = 0; i < 9; i++) {
        final p = plan(LearnerProfile(level: 'Beginner', round: round), seed: i);
        seen.add(p.main.name);
        round = p.round.where((q) => q != p.main.name).toList();
      }
      for (var r = 0; r < 3; r++) {
        expect(seen.sublist(r * 3, r * 3 + 3).toSet().length, 3);
      }
    });

    test('an unknown id in a stored round starts a new round', () {
      final p = plan(const LearnerProfile(level: 'Beginner', round: ['old']));
      expect(p.round.length, 3);
    });
  });

  group('grammar rules (AC-07)', () {
    test('15 rules in 3 lists of 5', () {
      expect(grammarRulesElementary.length, 5);
      expect(grammarRulesIntermediate.length, 5);
      expect(grammarRulesUpper.length, 5);
      expect({...grammarRulesElementary, ...grammarRulesIntermediate, ...grammarRulesUpper}.length, 15);
    });

    test('4 distinct rules from the level list', () {
      for (final l in ['Elementary', 'Intermediate', 'Upper-intermediate', 'Advanced']) {
        final pick = pickGrammarRules(l, Random(3));
        expect(pick.length, 4);
        expect(pick.toSet().length, 4);
        expect(grammarRulesForLevel(l).toSet().containsAll(pick), isTrue);
      }
    });

    test('Beginner uses Elementary; Not sure uses Elementary + Intermediate', () {
      expect(grammarRulesForLevel('Beginner'), grammarRulesElementary);
      expect(grammarRulesForLevel('Not sure'), [...grammarRulesElementary, ...grammarRulesIntermediate]);
      expect(grammarRulesForLevel('Advanced'), grammarRulesUpper);
      expect(grammarRulesForLevel('Upper-intermediate'), grammarRulesUpper);
    });

    test('seeded random gives the same pick', () {
      expect(pickGrammarRules('Intermediate', Random(5)), pickGrammarRules('Intermediate', Random(5)));
    });

    test('counter: +1 per finished warm-up, 0 after an answered grammar question', () {
      expect(nextGrammarCounter(counter: 2, grammarAnswered: false), 3);
      expect(nextGrammarCounter(counter: 4, grammarAnswered: true), 0);
      var c = 0;
      final due = <int>[];
      for (var i = 1; i <= 10; i++) {
        final isDue = c >= 4;
        if (isDue) due.add(i);
        c = nextGrammarCounter(counter: c, grammarAnswered: isDue);
      }
      expect(due, [5, 10]);
    });
  });
}
