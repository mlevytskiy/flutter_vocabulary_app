import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_topics_service.dart';
import '../../../core/services/learner_profile_store.dart';
import '../../../core/services/speech_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../entry/learner_profile_section.dart' show learnerTextTooLong;
import '../talk/talk_widgets.dart';
import 'flow_words.dart';
import 'learn_flow_notifier.dart';
import 'warm_up_plan.dart';

/// The warm-up's lines and choices (learn-welcome AC-02, AC-04;
/// learn-warm-up-v2 AC-01, AC-03, AC-04, AC-07).
String warmUpTopicQuestion(int words) =>
    'Hi! $words ${words == 1 ? 'word' : 'words'} today. What would you like to talk about?';
const warmUpLevelQuestion = "What's your English level?";
const warmUpMainQuestions = <MainQuestion, String>{
  MainQuestion.mood: 'What sounds good today: something useful, a little mystery, or a friendly argument?',
  MainQuestion.goal: 'What would you love to be able to do comfortably in English?',
  MainQuestion.daily: 'What do you spend most of your day doing: working, studying, or something else?',
};
const warmUpGrammarQuestion = 'Would you like to focus on a grammar rule in this talk?';
const warmUpSomethingElse = 'Something else';
const warmUpTooLong = learnerTextTooLong;
const warmUpModeQuestion = 'Ready to work hard, or easy mode today?';
const warmUpOwnTopicChoice = 'My own topic…';
const warmUpHardChoice = 'Hard · longer talk';
const warmUpEasyChoice = 'Easy · shorter talk';
const warmUpOwnTopicHint = 'Type or say your topic…';
const warmUpOwnAnswerHint = 'Type or say your answer…';
const warmUpTitle = 'Talk with AI';

/// Keys the tests and the flow screen find the warm-up by.
ValueKey<String> warmUpStepKey(int step) => ValueKey('warm-up-step-$step');
const warmUpTopicsLoadingKey = ValueKey('warm-up-topics-loading');
const warmUpReactingKey = ValueKey('warm-up-reacting');
const warmUpOwnTopicFieldKey = ValueKey('warm-up-own-topic-field');
const warmUpSendKey = ValueKey('warm-up-send');
const warmUpMicKey = ValueKey('warm-up-mic');
const warmUpSettingsKey = ValueKey('warm-up-settings');

/// The warm-up of the Learn flow as a dialog (learn-welcome AC-02, AC-04;
/// learn-warm-up-v2 AC-01, AC-03, AC-04, AC-06, AC-07, AC-13): the Talk
/// screen's look — AI bubbles, the learner's answers, tap choices — walking
/// the steps of [LearnFlowState.plan] under one bar of 3 or 4 steps: the
/// level intro, the main question (goal and daily also in own words through
/// "Something else"), the grammar question, the topics with their situation
/// lines and "My own topic…", then Hard or Easy. Each reaction shows as an
/// AI line before the next step. No Skip.
///
/// This is the body only: the flow screen puts it in its Scaffold's body
/// with [WarmUpView.appBar] (title and the gear to Learn settings) as the
/// Scaffold's appBar.
class WarmUpView extends ConsumerStatefulWidget {
  const WarmUpView({super.key, required this.collectionId});

  final String collectionId;

  /// The warm-up's top bar: the Talk screen's title and a gear opening
  /// Learn settings (AC-02, AC-17).
  static PreferredSizeWidget appBar(BuildContext context, {required String collectionId}) => AppBar(
        title: const Text(warmUpTitle),
        actions: [
          IconButton(
            key: warmUpSettingsKey,
            tooltip: 'Learn settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => LearnSettingsRoute(collectionId: collectionId).push(context),
          ),
        ],
      );

  @override
  ConsumerState<WarmUpView> createState() => _WarmUpViewState();
}

class _WarmUpViewState extends ConsumerState<WarmUpView> {
  final _field = TextEditingController();
  final _scroll = ScrollController();

  /// The step whose own-words composer is open ("Something else" on the
  /// main question, "My own topic…" on the topic step); null when closed.
  WarmUpStep? _own;

  SpeechInput? _speech;
  bool _listening = false;
  SpeechAvailability? _availability;

  @override
  void dispose() {
    if (_listening) _speech?.cancel();
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  LearnFlow get _flow => ref.read(learnFlowProvider(widget.collectionId).notifier);

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _speech?.stop();
    if (mounted) setState(() => _listening = false);
  }

  void _chooseTopic(LearnTopic topic) {
    _stopListening();
    setState(() => _own = null);
    _flow.chooseTopic(topic);
  }

  void _openOwn(WarmUpStep step) {
    setState(() => _own = step);
    _scrollToEnd();
  }

  Future<void> _send() async {
    final step = _own;
    await _stopListening();
    final text = _field.text;
    final sent = step == WarmUpStep.main ? _flow.answerMain(text, own: true) : _flow.ownTopic(text);
    if (!sent || !mounted) return;
    _field.clear();
    setState(() => _own = null);
  }

  /// Tap to speak, tap again to stop: what is heard fills the field.
  Future<void> _micTap() async {
    if (_listening) return _stopListening();
    final speech = _speech ??= ref.read<SpeechInput>(speechInputProvider);
    if (_availability != SpeechAvailability.ready) {
      final found = await speech.init();
      if (!mounted) return;
      setState(() => _availability = found);
      if (found != SpeechAvailability.ready) return;
    }
    setState(() => _listening = true);
    await speech.listen(onText: (text, _) {
      if (mounted) _field.text = text;
    });
  }

  /// Own words on the main question: 1–80 characters once trimmed (AC-04).
  static bool _tooLong(WarmUpStep? step, String text) =>
      step == WarmUpStep.main && text.trim().length > learnerTextMax;

  static bool _sendable(WarmUpStep? step, String text) => step == WarmUpStep.main
      ? text.trim().isNotEmpty && !_tooLong(step, text)
      : text.trim().isNotEmpty && text.length <= maxOwnTopicLength;

  String _question(WarmUpStep step, LearnFlowState s) => switch (step) {
        WarmUpStep.intro => warmUpLevelQuestion,
        WarmUpStep.main => warmUpMainQuestions[s.plan!.main]!,
        WarmUpStep.grammar => warmUpGrammarQuestion,
        WarmUpStep.topic => warmUpTopicQuestion(s.words.length),
        WarmUpStep.hardEasy => warmUpModeQuestion,
      };

  /// The taps of the step being asked.
  List<Widget> _choices(WarmUpStep step, LearnFlowState s, double maxWidth) {
    TalkChoiceButton tap(String choice, VoidCallback? onPressed, {String? detail}) =>
        TalkChoiceButton(choice: choice, detail: detail, onPressed: onPressed);
    switch (step) {
      case WarmUpStep.intro:
        return [for (final level in learnerLevels) tap(level, () => _flow.answerLevel(level))];
      case WarmUpStep.main:
        final main = s.plan!.main;
        return [
          for (final c in switch (main) {
            MainQuestion.mood => moodChoices.keys,
            MainQuestion.goal => goalChoices,
            MainQuestion.daily => dailyChoices,
          })
            tap(c, () => _flow.answerMain(c)),
          if (main != MainQuestion.mood)
            tap(warmUpSomethingElse, _own == step ? null : () => _openOwn(step)),
        ];
      case WarmUpStep.grammar:
        return [
          for (final rule in s.grammarRules) tap(rule, () => _flow.answerGrammar(rule)),
          tap(noGrammarAnswer, () => _flow.answerGrammar(null)),
        ];
      case WarmUpStep.topic:
        final topics = s.topics;
        if (topics == null) {
          return [TalkBubble(key: warmUpTopicsLoadingKey, index: -1, text: '…', mine: false, maxWidth: maxWidth)];
        }
        return [
          for (final t in topics)
            tap(t.title, () => _chooseTopic(t),
                detail: t.situation.isNotEmpty ? t.situation : (t.description.isEmpty ? null : t.description)),
          tap(warmUpOwnTopicChoice, _own == step ? null : () => _openOwn(step)),
        ];
      case WarmUpStep.hardEasy:
        return [
          tap(warmUpHardChoice, () => _flow.chooseMode(FlowMode.hard)),
          tap(warmUpEasyChoice, () => _flow.chooseMode(FlowMode.easy)),
        ];
    }
  }

  /// The dialog so far: each step's question, the answer, its reaction (or
  /// a waiting bubble), and the taps of the step being asked.
  List<Widget> _dialog(LearnFlowState s, double maxWidth) {
    final plan = s.plan;
    if (s.phase == FlowPhase.loading || plan == null) {
      return [TalkBubble(key: warmUpTopicsLoadingKey, index: -1, text: '…', mine: false, maxWidth: maxWidth)];
    }
    var index = 0;
    TalkBubble bubble(String text, {bool mine = false, Key? key}) =>
        TalkBubble(key: key, index: key == null ? index++ : -1, text: text, mine: mine, maxWidth: maxWidth);
    return [
      for (var i = 0; i <= s.stepIndex && i < plan.steps.length; i++)
        ...() {
          final step = plan.steps[i];
          final current = i == s.stepIndex;
          final answer = s.answers[step];
          final reaction = s.reactions[step];
          return [
            bubble(_question(step, s)),
            if (answer != null && step != WarmUpStep.hardEasy) bubble(answer, mine: true),
            if (reaction != null)
              bubble(reaction)
            else if (current && answer != null && s.reacting)
              bubble('…', key: warmUpReactingKey),
            if (current && answer == null) ...[const SizedBox(height: 8), ..._choices(step, s, maxWidth)],
          ];
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(learnFlowProvider(widget.collectionId), (_, __) => _scrollToEnd());
    final s = ref.watch(learnFlowProvider(widget.collectionId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final plan = s.plan;
    final step = s.warmUpStep;
    final own = _own != null && _own == step && !s.answers.containsKey(step) ? _own : null;

    return Column(
      children: [
        if (plan != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(children: [
              Expanded(child: _WarmUpBar(step: s.stepIndex + 1, total: plan.steps.length)),
              const SizedBox(width: 12),
              Text('${s.stepIndex + 1} / ${plan.steps.length}',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              children: _dialog(s, box.maxWidth * 0.84),
            );
          }),
        ),
        if (own != null)
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
            child: Column(children: [
              if (_availability == null || _availability == SpeechAvailability.ready)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    label: 'Tap to talk',
                    button: true,
                    child: GestureDetector(
                      key: warmUpMicKey,
                      onTap: _micTap,
                      child: TalkRing(progress: 0, active: _listening, child: TalkMicCircle(on: _listening)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Text(
                  _listening ? 'Listening… tap the mic to stop' : 'Tap the mic to say it, or type',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: decor.muted, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _field,
                  builder: (_, v, __) => Row(children: [
                    Expanded(
                      child: TextField(
                        key: warmUpOwnTopicFieldKey,
                        controller: _field,
                        autofocus: true,
                        maxLength: own == WarmUpStep.main ? learnerTextMax : maxOwnTopicLength,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendable(own, _field.text) ? _send() : null,
                        decoration: InputDecoration(
                          hintText: own == WarmUpStep.main ? warmUpOwnAnswerHint : warmUpOwnTopicHint,
                          isDense: true,
                          errorText: _tooLong(own, v.text) ? warmUpTooLong : null,
                        ),
                      ),
                    ),
                    IconButton(
                      key: warmUpSendKey,
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
                      onPressed: _sendable(own, v.text) ? _send : null,
                    ),
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

/// The warm-up's bar of [total] steps (3 or 4, AC-06), the learning
/// session's segments: the step being asked and the ones before it filled.
class _WarmUpBar extends StatelessWidget {
  const _WarmUpBar({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: warmUpStepKey(i),
                minHeight: 6,
                value: i <= step ? 1 : 0,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
