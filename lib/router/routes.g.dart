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
  static WordsTableRoute _fromState(GoRouterState state) =>
      const WordsTableRoute();

  @override
  String get location => GoRouteData.$location(
        '/table',
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
