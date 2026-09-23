import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/session.dart';
import 'services/google_translate_service.dart';
import 'services/photo_scaler.dart';
import 'services/pronunciation_service.dart';
import 'services/session_publish_service.dart';
import 'services/session_store.dart';
import 'services/vocab_photo_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

@Riverpod(keepAlive: true)
Future<SessionStore> sessionStore(Ref ref) => SessionStore.open();

@Riverpod(keepAlive: true)
GoogleTranslateService googleTranslateService(Ref ref) =>
    GoogleTranslateService();

@Riverpod(keepAlive: true)
PronunciationService pronunciationService(Ref ref) => PronunciationService();

@Riverpod(keepAlive: true)
SessionPublishService sessionPublishService(Ref ref) => SessionPublishService();

@riverpod
Future<Session?> sessionById(Ref ref, String sessionId) async {
  final store = await ref.watch(sessionStoreProvider.future);
  return store.byId(sessionId);
}

/// Every session that has at least one non-blank word, newest first, re-emitted
/// after every write. The drawer rule on the input screen and the History
/// screen (task-10) both read this one stream.
@riverpod
Stream<List<Session>> nonEmptySessions(Ref ref) async* {
  final store = await ref.watch(sessionStoreProvider.future);
  yield* store.watchNonEmpty();
}
