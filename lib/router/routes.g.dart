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
        ),
        GoRouteData.$route(
          path: 'history',
          factory: _$HistoryRoute._fromState,
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
