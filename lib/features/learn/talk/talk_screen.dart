import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'talk_navigation.dart';
import 'talk_notifier.dart';

/// Talk with AI (learn-redesign SCR-06; AC-20, AC-21, AC-24): bubbles, the
/// word strip, Hint, the reply field and End talk. Opened by `TalkRoute`.
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
