import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// One warm-up or talk count for `POST /learn/events` (learn-warm-up-v2
/// AC-17): a name from the Worker's fixed list (`EVENT_SCHEMA` in
/// `vocab-photo-api/src/learn/events.ts`) with a fixed value or a whole
/// number, never words. Built only through the named constructors.
@immutable
class LearnEvent {
  /// The warm-up steps an event can name.
  static const steps = {
    'intro',
    'mood',
    'goal',
    'daily',
    'grammar',
    'topic',
    'difficulty',
  };
  static const maxN = 1000;

  final String name;
  final String? value;
  final int? n;

  const LearnEvent._(this.name, {this.value, this.n});

  /// A warm-up step shown; [step] is one of [steps].
  const LearnEvent.warmUpShown(String step)
      : this._('warm_up_shown', value: step);

  /// A warm-up step answered; [step] is one of [steps].
  const LearnEvent.warmUpAnswered(String step)
      : this._('warm_up_answered', value: step);

  /// The warm-up left at [step] (one of [steps]).
  const LearnEvent.warmUpLeft(String step)
      : this._('warm_up_left', value: step);

  /// The warm-up finished with [answered] steps answered.
  const LearnEvent.warmUpFinished(int answered)
      : this._('warm_up_finished', n: answered);

  /// The grammar question answered with a rule or "No, just talk".
  const LearnEvent.grammarAnswer({required bool rule})
      : this._('grammar_answer', value: rule ? 'rule' : 'none');

  /// A suggested topic or the learner's own topic picked.
  const LearnEvent.topicPicked({required bool own})
      : this._('topic_picked', value: own ? 'own' : 'suggested');

  /// The talk finished or ended early.
  const LearnEvent.talkEnd({required bool finished})
      : this._('talk_end', value: finished ? 'finished' : 'ended');

  /// Another talk started from the results page.
  const LearnEvent.talkAgain() : this._('talk_again');

  /// "Was this talk interesting?" answered with 👍 or 👎.
  const LearnEvent.talkRating({required bool up})
      : this._('talk_rating', value: up ? 'up' : 'down');

  /// Whether the Worker accepts it: a step off the list or a number out of
  /// range would reject the whole batch there.
  bool get isValid {
    if (name.startsWith('warm_up_') && name != 'warm_up_finished') {
      return steps.contains(value);
    }
    if (name == 'warm_up_finished') return n != null && n! >= 0 && n! <= maxN;
    return true;
  }

  Map<String, Object> toJson() => {
        'name': name,
        if (value != null) 'value': value!,
        if (n != null) 'n': n!,
      };

  @override
  bool operator ==(Object other) =>
      other is LearnEvent &&
      other.name == name &&
      other.value == value &&
      other.n == n;

  @override
  int get hashCode => Object.hash(name, value, n);

  @override
  String toString() => 'LearnEvent(${toJson()})';
}

/// The Worker's `POST /learn/events` (learn-warm-up-v2 AC-17, ADR-0007):
/// fire-and-forget batches of at most 20 fixed events. Events the Worker
/// would refuse are dropped here so they cannot sink the batch. Never throws;
/// callers need not await it.
class LearnEventsService {
  static const maxBatch = 20;

  final http.Client _client;

  LearnEventsService({http.Client? client})
      : _client = client ?? http.Client();

  Future<void> send(List<LearnEvent> events) async {
    final valid = [
      for (final e in events)
        if (e.isValid) e,
    ];
    for (var i = 0; i < valid.length; i += maxBatch) {
      final batch = valid.sublist(i, min(i + maxBatch, valid.length));
      try {
        final response = await _client.post(
          Uri.parse('${VocabApiConfig.baseUrl}/learn/events'),
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'x-app-secret': VocabApiConfig.appSecret,
          },
          body: jsonEncode({
            'events': [for (final e in batch) e.toJson()]
          }),
        );
        if (response.statusCode != 200) {
          debugPrint('VOCAB: /learn/events: status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('VOCAB: /learn/events failed: ${e.runtimeType}');
      }
    }
  }
}
