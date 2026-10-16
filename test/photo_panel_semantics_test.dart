import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/features/word_input/photo_panel/photo_panel_stops.dart';

import 'photo_panel_test_host.dart';

/// side-bar-for-main-screen T11: every panel state is reached and left with a
/// screen reader, without any drag (spec AC-18).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> semanticTap(WidgetTester tester, String label) async {
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
        reason: '"$label" can be activated');
    node.owner!.performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
  }

  testWidgets('the tab is one node, "Collection photos, N"; a double-tap opens half-open',
      (tester) async {
    final handle = tester.ensureSemantics();
    final host = PanelHost(photos: fakePhotos(4));
    await host.pump(tester);

    expect(find.bySemanticsLabel('Collection photos, 4'), findsOneWidget);
    // One node: the previews and the count are not read one by one.
    expect(find.bySemanticsLabel('4'), findsNothing);
    final data = tester.getSemantics(find.bySemanticsLabel('Collection photos, 4')).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);

    await semanticTap(tester, 'Collection photos, 4');
    expect(host.controller.stop, PanelStop.halfOpen);
    handle.dispose();
  });

  testWidgets('while busy the tab offers no action (AC-17)', (tester) async {
    final handle = tester.ensureSemantics();
    final host = PanelHost(busy: true);
    await host.pump(tester);
    final data = tester.getSemantics(find.bySemanticsLabel('Collection photos, 3')).getSemanticsData();
    expect(data.hasAction(SemanticsAction.tap), isFalse);
    expect(host.controller.stop, PanelStop.closed);
    handle.dispose();
  });

  testWidgets('small photos are selectable buttons; expand, back and close need no drag',
      (tester) async {
    final handle = tester.ensureSemantics();
    final host = PanelHost(photos: fakePhotos(3));
    await host.pump(tester);
    await semanticTap(tester, 'Collection photos, 3');

    final photo = tester.getSemantics(find.bySemanticsLabel('Photo 2 of 3')).getSemanticsData();
    expect(photo.flagsCollection.isButton, isTrue);
    expect(photo.flagsCollection.isSelected, isFalse);
    await semanticTap(tester, 'Photo 2 of 3');
    expect(host.controller.selectedId, 'p1');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Photo 2 of 3')).getSemanticsData().flagsCollection.isSelected,
      isTrue,
    );

    await semanticTap(tester, 'Show photos large');
    expect(host.controller.stop, PanelStop.fullOpen);

    await semanticTap(tester, 'Back to small photos');
    expect(host.controller.stop, PanelStop.halfOpen);

    await semanticTap(tester, 'Close photos');
    expect(host.controller.stop, PanelStop.closed);
    handle.dispose();
  });
}
