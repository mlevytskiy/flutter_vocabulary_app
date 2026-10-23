import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../../core/services/speech_input.dart';
import '../../../core/theme/app_theme.dart';
import 'talk_navigation.dart';
import 'talk_notifier.dart';

/// Said when the speech permission is refused or no recognizer is there
/// (learn-redesign AC-26, AC-28); typing keeps working.
const talkVoiceRefusedMessage = 'Allow the microphone and speech recognition in Settings to talk';

/// Talk with AI (learn-redesign SCR-06; AC-20, AC-21, AC-24): bubbles, the
/// word strip, Hint, the reply field and End talk; hold-to-talk beside Send,
/// whose use has the AI's replies read aloud (AC-25, AC-26, ADR-0009).
/// Opened by `TalkRoute`.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key, this.collectionId, this.split = true});

  /// Null for the current collection, as on `LearnRoute`.
  final String? collectionId;

  /// Whether the Learn sheet's split was ticked.
  final bool split;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  static const leaveText = 'Leave the talk? Words used so far are not saved.';
  static const maxReplies = 12;

  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// The speech input, read on the first hold; null until then.
  SpeechInput? _speech;

  /// What the first hold's init found; null while not asked yet.
  SpeechAvailability? _availability;

  /// Whether the finger is on the mic, and whether it is listening.
  bool _holding = false;
  bool _listening = false;

  /// Set once the mic was used in this talk: new AI replies are read aloud.
  bool _voiceUsed = false;

  @override
  void initState() {
    super.initState();
    // After the first build has subscribed, so the auto-dispose talk lives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(talkProvider(widget.collectionId).notifier).start(split: widget.split);
    });
  }

  @override
  void dispose() {
    if (_listening) _speech?.cancel();
    _field.dispose();
    _focus.dispose();
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

  void _send() {
    final text = _field.text.trim();
    if (text.isEmpty) return;
    _field.clear();
    ref.read(talkProvider(widget.collectionId).notifier).send(text);
  }

  /// The mic went down: init on the first hold, then listen while held.
  Future<void> _holdDown() async {
    _holding = true;
    final speech = _speech ??= ref.read<SpeechInput>(speechInputProvider);
    if (_availability != SpeechAvailability.ready) {
      final found = await speech.init();
      if (!mounted) return;
      setState(() => _availability = found);
      if (found != SpeechAvailability.ready) return;
    }
    if (!_holding) return;
    _field.clear();
    setState(() {
      _listening = true;
      _voiceUsed = true;
    });
    await speech.listen(onText: (text, _) {
      if (mounted) _field.text = text;
    });
  }

  /// The mic was let go: stop and send the final words, if any.
  Future<void> _holdUp() async {
    _holding = false;
    if (!_listening) return;
    await _speech?.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    _send();
  }

  /// Reads a new AI reply aloud once the mic was used (AC-25).
  void _speak(String text) {
    ref
        .read(pronunciationServiceProvider)
        .speak(text, accent: Accent.us)
        .catchError((Object _) {});
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(leaveText),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = talkProvider(widget.collectionId);
    ref.listen(provider, (prev, next) {
      if (next.messages.length != prev?.messages.length || next.status != prev?.status) _scrollToEnd();
      if (_voiceUsed &&
          next.messages.length > (prev?.messages.length ?? 0) &&
          next.messages.last.role == TalkRole.ai) {
        _speak(next.messages.last.text);
      }
      final draft = next.keepDraft;
      if (draft != null && draft != prev?.keepDraft) _field.text = draft;
      if (draft == null && prev?.keepDraft != null) _field.clear();
      if (next.status == TalkStatus.over && prev?.status != TalkStatus.over) {
        openSessionResults(context, widget.collectionId);
      }
    });
    final s = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final decor = AppDecor.of(context);
    final scheme = Theme.of(context).colorScheme;
    final busy = s.status == TalkStatus.starting || s.status == TalkStatus.waiting;
    final inProgress = s.messages.isNotEmpty && s.status != TalkStatus.over;
    final micShown = _availability == null || _availability == SpeechAvailability.ready;
    final voiceRefused = _availability == SpeechAvailability.permissionDenied ||
        _availability == SpeechAvailability.unavailable;

    Widget body;
    if (s.status == TalkStatus.limit) {
      body = _Message(
          text: s.errorText ?? talkDayLimitMessage, button: 'Back', onPressed: () => Navigator.of(context).pop());
    } else if (s.status == TalkStatus.starting && s.messages.isEmpty) {
      body = const _Message(text: 'Setting the scene…', busy: true);
    } else if (s.status == TalkStatus.error && s.messages.isEmpty) {
      body = _Message(text: s.errorText ?? talkFailedMessage, button: 'Retry', onPressed: notifier.retry);
    } else {
      body = Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in s.messages) _Bubble(text: m.text, mine: m.role == TalkRole.learner),
                if (s.status == TalkStatus.waiting) const _Bubble(text: '…', mine: false),
              ],
            ),
          ),
          if (s.status == TalkStatus.error)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Text(s.errorText ?? talkFailedMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.error)),
                ),
                TextButton(onPressed: notifier.retry, child: const Text('Retry')),
              ]),
            ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final w in s.words)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: w.used
                        ? Chip(
                            label: Text('${w.word.word} ✓', style: TextStyle(color: decor.onLearnRight)),
                            backgroundColor: decor.learnRight,
                            side: BorderSide.none,
                          )
                        : Chip(label: Text(w.word.word), backgroundColor: Colors.transparent),
                  ),
              ],
            ),
          ),
          if (s.hintWord != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Try using: ${s.hintWord}', style: TextStyle(color: decor.muted)),
              ),
            ),
          if (_listening || voiceRefused)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_listening ? 'Listening…' : talkVoiceRefusedMessage,
                    style: TextStyle(color: decor.muted)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(children: [
              OutlinedButton(
                onPressed: s.hintAvailable && s.status == TalkStatus.talking ? notifier.showHint : null,
                child: const Text('Hint'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _field,
                  focusNode: _focus,
                  enabled: !busy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Type a reply…', isDense: true),
                ),
              ),
              IconButton(tooltip: 'Send', icon: const Icon(Icons.send), onPressed: busy ? null : _send),
              if (micShown)
                Semantics(
                  label: 'Hold to talk',
                  button: true,
                  child: Listener(
                    onPointerDown: busy ? null : (_) => _holdDown(),
                    onPointerUp: (_) => _holdUp(),
                    onPointerCancel: (_) => _holdUp(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(_listening ? Icons.mic : Icons.mic_none,
                          color: _listening ? scheme.primary : (busy ? scheme.onSurface.withValues(alpha: 0.38) : null)),
                    ),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: s.messages.isEmpty ? null : notifier.finish,
                child: const Text('End talk'),
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Talk with AI'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${s.repliesCount} / $maxReplies')),
            ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.busy = false, this.button, this.onPressed});

  final String text;
  final bool busy;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
              Text(text, textAlign: TextAlign.center),
              if (button != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(button!)),
              ],
            ],
          ),
        ),
      );
}
