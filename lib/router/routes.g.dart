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
              ],
            ),
          ],
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
