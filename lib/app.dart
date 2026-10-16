import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dialogues/dialogue_push.dart';
import 'core/story/story_run_tracker.dart';
import 'router/routes.dart';

/// The top bars' colour: the main screen's word-row background
/// (`word_row_item.dart`), chosen by the owner 2026-10-16. Change it here to
/// recolour every top bar.
const topBarColor = Color(0x57d9c1ff);

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Brings the story run tracker up, so runs left going are collected once on
    // app start (mnemonic-story AC-10).
    ref.read(storyRunTrackerProvider);
    // Brings the dialogue outbox up, so what a shared link is still owed is
    // delivered once on app start (get-words-from-subtitles-improvment
    // ADR-0005).
    ref.read(dialoguePushProvider);
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'English Vocabulary',
      debugShowCheckedModeBanner: false,
      // Every top bar is `inversePrimary`, so [topBarColor] goes there, and
      // to any bar that sets no colour.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)
            .copyWith(inversePrimary: topBarColor),
        appBarTheme: const AppBarTheme(backgroundColor: topBarColor),
        useMaterial3: true,
      ),
    );
  }
}
