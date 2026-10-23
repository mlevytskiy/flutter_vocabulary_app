// Collections settings (owner, 2026-10-18): the Collections screen's
// Settings button opens it; "Replace all date names" reports what it did.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/features/collections/collections_settings_screen.dart';
import 'package:flutter_vocabulary_app/features/words/words_notifier.dart';
import 'package:flutter_vocabulary_app/router/routes.dart';

class _FakeInput extends WordsNotifier {
  final done = Completer<({int vocabulary, int ai, int kept})>();
  int calls = 0;

  @override
  Future<WordCollection> build() async => WordCollection.create();

  @override
  Future<({int vocabulary, int ai, int kept})> replaceDateNames() {
    calls++;
    return done.future;
  }
}

void main() {
  test('the snackbar line says what happened', () {
    expect(replaceDateNamesMessage((vocabulary: 0, ai: 0, kept: 0)),
        'No date names to replace');
    expect(replaceDateNamesMessage((vocabulary: 3, ai: 1, kept: 0)),
        'AI named 1 collection. 3 collections now called "Vocabulary"');
    expect(
        replaceDateNamesMessage((vocabulary: 0, ai: 0, kept: 2)),
        'AI did not answer for 2 collections, they keep their dates: '
        'try again later');
  });

  testWidgets('its own route, one row; a tap replaces once and reports',
      (t) async {
    final input = _FakeInput();
    await t.pumpWidget(ProviderScope(
      overrides: [wordsProvider.overrideWith(() => input)],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: $appRoutes,
          initialLocation: const CollectionsSettingsRoute().location,
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Collections settings'), findsOneWidget);
    expect(find.text('Replace all date names'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    await t.tap(find.byKey(CollectionsSettingsScreen.replaceDateNamesKey));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // A second tap while it runs does nothing.
    await t.tap(find.byKey(CollectionsSettingsScreen.replaceDateNamesKey));
    await t.pump();
    expect(input.calls, 1);

    input.done.complete((vocabulary: 2, ai: 3, kept: 0));
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.text('AI named 3 collections. 2 collections now called '
            '"Vocabulary"'),
        findsOneWidget);
  });
}
