import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/word_input/widgets/still_body.dart';

/// The main screen's body holds still (one picture) exactly while the side
/// menu is on screen, on Android only.
void main() {
  late SnapshotController controller;

  setUp(() {
    controller = SnapshotController();
    StillBody.debugEnabled = true;
  });

  tearDown(() => StillBody.debugEnabled = null);

  /// Takes the tree down first: as on the main screen, the drawer's trigger
  /// goes before the controller's owner.
  Future<void> finish(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    controller.dispose();
  }

  Widget app() => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Main')),
          drawer: Drawer(
            child: StillBodyWhileMounted(
              controller: controller,
              child: const Text('Menu'),
            ),
          ),
          body: StillBody(
            controller: controller,
            child: const ColoredBox(color: Colors.white, child: Text('rows')),
          ),
        ),
      );

  ScaffoldState scaffold(WidgetTester t) =>
      t.state<ScaffoldState>(find.byType(Scaffold));

  testWidgets('the body holds still from the first frame of the menu button\'s '
      'slide until the menu is away', (t) async {
    await t.pumpWidget(app());
    expect(controller.allowSnapshotting, isFalse);

    scaffold(t).openDrawer();
    await t.pump();
    expect(controller.allowSnapshotting, isTrue, reason: 'slide begins');
    await t.pump(const Duration(milliseconds: 100));
    expect(controller.allowSnapshotting, isTrue, reason: 'mid-slide');
    await t.pumpAndSettle();
    expect(controller.allowSnapshotting, isTrue, reason: 'open');

    scaffold(t).closeDrawer();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(controller.allowSnapshotting, isTrue, reason: 'sliding away');
    await t.pumpAndSettle();
    expect(controller.allowSnapshotting, isFalse, reason: 'away');
    expect(find.text('rows'), findsOneWidget);
    await finish(t);
  });

  testWidgets('an edge drag holds the body still from its first pixel',
      (t) async {
    await t.pumpWidget(app());
    final gesture = await t.startGesture(const Offset(4, 300));
    await gesture.moveBy(const Offset(30, 0));
    await t.pump();
    expect(controller.allowSnapshotting, isTrue);
    expect(scaffold(t).isDrawerOpen, isFalse, reason: 'well before the midpoint');

    // Let go early: the menu slides back and the body is live again.
    await gesture.up();
    await t.pumpAndSettle();
    expect(scaffold(t).isDrawerOpen, isFalse);
    expect(controller.allowSnapshotting, isFalse);
    await finish(t);
  });

  testWidgets('the body is painted as one picture while still', (t) async {
    await t.pumpWidget(app());
    scaffold(t).openDrawer();
    await t.pumpAndSettle();
    // The page transition has a SnapshotWidget of its own.
    final snapshot = t.widget<SnapshotWidget>(find.descendant(
        of: find.byType(StillBody), matching: find.byType(SnapshotWidget)));
    expect(snapshot.controller, same(controller));
    expect(snapshot.mode, SnapshotMode.permissive);
    expect(snapshot.autoresize, isTrue);
    // The picture painted without error, and the menu is on top of it.
    expect(find.text('Menu'), findsOneWidget);
    await finish(t);
  });

  testWidgets('off Android the body is never held still', (t) async {
    StillBody.debugEnabled = false;
    await t.pumpWidget(app());
    scaffold(t).openDrawer();
    await t.pump();
    expect(controller.allowSnapshotting, isFalse);
    await t.pumpAndSettle();
    expect(controller.allowSnapshotting, isFalse);
    scaffold(t).closeDrawer();
    await t.pumpAndSettle();
    expect(controller.allowSnapshotting, isFalse);
    await finish(t);
  });

  testWidgets('by default it follows the platform', (t) async {
    StillBody.debugEnabled = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(StillBody.enabled, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(StillBody.enabled, isFalse);
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
  });
}
