import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/word_input/word_input_screen.dart';
import '../features/words_table/words_table_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<WordInputRoute>(
  path: '/',
  routes: [
    TypedGoRoute<WordsTableRoute>(path: 'table'),
    TypedGoRoute<HistoryRoute>(path: 'history'),
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

class HistoryRoute extends GoRouteData with _$HistoryRoute {
  const HistoryRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryScreen();
}

final appRouter = GoRouter(routes: $appRoutes);
