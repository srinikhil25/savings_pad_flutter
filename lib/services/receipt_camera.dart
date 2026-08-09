import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Lecture 07: Handling Embedded Device Hardware — the camera.
///
/// The lecture notes record a limitation dated 2026.07.30: the `camera`
/// plugin and the Android NDK camera component are version-mismatched, and
/// the build fails on the Android emulator.
///
/// `image_picker` hands off to the platform's own camera activity instead of
/// binding the NDK camera libraries, so it is unaffected by that conflict and
/// also gives the gallery for free — useful when demoing on an emulator whose
/// camera is the "Virtual Scene".
class ReceiptCamera {
  ReceiptCamera({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Downscaled hard, because the photo is stored inside the Firestore
  /// document and a document cannot exceed 1 MiB. 900px at quality 55 lands
  /// around 40-120 KB for a receipt, which is plenty to read a total off.
  static const double _maxEdge = 900;
  static const int _quality = 55;

  Future<String?> capture({required bool fromGallery}) async {
    final XFile? shot = await _picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );
    if (shot == null) return null; // user backed out

    final bytes = await shot.readAsBytes();
    return base64Encode(bytes);
  }

  /// Decoding is needed to render the stored photo back into an Image widget.
  static Uint8List decode(String base64Photo) => base64Decode(base64Photo);

  static String sizeLabel(String base64Photo) {
    final kb = (base64Photo.length * 3 / 4 / 1024).round();
    return '$kb KB';
  }
}
