import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dialogues/dialogue_push.dart';
import 'core/providers.dart';
import 'core/story/story_run_tracker.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/layout_scale.dart';
import 'router/routes.dart';

/// The top bars' colour in the Classic theme: the main screen's word-row
/// background (`word_row_item.dart`), chosen by the owner 2026-10-16. Every
/// theme sets its own as [AppDecor.topBar] (`lib/core/theme/app_theme.dart`).
const topBarColor = classicTopBarColor;

/// Every platform pushes and pops pages with the iOS slide, so Android
/// moves between screens as the iPhone does (owner, 2026-10-19).
const pageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
});

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
      // Every top bar is `inversePrimary`, so the theme's top bar colour goes
      // there, and to any bar that sets no colour (app-themes).
      // Android pages slide in as on iOS, the old page drifting left under
      // the new one (owner, 2026-10-19).
      theme: AppThemeSpec.of(ref.watch(appThemeNotifierProvider))
          .build()
          .copyWith(pageTransitionsTheme: pageTransitions),
      // A red line along the top of every screen while the new-user trial is
      // on, so the test account is never mistaken for the real one
      // (new-user-trial, owner 2026-10-17).
      // Every phone lays out as the iPhone does (owner, 2026-10-19).
      builder: (context, child) =>
          LayoutScale(child: TrialFrame(child: child!)),
    );
  }
}

/// Every screen; while the new-user trial is on, a red line over it, just
/// under the status bar along the top edge of the top bar. Taps pass through.
class TrialFrame extends ConsumerWidget {
  const TrialFrame({super.key, required this.child});

  static const lineKey = Key('trial-line');
  static const lineHeight = 4.0;
  static const lineColor = Color(0xFFE53935);

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(newUserBackupProvider).valueOrNull != null;
    return Stack(
      children: [
        child,
        if (on)
          Positioned(
            top: MediaQuery.paddingOf(context).top,
            left: 0,
            right: 0,
            height: lineHeight,
            child: const IgnorePointer(
              child: ColoredBox(key: lineKey, color: lineColor),
            ),
          ),
      ],
    );
  }
}
