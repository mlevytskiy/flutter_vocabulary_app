import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/word_input_screen.dart';
import 'services/photo_scaler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Spawn the long-lived background isolate used to downscale photos before
  // sending them to the vocabulary API, so it's ready by the time the user
  // takes their first photo.
  unawaited(PhotoScaler.instance.start());
  runApp(const VocabularyApp());
}

class VocabularyApp extends StatelessWidget {
  const VocabularyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WordInputScreen(),
    );
  }
}
