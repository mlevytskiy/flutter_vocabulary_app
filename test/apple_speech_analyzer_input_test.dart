import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/services/speech_input.dart';

/// Apple's SpeechAnalyzer engine (owner, 2026-10-24) over a mocked Runner
/// bridge: what `prepare` answers, the words of a session, and hands-free.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('vocab/speech_analyzer');
  const events = EventChannel('vocab/speech_analyzer/events');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;
  late String prepare;
  late String finalText;
  MockStreamHandlerEventSink? sink;

  setUp(() {
    calls = [];
    prepare = 'ready';
    finalText = '';
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return switch (call.method) {
        'prepare' => prepare,
        'start' => true,
        'stop' => finalText,
        _ => null,
      };
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, s) => sink = s, onCancel: (_) => sink = null),
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('prepare maps to availability', () async {
    expect(await AppleSpeechAnalyzerInput().init(), SpeechAvailability.ready);
    prepare = 'permissionDenied';
    expect(await AppleSpeechAnalyzerInput().init(), SpeechAvailability.permissionDenied);
    prepare = 'unavailable';
    expect(await AppleSpeechAnalyzerInput().init(), SpeechAvailability.unavailable);
  });

  test('no bridge (Android, older iOS) is unavailable', () async {
    messenger.setMockMethodCallHandler(methods, null);
    expect(await AppleSpeechAnalyzerInput().init(), SpeechAvailability.unavailable);
  });

  test('listen streams the words; stop gives the final text', () async {
    final input = AppleSpeechAnalyzerInput();
    await input.init();
    final got = <(String, bool)>[];
    await input.listen(onText: (t, f) => got.add((t, f)));
    sink!.success({'text': 'I lost my', 'isFinal': false});
    await pumpEventQueue();
    finalText = 'I lost my luggage';
    await input.stop();
    expect(got, [('I lost my', false), ('I lost my luggage', true)]);
    expect(calls, ['prepare', 'start', 'stop']);
  });

  test('hands-free: a pause after words ends with them', () async {
    final input = AppleSpeechAnalyzerInput();
    await input.init();
    String? done;
    await input.listenUntilPause(
      pause: const Duration(milliseconds: 50),
      onPartial: (_) {},
      onDone: (t) => done = t,
    );
    sink!.success({'text': 'The tide is high', 'isFinal': false});
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(done, 'The tide is high');
    expect(calls.last, 'stop');
  });

  test('Apple SpeechAnalyzer is offered only on iOS', () {
    // Tests run on the desktop.
    expect(SpeechEngine.offered, [SpeechEngine.speechToText, SpeechEngine.speechToTextPro]);
    expect(SpeechEngine.appleSpeechAnalyzer.label, 'Apple SpeechAnalyzer');
  });
}
