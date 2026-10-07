import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/story/story_run_tracker.dart';
import 'router/routes.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Brings the story run tracker up, so runs left going are collected once on
    // app start (mnemonic-story AC-10).
    ref.read(storyRunTrackerProvider);
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'English Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}
