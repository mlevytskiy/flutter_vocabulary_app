import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_vocabulary_app/features/word_input/widgets/photo_source_dialog.dart';

/// photo-from-gallery T3: the Camera/Gallery source choice — spec AC-01,
/// AC-05; sad §4 "Source choice".
void main() {
  late ImageSource? result;
  late bool closed;

  Future<void> openDialog(WidgetTester tester) async {
    closed = false;
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showPhotoSourceDialog(context);
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows exactly the two choices Camera and Gallery', (tester) async {
    await openDialog(tester);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.byType(ListTile)), findsNWidgets(2));
  });

  testWidgets('tapping Camera returns ImageSource.camera', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, ImageSource.camera);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('tapping Gallery returns ImageSource.gallery', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, ImageSource.gallery);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('tapping outside the dialog returns null (AC-05)', (tester) async {
    await openDialog(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('going back returns null (AC-05)', (tester) async {
    await openDialog(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.maybePop();
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
    expect(find.byType(Dialog), findsNothing);
  });
}
