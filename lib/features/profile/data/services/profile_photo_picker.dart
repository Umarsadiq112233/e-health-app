import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../domain/models/account_profile.dart';

abstract class ProfilePhotoPicker {
  Future<AvatarPhoto?> pick(ImageSource source);
  Future<AvatarPhoto?> recover();
}

class NativeProfilePhotoPicker implements ProfilePhotoPicker {
  final ImagePicker picker;
  NativeProfilePhotoPicker({ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  @override
  Future<AvatarPhoto?> pick(ImageSource source) async {
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      return file == null ? null : await _prepare(file);
    } on PlatformException catch (error) {
      throw ProfileEditFailure(switch (error.code) {
        'camera_access_denied' ||
        'photo_access_denied' ||
        'camera_access_restricted' ||
        'photo_access_restricted' => 'Photo access was denied. Allow camera or photo access in your phone’s app settings, then try again.',
        'camera_unavailable' || 'no_available_camera' => 'A camera is not available. Choose a photo from your gallery instead.',
        _ => 'Could not open the photo picker. Please try again.',
      });
    } on UnimplementedError {
      throw const ProfileEditFailure(
        'A camera is not available on this device. Choose from Gallery instead.',
      );
    }
  }

  @override
  Future<AvatarPhoto?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await picker.retrieveLostData();
    if (response.exception != null) {
      throw const ProfileEditFailure(
        'The previous photo selection could not be recovered. Please select it again.',
      );
    }
    return response.files?.isNotEmpty == true
        ? _prepare(response.files!.first)
        : null;
  }

  Future<AvatarPhoto> _prepare(XFile file) async {
    if (await file.length() > 12 * 1024 * 1024) {
      throw const ProfileEditFailure('Choose a photo smaller than 12 MB.');
    }
    return AvatarPhoto(await compute(prepareAvatar, await file.readAsBytes()));
  }
}

/// Decode content rather than trusting extensions/MIME supplied by a picker.
/// Bake EXIF orientation, discard metadata and normalize uploads to JPEG.
Uint8List prepareAvatar(Uint8List bytes) {
  if (bytes.length > 12 * 1024 * 1024) {
    throw const ProfileEditFailure('Choose a photo smaller than 12 MB.');
  }
  if (bytes.length < 16) {
    throw const ProfileEditFailure(
      "This photo could not be read. Choose another image.",
    );
  }
  final decoder = img.findDecoderForData(bytes);
  if (decoder is! img.JpegDecoder &&
      decoder is! img.PngDecoder &&
      decoder is! img.WebPDecoder) {
    throw const ProfileEditFailure(
      'Choose a JPEG, PNG or WebP photo. HEIC photos may need conversion to JPEG.',
    );
  }
  if (!decoder!.isValidFile(bytes)) {
    throw const ProfileEditFailure(
      'This photo could not be read. Choose another image.',
    );
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > 25000000) {
    throw const ProfileEditFailure('Choose a photo under 25 megapixels.');
  }
  final decoded = decoder.decode(bytes);
  if (decoded == null) {
    throw const ProfileEditFailure('This photo could not be read.');
  }
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest > 1024
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? 1024 : null,
          height: oriented.height > oriented.width ? 1024 : null,
        )
      : oriented;
  final flattened = img.Image(width: resized.width, height: resized.height)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(flattened, resized);
  final result = Uint8List.fromList(img.encodeJpg(flattened, quality: 85));
  AvatarPhoto(result).validate();
  return result;
}
