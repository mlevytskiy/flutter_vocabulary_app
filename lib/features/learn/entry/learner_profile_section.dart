import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/learner_profile_store.dart';
import '../flow/warm_up_plan.dart' show dailyChoices, goalChoices;

const learnerProfileNote = 'Used only to pick talk topics';
const learnerTextTooLong = 'Keep it under 80 characters';

/// The learner profile in Learn settings (learn-warm-up-v2 AC-11, AC-04): the
/// English level, goal and daily context, or "Not set"; each changed with the
/// warm-up's taps (goal and daily also in own words, at most 80 characters)
/// and cleared on its own. Round and counters are never touched here.
class LearnerProfileSection extends ConsumerStatefulWidget {
  const LearnerProfileSection({super.key});

  @override
  ConsumerState<LearnerProfileSection> createState() => _LearnerProfileSectionState();
}

class _LearnerProfileSectionState extends ConsumerState<LearnerProfileSection> {
  LearnerProfile _profile = const LearnerProfile();

  LearnerProfileStore get _store => ref.read(learnerProfileStoreProvider);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await _store.read();
    if (mounted) setState(() => _profile = p);
  }

  Future<void> _set(Future<void> Function(LearnerProfileStore s) write) async {
    await write(_store);
    await _reload();
  }

  Future<void> _pick({
    required String title,
    required List<String> choices,
    required bool ownWords,
    required Future<void> Function(LearnerProfileStore s, String value) save,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChoiceSheet(title: title, choices: choices, ownWords: ownWords),
    );
    if (value != null) await _set((s) => save(s, value));
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium;
    final muted = Theme.of(context).textTheme.bodySmall;
    final p = _profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Learner profile', style: heading),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
          child: Text(learnerProfileNote, style: muted),
        ),
        _row(
          title: 'English level',
          value: p.level,
          clearTooltip: 'Clear English level',
          onClear: () => _set((s) => s.setLevel(null)),
          onTap: () => _pick(
            title: 'English level',
            choices: learnerLevels,
            ownWords: false,
            save: (s, v) => s.setLevel(v),
          ),
        ),
        _row(
          title: 'Goal',
          value: p.goal,
          clearTooltip: 'Clear goal',
          onClear: () => _set((s) => s.setGoal(null)),
          onTap: () => _pick(
            title: 'Goal',
            choices: goalChoices,
            ownWords: true,
            save: (s, v) => s.setGoal(v),
          ),
        ),
        _row(
          title: 'Daily context',
          value: p.daily,
          clearTooltip: 'Clear daily context',
          onClear: () => _set((s) => s.setDaily(null)),
          onTap: () => _pick(
            title: 'Daily context',
            choices: dailyChoices,
            ownWords: true,
            save: (s, v) => s.setDaily(v),
          ),
        ),
      ],
    );
  }

  Widget _row({
    required String title,
    required String? value,
    required String clearTooltip,
    required VoidCallback onClear,
    required VoidCallback onTap,
  }) =>
      ListTile(
        title: Text(title),
        subtitle: Text(value ?? 'Not set'),
        onTap: onTap,
        trailing: value == null
            ? null
            : IconButton(icon: const Icon(Icons.close), tooltip: clearTooltip, onPressed: onClear),
      );
}

/// The taps of one profile question, and for goal and daily context a field for
/// own words with the 80-character rule. Pops the chosen text.
class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({required this.title, required this.choices, required this.ownWords});

  final String title;
  final List<String> choices;
  final bool ownWords;

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final tooLong = text.length > learnerTextMax;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final c in widget.choices)
                ListTile(title: Text(c), onTap: () => Navigator.of(context).pop(c)),
              if (widget.ownWords)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'In your own words',
                          errorText: tooLong ? learnerTextTooLong : null,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: text.isEmpty || tooLong ? null : () => Navigator.of(context).pop(text),
                      child: const Text('Send'),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
