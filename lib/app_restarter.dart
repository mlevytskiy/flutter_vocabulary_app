import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/collection_store.dart';
import 'router/routes.dart';
import 'router/start_location.dart';

/// The app's root: a [ProviderScope] around [App] that can be torn down and
/// built again, as if the app were started anew (new-user-trial, owner
/// 2026-10-17).
///
/// [restart] drops the scope (every provider, store and watcher goes with
/// it), runs `work` while nothing holds the database, then builds a fresh
/// scope on the start screen.
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

  /// Notes each time the app goes to the background, for the next start's
  /// screen (start-screen, owner 2026-10-18).
  late final _lifecycle = AppLifecycleListener(
    onHide: StartLocation.recordLeave,
    onDetach: StartLocation.recordLeave,
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

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
    // Words for a store with nothing to pick from (the trial's empty start),
    // Collections otherwise (start-screen, owner 2026-10-18).
    appRouter.go(StartLocation.pick(
      now: DateTime.now(),
      leftAt: null,
      onlyOneEmpty: await CollectionStore.onlyOneEmpty(),
    ));
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
