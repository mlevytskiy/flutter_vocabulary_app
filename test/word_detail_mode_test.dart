import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/providers.dart';

/// definition-mode T2: the learner's word detail mode — translation by default,
/// kept across restarts (spec AC-01).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WordDetailMode> readAfterLoad(ProviderContainer container) async {
    container.read(wordDetailModeProvider);
    await container.read(wordDetailModeProvider.notifier).loaded;
    return container.read(wordDetailModeProvider);
  }

  test('a fresh install starts in translation mode', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await readAfterLoad(container), WordDetailMode.translation);
  });

  test('the chosen mode survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await readAfterLoad(first);
    await first.read(wordDetailModeProvider.notifier).set(WordDetailMode.definition);
    expect(first.read(wordDetailModeProvider), WordDetailMode.definition);
    first.dispose();

    // A new container stands in for a relaunch; the mock store keeps values.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    expect(await readAfterLoad(second), WordDetailMode.definition);
  });

  test('an unknown stored value falls back to translation', () async {
    SharedPreferences.setMockInitialValues({'word_detail_mode': 'bogus'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await readAfterLoad(container), WordDetailMode.translation);
  });
}
