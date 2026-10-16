// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $wordInputRoute,
    ];

RouteBase get $wordInputRoute => GoRouteData.$route(
      path: '/',
      factory: _$WordInputRoute._fromState,
      routes: [
        GoRouteData.$route(
          path: 'table',
          factory: _$WordsTableRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'learn',
              factory: _$LearnRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'soon',
                  factory: _$ComingSoonRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'story',
                  factory: _$StoryRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'exercise',
                  factory: _$ExerciseRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'dialogue',
                  factory: _$DialogueRoute._fromState,
                ),
              ],
            ),
            GoRouteData.$route(
              path: 'settings',
              factory: _$WordsSettingsRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'runs',
                  factory: _$StoryRunsRoute._fromState,
                  routes: [
                    GoRouteData.$route(
                      path: ':runId',
                      factory: _$StoryRunRoute._fromState,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRouteData.$route(
          path: 'notes',
          factory: _$NotesRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'photo/:sourceId',
          factory: _$PhotoViewerRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'history',
          factory: _$HistoryRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'settings',
          factory: _$SettingsRoute._fromState,
        ),
      ],
    );

mixin _$WordInputRoute on GoRouteData {
  static WordInputRoute _fromState(GoRouterState state) =>
      const WordInputRoute();

  @override
  String get location => GoRouteData.$location(
        '/',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$WordsTableRoute on GoRouteData {
  static WordsTableRoute _fromState(GoRouterState state) => WordsTableRoute(
        sessionId: state.uri.queryParameters['session-id'],
      );

  WordsTableRoute get _self => this as WordsTableRoute;

  @override
  String get location => GoRouteData.$location(
        '/table',
        queryParams: {
          if (_self.sessionId != null) 'session-id': _self.sessionId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$LearnRoute on GoRouteData {
  static LearnRoute _fromState(GoRouterState state) => LearnRoute(
        sessionId: state.uri.queryParameters['session-id'],
      );

  LearnRoute get _self => this as LearnRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/learn',
        queryParams: {
          if (_self.sessionId != null) 'session-id': _self.sessionId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ComingSoonRoute on GoRouteData {
  static ComingSoonRoute _fromState(GoRouterState state) => ComingSoonRoute(
        exercise: state.uri.queryParameters['exercise']!,
      );

  ComingSoonRoute get _self => this as ComingSoonRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/learn/soon',
        queryParams: {
          'exercise': _self.exercise,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRoute on GoRouteData {
  static StoryRoute _fromState(GoRouterState state) => StoryRoute(
        sessionId: state.uri.queryParameters['session-id'],
        groupId: state.uri.queryParameters['group-id']!,
      );

  StoryRoute get _self => this as StoryRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/learn/story',
        queryParams: {
          if (_self.sessionId != null) 'session-id': _self.sessionId,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ExerciseRoute on GoRouteData {
  static ExerciseRoute _fromState(GoRouterState state) => ExerciseRoute(
        sessionId: state.uri.queryParameters['session-id'],
        exercise: state.uri.queryParameters['exercise']!,
        groupId: state.uri.queryParameters['group-id']!,
      );

  ExerciseRoute get _self => this as ExerciseRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/learn/exercise',
        queryParams: {
          if (_self.sessionId != null) 'session-id': _self.sessionId,
          'exercise': _self.exercise,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$DialogueRoute on GoRouteData {
  static DialogueRoute _fromState(GoRouterState state) => DialogueRoute(
        sessionId: state.uri.queryParameters['session-id'],
        groupId: state.uri.queryParameters['group-id']!,
      );

  DialogueRoute get _self => this as DialogueRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/learn/dialogue',
        queryParams: {
          if (_self.sessionId != null) 'session-id': _self.sessionId,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$WordsSettingsRoute on GoRouteData {
  static WordsSettingsRoute _fromState(GoRouterState state) =>
      const WordsSettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/table/settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRunsRoute on GoRouteData {
  static StoryRunsRoute _fromState(GoRouterState state) =>
      const StoryRunsRoute();

  @override
  String get location => GoRouteData.$location(
        '/table/settings/runs',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRunRoute on GoRouteData {
  static StoryRunRoute _fromState(GoRouterState state) => StoryRunRoute(
        runId: state.pathParameters['runId']!,
      );

  StoryRunRoute get _self => this as StoryRunRoute;

  @override
  String get location => GoRouteData.$location(
        '/table/settings/runs/${Uri.encodeComponent(_self.runId)}',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$NotesRoute on GoRouteData {
  static NotesRoute _fromState(GoRouterState state) => NotesRoute(
        selectedId: state.uri.queryParameters['selected-id'],
      );

  NotesRoute get _self => this as NotesRoute;

  @override
  String get location => GoRouteData.$location(
        '/notes',
        queryParams: {
          if (_self.selectedId != null) 'selected-id': _self.selectedId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$PhotoViewerRoute on GoRouteData {
  static PhotoViewerRoute _fromState(GoRouterState state) => PhotoViewerRoute(
        sourceId: state.pathParameters['sourceId']!,
      );

  PhotoViewerRoute get _self => this as PhotoViewerRoute;

  @override
  String get location => GoRouteData.$location(
        '/photo/${Uri.encodeComponent(_self.sourceId)}',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$HistoryRoute on GoRouteData {
  static HistoryRoute _fromState(GoRouterState state) => const HistoryRoute();

  @override
  String get location => GoRouteData.$location(
        '/history',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
