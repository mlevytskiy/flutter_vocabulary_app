import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/models/tag_kind.dart';
import '../features/app_settings/app_settings_screen.dart';
import '../features/collections/collections_screen.dart';
import '../features/collections/collections_settings_screen.dart';
import '../features/collections/recycle_bin_screen.dart';
import '../features/dialogue/dialogue_screen.dart';
import '../features/learn/coming_soon_screen.dart';
import '../features/learn/exercise_screens.dart';
import '../features/learn/learn_screen.dart';
import '../features/learn/session/learning_session_screen.dart';
import '../features/learn/talk/talk_screen.dart';
import '../features/learn/session/session_results_screen.dart';
import '../features/mnemonic_story/story_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/notes/photo_viewer_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/words/words_screen.dart';
import '../features/words_settings/story_run_screen.dart';
import '../features/words_settings/story_runs_screen.dart';
import '../features/words_settings/words_settings_screen.dart';
import '../features/words_table/words_table_screen.dart';

part 'routes.g.dart';

// The side menu's screens (navigation, owner 2026-10-18) are the branches
// of one shell: each keeps its own navigator, so going back to one through
// the menu shows the same screen, as it was, without a page transition.
// `go` to one leaves its branch at its root, so its top bar shows the menu
// button, not Back. Collections is the start screen.
@TypedStatefulShellRoute<MenuShellRoute>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<CollectionsBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<CollectionsRoute>(
          path: '/',
          routes: [
            TypedGoRoute<RecycleBinRoute>(path: 'recycle-bin'),
            TypedGoRoute<CollectionsSettingsRoute>(path: 'collections-settings'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<WordsBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<WordsRoute>(
          path: '/words',
          routes: [
            TypedGoRoute<WordsTableRoute>(
              path: 'table',
              routes: [
                TypedGoRoute<LearnRoute>(
                  path: 'learn',
                  routes: [
                    TypedGoRoute<ComingSoonRoute>(path: 'soon'),
                    TypedGoRoute<StoryRoute>(path: 'story'),
                    TypedGoRoute<ExerciseRoute>(path: 'exercise'),
                    TypedGoRoute<DialogueRoute>(path: 'dialogue'),
                  ],
                ),
                TypedGoRoute<LearningSessionRoute>(path: 'session'),
                TypedGoRoute<TalkRoute>(path: 'talk'),
                TypedGoRoute<SessionResultsRoute>(path: 'results'),
                TypedGoRoute<WordsSettingsRoute>(
                  path: 'settings',
                  routes: [
                    TypedGoRoute<StoryRunsRoute>(
                      path: 'runs',
                      routes: [TypedGoRoute<StoryRunRoute>(path: ':runId')],
                    ),
                  ],
                ),
              ],
            ),
            TypedGoRoute<NotesRoute>(path: 'notes'),
            TypedGoRoute<PhotoViewerRoute>(path: 'photo/:sourceId'),
            TypedGoRoute<SettingsRoute>(path: 'settings'),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<AppSettingsBranch>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<AppSettingsRoute>(path: '/app-settings'),
      ],
    ),
  ],
)
/// The shell around the side menu's screens: the branches in an indexed
/// stack, the hidden ones kept alive.
class MenuShellRoute extends StatefulShellRouteData {
  const MenuShellRoute();

  @override
  Widget builder(BuildContext context, GoRouterState state,
          StatefulNavigationShell navigationShell) =>
      navigationShell;
}

class CollectionsBranch extends StatefulShellBranchData {
  const CollectionsBranch();
}

class WordsBranch extends StatefulShellBranchData {
  const WordsBranch();
}

class AppSettingsBranch extends StatefulShellBranchData {
  const AppSettingsBranch();
}

/// The Collections screen (collections-screen): folders and collections as icons.
class CollectionsRoute extends GoRouteData with _$CollectionsRoute {
  const CollectionsRoute({this.tagKind, this.tag});

  /// A tag tap on the Words screen filters the screen (collection-tags ADR-0008).
  final TagKind? tagKind;
  final String? tag;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CollectionsScreen(tagKind: tagKind, tag: tag);
}

/// The Words screen: the current collection's word rows (the app's main
/// screen before navigation, owner 2026-10-18).
class WordsRoute extends GoRouteData with _$WordsRoute {
  const WordsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WordsScreen();
}

/// [collectionId] is optional and travels as a query param: with no id the table
/// shows the current session (the AppBar "Next" button), with one it shows that
/// stored session, read-only (a History row). An id, never the object — rule 1.
class WordsTableRoute extends GoRouteData with _$WordsTableRoute {
  const WordsTableRoute({this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      WordsTableScreen(collectionId: collectionId);
}

/// The learn page (learn-part-step-1), opened from the Words screen. Carries
/// the same optional [collectionId] as [WordsTableRoute]: none for the current
/// session, an id for a History row, read-only either way (AC-13).
class LearnRoute extends GoRouteData with _$LearnRoute {
  const LearnRoute({this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LearnScreen(collectionId: collectionId);
}

/// A learning session (learn-redesign SCR-03, AC-02), opened from the Learn
/// sheet's Exercises card. Ids only (rule 1): [collectionId] as on
/// [LearnRoute], [split] as ticked on the sheet, [rowIds] the comma-joined
/// rows of "Practise N shaky words" (none: the picker chooses).
class LearningSessionRoute extends GoRouteData with _$LearningSessionRoute {
  const LearningSessionRoute({this.collectionId, this.split = true, this.rowIds, this.skipGroup});

  final String? collectionId;
  final bool split;
  final String? rowIds;

  /// "Next group": the group just played, skipped by the picker.
  final int? skipGroup;

  @override
  Widget build(BuildContext context, GoRouterState state) => LearningSessionScreen(
        collectionId: collectionId,
        split: split,
        rowIds: rowIds == null || rowIds!.isEmpty ? null : rowIds!.split(','),
        skipGroup: skipGroup,
      );
}

/// Talk with AI (learn-redesign SCR-06, AC-20), opened from the Learn sheet's
/// Talk with AI card. Ids only (rule 1): [collectionId] as on [LearnRoute],
/// [split] as ticked on the sheet.
class TalkRoute extends GoRouteData with _$TalkRoute {
  const TalkRoute({this.collectionId, this.split = true});

  final String? collectionId;
  final bool split;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TalkScreen(collectionId: collectionId, split: split);
/// The results of the session just finished (learn-redesign SCR-04; AC-12),
/// read from `lastSessionResultProvider`. [collectionId] as on
/// [LearningSessionRoute].
}

class SessionResultsRoute extends GoRouteData with _$SessionResultsRoute {
  const SessionResultsRoute({this.collectionId});

  final String? collectionId;

  @override
  Widget build(BuildContext context, GoRouterState state) => SessionResultsScreen(collectionId: collectionId);
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
/// with Mnemonic story ticked. Ids only, never objects (rule 1): [collectionId] is
/// as on [LearnRoute] (none is the current session), [groupId] the group.
class StoryRoute extends GoRouteData with _$StoryRoute {
  const StoryRoute({this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      StoryScreen(collectionId: collectionId, groupId: groupId);
}

/// One exercise for one word group (learn-kit S-03), pushed from Start like
/// [StoryRoute]. Ids only (rule 1): [collectionId] as on [LearnRoute], the
/// frozen [exercise] id and the [groupId]. `exerciseScreen` picks the screen.
class ExerciseRoute extends GoRouteData with _$ExerciseRoute {
  const ExerciseRoute({this.collectionId, required this.exercise, required this.groupId});

  final String? collectionId;
  final String exercise;
  final String groupId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      exerciseScreen(exercise, collectionId, groupId);
}

/// "Dialogs from movie" for one dialogue group (get-words-from-subtitles-
/// improvment, SCR-07), pushed from Start like [StoryRoute]. Ids only (rule 1).
class DialogueRoute extends GoRouteData with _$DialogueRoute {
  const DialogueRoute({this.collectionId, required this.groupId});

  final String? collectionId;
  final String groupId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DialogueScreen(collectionId: collectionId, groupId: groupId);
}

/// Words settings (mnemonic-story, SCR-05): the AI for each step of a story
/// run. Global, like the app's settings, so it carries no session id.
class WordsSettingsRoute extends GoRouteData with _$WordsSettingsRoute {
  const WordsSettingsRoute({this.collectionId});

  /// The Words screen's collection, as in [WordsTableRoute]: its "Include
  /// photos (N)" switch is here (words-photo-panel).
  final String? collectionId;

  @override
  Widget build(BuildContext context, GoRouterState state) => WordsSettingsScreen(
        collectionId: collectionId,
        onOpenStoryRuns: () => const StoryRunsRoute().push(context),
      );
}

/// Every story run, newest first (SCR-06).
class StoryRunsRoute extends GoRouteData with _$StoryRunsRoute {
  const StoryRunsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => StoryRunsScreen(
        onOpenRun: (runId) => StoryRunRoute(runId: runId).push(context),
      );
}

/// One story run's details (SCR-07). An id, never the object — rule 1.
class StoryRunRoute extends GoRouteData with _$StoryRunRoute {
  const StoryRunRoute({required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, GoRouterState state) => StoryRunScreen(runId: runId);
}

/// Notes (owner, 2026-10-15): every source the photo panel lists, pushed
/// from the half-open panel's expand control. [selectedId] is the source
/// selected in the panel, an id, never the object (rule 1).
class NotesRoute extends GoRouteData with _$NotesRoute {
  const NotesRoute({this.selectedId});

  final String? selectedId;

  /// Fades in rather than sliding, so a panel dragged into the Notes look
  /// becomes the page with nothing moving (owner, 2026-10-15); the tapped
  /// picture still flies in as a hero.
  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) =>
      CustomTransitionPage<void>(
        key: state.pageKey,
        child: NotesScreen(selectedId: selectedId),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
}

/// A source's photo full screen, pushed from its picture on the Notes page
/// (notes-editing, owner 2026-10-15). An id, never the object (rule 1).
class PhotoViewerRoute extends GoRouteData with _$PhotoViewerRoute {
  const PhotoViewerRoute({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PhotoViewerScreen(sourceId: sourceId);
}

/// A plain pushed screen, not a dialog: it is where preferences live, and
/// more rows are expected here than the one it ships with (task-13).
class SettingsRoute extends GoRouteData with _$SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsScreen();
}

/// App settings (app-themes): settings for the whole app, opened from the
/// side menu. Holds the theme gallery.
class AppSettingsRoute extends GoRouteData with _$AppSettingsRoute {
  const AppSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AppSettingsScreen();
}

/// The recycle bin (collections-screen SCR-08); opened from the top-level bin
/// icon on the Collections screen.
class RecycleBinRoute extends GoRouteData with _$RecycleBinRoute {
  const RecycleBinRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const RecycleBinScreen();
}

/// Collections settings (owner, 2026-10-18): the Collections screen's
/// Settings button. Holds "Replace all date names".
class CollectionsSettingsRoute extends GoRouteData
    with _$CollectionsSettingsRoute {
  const CollectionsSettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const CollectionsSettingsScreen();
}

/// The screen the router opens on; `main` sets it from [StartLocation]
/// before the first frame, as `appRouter` is built on first use.
String appStartLocation = const CollectionsRoute().location;

final appRouter =
    GoRouter(initialLocation: appStartLocation, routes: $appRoutes);
