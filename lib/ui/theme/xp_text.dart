import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';

/// Text styles for the XP chrome and the editor. Each style lists fallbacks, so the look
/// holds where the original Microsoft fonts are missing (Linux, for example).
abstract final class XpText {
  static const _uiFamily = 'Tahoma';
  static const _uiFallback = <String>[
    'Liberation Sans',
    'Arial',
    'Helvetica',
    'sans-serif',
  ];
  static const _monoFallback = <String>[
    'Liberation Mono',
    'Noto Sans Mono',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  /// Tahoma 8pt is 11px. Where Tahoma is missing, Liberation Sans is drawn at 95%.
  static double get uiSize =>
      defaultTargetPlatform == TargetPlatform.windows ? 11 : 10.45;

  static TextStyle ui({Color? color}) {
    return TextStyle(
      fontFamily: _uiFamily,
      fontFamilyFallback: _uiFallback,
      fontSize: uiSize,
      color: color ?? XpColors.text,
    );
  }

  static TextStyle title({required bool active}) {
    return TextStyle(
      fontFamily: 'Trebuchet MS',
      fontFamilyFallback: _uiFallback,
      fontSize: uiSize,
      fontWeight: FontWeight.bold,
      color: active ? const Color(0xFFFFFFFF) : XpColors.titleInactiveText,
      shadows: active
          ? [Shadow(color: XpColors.titleShadow, offset: Offset(1, 1))]
          : null,
    );
  }

  /// The editor font. The default Lucida Console 10pt uses XP's 13px line pitch.
  static TextStyle editor(EditorFont font) {
    final pixels = font.sizePixels;
    final isDefault = font.family == 'Lucida Console' && font.sizePoints == 10;
    final monospaced =
        font.family == 'Lucida Console' ||
        font.family == 'Courier New' ||
        font.family == 'Consolas';
    return TextStyle(
      fontFamily: font.family,
      fontFamilyFallback: monospaced ? _monoFallback : _uiFallback,
      fontSize: pixels,
      fontWeight: font.style.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: font.style.isItalic ? FontStyle.italic : FontStyle.normal,
      height: isDefault ? 13 / pixels : null,
      color: XpColors.text,
    );
  }
}
