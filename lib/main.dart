import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app_restarter.dart';
import 'core/services/photo_scaler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Spawn the long-lived background isolate used to downscale photos before
  // sending them to the vocabulary API, so it's ready by the time the user
  // takes their first photo.
  unawaited(PhotoScaler.instance.start());
  useAndroidPhotoPicker();
  registerFontLicenses();
  runApp(const AppRestarter());
}

/// Gallery picks on Android open the system Photo Picker instead of
/// ACTION_GET_CONTENT (photo-from-gallery ADR-0001). No-op on other platforms.
void useAndroidPhotoPicker() {
  final picker = ImagePickerPlatform.instance;
  if (picker is ImagePickerAndroid) picker.useAndroidPhotoPicker = true;
}

/// The theme fonts' SIL Open Font Licences, shown in the licence page
/// (app-themes).
void registerFontLicenses() {
  const families = {
    'Comfortaa': 'Comfortaa',
    'JetBrains Mono': 'JetBrainsMono',
    'Manrope': 'Manrope',
    'Nunito': 'Nunito',
    'Unbounded': 'Unbounded',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: file) in families.entries) {
      yield LicenseEntryWithLineBreaks(
        [family],
        await rootBundle.loadString('assets/fonts/licenses/$file-OFL.txt'),
      );
    }
  });
}
