import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/photo_scaler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Spawn the long-lived background isolate used to downscale photos before
  // sending them to the vocabulary API, so it's ready by the time the user
  // takes their first photo.
  unawaited(PhotoScaler.instance.start());
  runApp(const ProviderScope(child: App()));
}
