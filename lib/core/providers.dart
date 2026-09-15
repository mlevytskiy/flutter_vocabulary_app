import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/word_pair.dart';
import 'services/photo_scaler.dart';
import 'services/vocab_photo_service.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
VocabPhotoService vocabPhotoService(Ref ref) => VocabPhotoService();

@Riverpod(keepAlive: true)
PhotoScaler photoScaler(Ref ref) => PhotoScaler.instance; // singleton stays for now; provider is the door

// Step 2 (go_router): holds the valid pairs handed from WordInputScreen to
// WordsTableScreen across the route boundary, replacing the old constructor
// argument. Step 3 replaces this with the real word_input_notifier.
final validPairsProvider = StateProvider<List<WordPair>>((_) => []);
