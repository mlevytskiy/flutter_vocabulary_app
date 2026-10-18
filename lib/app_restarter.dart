import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'router/routes.dart';

/// The app's root: a [ProviderScope] around [App] that can be torn down and
/// built again, as if the app were started anew (new-user-trial, owner
/// 2026-10-17).
///
/// [restart] drops the scope (every provider, store and watcher goes with
/// it), runs `work` while nothing holds the database, then builds a fresh
/// scope on the main screen.
class AppRestarter extends StatefulWidget {
  const AppRestarter({super.key});

  static AppRestarterState of(BuildContext context) =>
      context.findAncestorStateOfType<AppRestarterState>()!;

  @override
  State<AppRestarter> createState() => AppRestarterState();
}

class AppRestarterState extends State<AppRestarter> {
  int _generation = 0;
  bool _restarting = false;

  Future<void> restart(Future<void> Function() work) async {
    if (_restarting) return;
    setState(() => _restarting = true);
    // Let the old scope unmount and dispose before the data moves.
    await WidgetsBinding.instance.endOfFrame;
    try {
      await work();
    } catch (e) {
      debugPrint('VOCAB: restart work failed: $e');
    }
    appRouter.go(const WordInputRoute().location);
    if (!mounted) return;
    setState(() {
      _restarting = false;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restarting) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return ProviderScope(key: ValueKey(_generation), child: const App());
  }
}
