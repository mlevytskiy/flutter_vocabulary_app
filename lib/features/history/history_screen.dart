import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/providers.dart';
import '../../router/routes.dart';
import '../word_input/word_input_notifier.dart';

/// Every session that still has words, newest first. Read-only: tapping a row
/// opens the existing words table on that session's id.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(nonEmptySessionsProvider).valueOrNull ?? const <Session>[];
    final currentSessionId =
        ref.watch(wordInputNotifierProvider).valueOrNull?.sessionId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'No sessions yet',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final words = session.words.where((w) => !w.isEmpty).length;
                return ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: Text('$words ${words == 1 ? 'word' : 'words'}'),
                  subtitle: Text(_formatTimestamp(session.updatedAt)),
                  trailing: session.sessionId == currentSessionId
                      ? const Chip(label: Text('current'))
                      : null,
                  onTap: () =>
                      WordsTableRoute(sessionId: session.sessionId).push(context),
                );
              },
            ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatTimestamp(DateTime utcOrLocal) {
  final at = utcOrLocal.toLocal();
  return '${_two(at.day)}.${_two(at.month)}.${at.year} ${_two(at.hour)}:${_two(at.minute)}';
}
