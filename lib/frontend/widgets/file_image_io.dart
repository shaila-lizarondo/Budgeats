import 'dart:io';
import 'package:flutter/material.dart';

Widget buildNativeFileImage(String path, {BoxFit fit = BoxFit.cover}) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
  } catch (_) {}
  return const SizedBox.shrink();
}
