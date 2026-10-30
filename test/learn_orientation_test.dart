import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/flow/story_page.dart';

/// learn-welcome T14 / AC-11: portrait app, landscape story page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <List<dynamic>>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') calls.add(call.arguments as List<dynamic>);
        return null;
      },
    );
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  test('the app orientation is portrait only', () async {
    await SystemChrome.setPreferredOrientations(appOrientations);
    expect(calls.single, ['DeviceOrientation.portraitUp']);
  });

  testWidgets('story page turns to landscape on show and back to portrait on leave', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StoryPage(picturePath: null, onDone: () {}),
    ));
    expect(calls.last, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(calls.last, ['DeviceOrientation.portraitUp']);
    expect(calls.length, 2);
  });
}
