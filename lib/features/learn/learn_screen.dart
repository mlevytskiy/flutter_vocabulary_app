import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../router/routes.dart';
import '../word_input/word_input_notifier.dart';
import 'exercises.dart';

/// The learn page (learn-part-step-1, SCR-03). Reads the session the same way
/// the Words screen does and only reads it: no sessionId is the current
/// session, an id is a History row (AC-13). Ticks are transient UI state.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final Set<String> _ticked = {};

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final session = sessionId == null
        ? ref.watch(wordInputNotifierProvider).valueOrNull
        : ref.watch(sessionByIdProvider(sessionId)).valueOrNull;
    final count = (session?.words ?? const <WordPair>[])
        .where((pair) => pair.isFilled)
        .length;
    final canStart = _ticked.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(count == 1 ? '1 word' : '$count words'),
          for (final stage in const [1, 2, 3]) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(
                'Step $stage',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final exercise in exercises.where((e) => e.stage == stage))
              CheckboxListTile(
                value: _ticked.contains(exercise.id),
                enabled: exercise.available,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(exercise.name),
                subtitle: exercise.available ? null : const Text('Coming soon'),
                onChanged: exercise.available
                    ? (on) => setState(() {
                          if (on == true) {
                            _ticked.add(exercise.id);
                          } else {
                            _ticked.remove(exercise.id);
                          }
                        })
                    : null,
              ),
          ],
          const SizedBox(height: 16),
          if (!canStart)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Pick at least one exercise'),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: canStart
                  ? () => ComingSoonRoute(
                        exercise: exercises
                            .firstWhere((e) => _ticked.contains(e.id))
                            .id,
                      ).push<void>(context)
                  : null,
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}
