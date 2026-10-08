import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a font file by name under /usr/share/fonts, or null when it is not installed.
File? findFont(String name) {
  final root = Directory('/usr/share/fonts');
  if (!root.existsSync()) return null;
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith(name)) return entity;
  }
  return null;
}

/// Loads the Liberation fonts for the goldens. The test engine ignores fontFamilyFallback,
/// so each XP family name the styles ask for is registered directly with a Liberation face.
/// The app itself relies on the real fallback chain, which Flutter applies on desktop.
Future<bool> loadLiberationFonts() async {
  final sansRegular = findFont('LiberationSans-Regular.ttf');
  final sansBold = findFont('LiberationSans-Bold.ttf');
  final monoRegular = findFont('LiberationMono-Regular.ttf');
  if (sansRegular == null || sansBold == null || monoRegular == null) {
    return false;
  }

  Future<ByteData> bytesOf(File file) async {
    final list = await file.readAsBytes();
    return ByteData.view(Uint8List.fromList(list).buffer);
  }

  for (final family in ['Tahoma', 'Trebuchet MS', 'Liberation Sans']) {
    final loader = FontLoader(family)
      ..addFont(bytesOf(sansRegular))
      ..addFont(bytesOf(sansBold));
    await loader.load();
  }
  for (final family in ['Lucida Console', 'Liberation Mono']) {
    final loader = FontLoader(family)..addFont(bytesOf(monoRegular));
    await loader.load();
  }
  return true;
}
