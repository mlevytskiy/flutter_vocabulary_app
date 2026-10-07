import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/learn/coming_soon_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/mnemonic_story/story_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/word_input/word_input_screen.dart';
import '../features/words_settings/words_settings_screen.dart';
import '../features/words_table/words_table_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<WordInputRoute>(
  path: '/',
  routes: [
    TypedGoRoute<WordsTableRoute>(
      path: 'table',
      routes: [
        TypedGoRoute<LearnRoute>(
          path: 'learn',
          routes: [
            TypedGoRoute<ComingSoonRoute>(path: 'soon'),
            TypedGoRoute<StoryRoute>(path: 'story'),
          ],
        ),
        TypedGoRoute<WordsSettingsRoute>(path: 'settings'),
      ],
    ),
    TypedGoRoute<HistoryRoute>(path: 'history'),
    TypedGoRoute<SettingsRoute>(path: 'settings'),
  ],
)
class WordInputRoute extends GoRouteData with _$WordInputRoute {
  const WordInputRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WordInputScreen();
}

/// [sessionId] is optional and travels as a query param: with no id the table
/// shows the current session (the AppBar "Next" button), with one it shows that
/// stored session, read-only (a History row). An id, never the object — rule 1.
class WordsTableRoute extends GoRouteData with _$WordsTableRoute {
  const WordsTableRoute({this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      WordsTableScreen(sessionId: sessionId);
}

/// The learn page (learn-part-step-1), opened from the Words screen. Carries
/// the same optional [sessionId] as [WordsTableRoute]: none for the current
/// session, an id for a History row, read-only either way (AC-13).
class LearnRoute extends GoRouteData with _$LearnRoute {
  const LearnRoute({this.sessionId});

  final String? sessionId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LearnScreen(sessionId: sessionId);
}

/// The app's placeholder for an exercise that is not built yet (learn-part-step-1),
/// pushed from Start. Carries the exercise id, never the object (rule 1).
class ComingSoonRoute extends GoRouteData with _$ComingSoonRoute {
  const ComingSoonRoute({required this.exercise});

  final String exercise;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ComingSoonScreen(exerciseId: exercise);
}

/// The mnemonic story of one group (mnemonic-story, SCR-04), pushed from Start
/// with Mnemonic story ticked. Ids only, never objects (rule 1): [sessionId] is
/// as on [LearnRoute] (none is the current session), [groupId] the group.
class StoryRoute extends GoRouteData with _$StoryRoute {
  const StoryRoute({this.sessionId, required this.groupId});

  final String? sessionId;
  final String groupId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      StoryScreen(sessionId: sessionId, groupId: groupId);
}

/// Words settings (mnemonic-story, SCR-05): the AI for each step of a story
/// run. Global, like the app's settings, so it carries no session id.
class WordsSettingsRoute extends GoRouteData with _$WordsSettingsRoute {
  const WordsSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WordsSettingsScreen();
}

class HistoryRoute extends GoRouteData with _$HistoryRoute {
  const HistoryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryScreen();
}

/// A plain pushed screen, not a dialog: it is where preferences live, and
/// more rows are expected here than the one it ships with (task-13).
class SettingsRoute extends GoRouteData with _$SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsScreen();
}

final appRouter = GoRouter(routes: $appRoutes);
