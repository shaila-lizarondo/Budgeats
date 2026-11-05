import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'file_image_stub.dart'
    if (dart.library.io) 'file_image_io.dart';

Widget buildFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  if (kIsWeb) {
    return Image.network(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  } else {
    return buildNativeFileImage(path, fit: fit);
  }
}
