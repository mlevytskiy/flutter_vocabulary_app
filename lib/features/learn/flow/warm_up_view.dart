import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/learn_topics_service.dart';
import '../../../core/services/speech_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../../router/routes.dart';
import '../talk/talk_widgets.dart';
import 'flow_words.dart';
import 'learn_flow_notifier.dart';

/// The warm-up's lines and choices (learn-welcome AC-02, AC-04).
String warmUpTopicQuestion(int words) =>
    'Hi! $words ${words == 1 ? 'word' : 'words'} today. What would you like to talk about?';
const warmUpModeQuestion = 'Ready to work hard, or easy mode today?';
const warmUpOwnTopicChoice = 'My own topic…';
const warmUpHardChoice = 'Hard · longer talk';
const warmUpEasyChoice = 'Easy · shorter talk';
const warmUpOwnTopicHint = 'Type or say your topic…';
const warmUpTitle = 'Talk with AI';

/// Keys the tests and the flow screen find the warm-up by.
const warmUpStepKey1 = ValueKey('warm-up-step-1');
const warmUpStepKey2 = ValueKey('warm-up-step-2');
const warmUpTopicsLoadingKey = ValueKey('warm-up-topics-loading');
const warmUpOwnTopicFieldKey = ValueKey('warm-up-own-topic-field');
const warmUpSendKey = ValueKey('warm-up-send');
const warmUpMicKey = ValueKey('warm-up-mic');
const warmUpSettingsKey = ValueKey('warm-up-settings');

/// The warm-up of the Learn flow (learn-welcome AC-02, AC-04; owner A2,
/// A16, A19, A20; proxy Q11): the Talk screen's look — AI bubbles and tap
/// choices — asking "What would you like to talk about?" (3 topics and "My
/// own topic…", typed or said) and then "Ready to work hard, or easy mode
/// today?", under a 2-step bar. No Skip. The answers go to
/// [LearnFlow.chooseTopic] / [LearnFlow.ownTopic] and [LearnFlow.chooseMode].
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

  /// "My own topic…" was tapped: the field, Send and the mic show.
  bool _own = false;

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
    setState(() => _own = false);
    _flow.chooseTopic(topic);
    _scrollToEnd();
  }

  void _openOwn() {
    setState(() => _own = true);
    _scrollToEnd();
  }

  Future<void> _send() async {
    await _stopListening();
    if (!_flow.ownTopic(_field.text)) return;
    if (mounted) setState(() => _own = false);
    _scrollToEnd();
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

  static bool _sendable(String text) => text.trim().isNotEmpty && text.length <= maxOwnTopicLength;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(learnFlowProvider(widget.collectionId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final topics = s.topics;
    final topic = s.topic;
    final step = topic == null ? 1 : 2;
    final loading = s.phase == FlowPhase.loading || topics == null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Expanded(child: _WarmUpBar(step: step)),
            const SizedBox(width: 12),
            Text('$step / 2', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final maxWidth = box.maxWidth * 0.84;
            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              children: [
                if (s.phase != FlowPhase.loading)
                  TalkBubble(index: 0, text: warmUpTopicQuestion(s.words.length), mine: false, maxWidth: maxWidth),
                if (loading)
                  TalkBubble(key: warmUpTopicsLoadingKey, index: -1, text: '…', mine: false, maxWidth: maxWidth)
                else if (topic == null) ...[
                  const SizedBox(height: 8),
                  for (final t in topics)
                    TalkChoiceButton(
                      choice: t.title,
                      detail: t.description.isEmpty ? null : t.description,
                      onPressed: () => _chooseTopic(t),
                    ),
                  TalkChoiceButton(choice: warmUpOwnTopicChoice, onPressed: _own ? null : _openOwn),
                ] else ...[
                  TalkBubble(index: 1, text: topic.text, mine: true, maxWidth: maxWidth),
                  TalkBubble(index: 2, text: warmUpModeQuestion, mine: false, maxWidth: maxWidth),
                  const SizedBox(height: 8),
                  TalkChoiceButton(choice: warmUpHardChoice, onPressed: () => _flow.chooseMode(FlowMode.hard)),
                  TalkChoiceButton(choice: warmUpEasyChoice, onPressed: () => _flow.chooseMode(FlowMode.easy)),
                ],
              ],
            );
          }),
        ),
        if (_own && topic == null)
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
                        maxLength: maxOwnTopicLength,
                        maxLengthEnforcement: MaxLengthEnforcement.none,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendable(_field.text) ? _send() : null,
                        decoration: const InputDecoration(hintText: warmUpOwnTopicHint, isDense: true),
                      ),
                    ),
                    IconButton(
                      key: warmUpSendKey,
                      tooltip: 'Send',
                      icon: const Icon(Icons.send),
                      onPressed: _sendable(v.text) ? _send : null,
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

/// The warm-up's 2-step bar (owner A16), the learning session's segments:
/// the step being asked and the ones before it filled.
class _WarmUpBar extends StatelessWidget {
  const _WarmUpBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 1; i <= 2; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: i == 1 ? warmUpStepKey1 : warmUpStepKey2,
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
