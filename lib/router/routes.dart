import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/word_input/word_input_screen.dart';
import '../features/words_table/words_table_screen.dart';

part 'routes.g.dart';

@TypedGoRoute<WordInputRoute>(
  path: '/',
  routes: [TypedGoRoute<WordsTableRoute>(path: 'table')],
)
class WordInputRoute extends GoRouteData with _$WordInputRoute {
  const WordInputRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WordInputScreen();
}

class WordsTableRoute extends GoRouteData with _$WordsTableRoute {
  const WordsTableRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const WordsTableScreen();
}

final appRouter = GoRouter(routes: $appRoutes);
