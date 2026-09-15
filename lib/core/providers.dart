import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'services/photo_scaler.dart';
import 'services/vocab_photo_service.dart';
import 'services/word_store.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

@Riverpod(keepAlive: true)
WordStore wordStore(Ref ref) => WordStore();
