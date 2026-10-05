// photo-from-gallery T2: the photo chain reads the image picker and the photo
// scaler through providers, so widget tests can swap in fakes.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/photo_scaler.dart';
import 'package:image_picker/image_picker.dart';

class _FakePicker extends ImagePicker {}

void main() {
  test('imagePickerProvider gives a real ImagePicker by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(imagePickerProvider), isA<ImagePicker>());
  });

  test('imagePickerProvider can be overridden with a fake', () {
    final fake = _FakePicker();
    final container = ProviderContainer(
      overrides: [imagePickerProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    expect(container.read(imagePickerProvider), same(fake));
  });

  test('photoScalerProvider still hands out the shared scaler', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(photoScalerProvider), same(PhotoScaler.instance));
  });
}
