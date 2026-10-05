import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:flutter_vocabulary_app/main.dart';

class _OtherPicker extends ImagePickerPlatform {}

/// photo-from-gallery T1: gallery picks on Android use the system Photo
/// Picker (ADR-0001, spec AC-09); other platforms are left alone.
void main() {
  late ImagePickerPlatform original;
  setUp(() => original = ImagePickerPlatform.instance);
  tearDown(() => ImagePickerPlatform.instance = original);

  test('turns on the Photo Picker when the platform is Android', () {
    final android = ImagePickerAndroid();
    ImagePickerPlatform.instance = android;
    expect(android.useAndroidPhotoPicker, isFalse);

    useAndroidPhotoPicker();

    expect(android.useAndroidPhotoPicker, isTrue);
  });

  test('does nothing on a non-Android platform', () {
    final other = _OtherPicker();
    ImagePickerPlatform.instance = other;

    expect(useAndroidPhotoPicker, returnsNormally);
    expect(ImagePickerPlatform.instance, same(other));
  });
}
