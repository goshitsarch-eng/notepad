import 'package:flutter/widgets.dart';

/// Luna (Windows XP blue) colours, with a dark variant. Light values come from the Luna
/// theme and the measured reference used by the earlier clone. Dark values are a
/// slate-grey version of the same roles.
///
/// [dark] is switched by the view model. Widgets read the colours in build, so they pick up
/// the change on the next rebuild. Painters record [dark] and repaint when it changes.
abstract final class XpColors {
  /// True while Dark Mode is on.
  static bool dark = false;

  static Color _pick(int light, int darkValue) =>
      Color(dark ? darkValue : light);

  static Color get face => _pick(0xFFECE9D8, 0xFF2D2D30);
  static Color get paper => _pick(0xFFFFFFFF, 0xFF1E1E1E);
  static Color get text => _pick(0xFF000000, 0xFFE6E6E6);
  static Color get grayText => _pick(0xFFACA899, 0xFF7A7A7A);
  static Color get highlight => _pick(0xFF316AC5, 0xFF2F5F9E);
  static Color get highlightText => _pick(0xFFFFFFFF, 0xFFFFFFFF);
  static Color get editBorder => _pick(0xFF7F9DB9, 0xFF4A4A52);
  static Color get ruleDark => _pick(0xFFACA899, 0xFF4A4A52);
  static Color get ruleLight => _pick(0xFFFFFFFF, 0xFF3A3A40);
  static Color get menuBorder => _pick(0xFF919B9C, 0xFF5A5A62);
  static Color get menuShadow => _pick(0x4D000000, 0x66000000);
  static Color get scrollTrack => _pick(0xFFFBFBF9, 0xFF252527);
  static Color get scrollButton => _pick(0xFFECEBE5, 0xFF3E3E42);
  static Color get scrollArrow => _pick(0xFFC9C9C2, 0xFFB5B5B5);
  static Color get thumbBorder => _pick(0xFF8DA4CE, 0xFF6F6F75);
  static Color get buttonBorder => _pick(0xFF003C74, 0xFF5C5C63);
  static Color get buttonDefaultRing => _pick(0xFF3C8FFD, 0xFF3C8FFD);
  static Color get buttonHoverRing => _pick(0xFFFBC761, 0xFFFBC761);
  static Color get buttonFocusRing => _pick(0xFF98B8EA, 0xFF98B8EA);
  static Color get checkMark => _pick(0xFF21A121, 0xFF5FB8FF);
  static Color get boxBorder => _pick(0xFF8E8F8F, 0xFF8E8F8F);
  static Color get captionActive => _pick(0xFF0050EE, 0xFF2A5C96);
  static Color get captionInactive => _pick(0xFF7A96DF, 0xFF3A4250);
  static Color get captionHover => _pick(0xFF3F7DF6, 0xFF3A6FB0);
  static Color get captionPressed => _pick(0xFF003DD7, 0xFF1B3354);
  static Color get closeButton => _pick(0xFFD3552F, 0xFFD3552F);
  static Color get closeButtonHover => _pick(0xFFE8704C, 0xFFE8704C);
  static Color get closeButtonPressed => _pick(0xFFB8421F, 0xFFB8421F);
  static Color get buttonGlyphEdge => const Color(0xB3FFFFFF);
  static Color get titleShadow => _pick(0xFF0F1089, 0xFF0B1A30);
  static Color get titleInactiveText => _pick(0xFFD8E4F8, 0xFFB9C2CF);

  /// Window frame bands, outermost first: left edge, then right and bottom edges.
  static List<Color> get frameLeft => dark
      ? const [
          Color(0xFF0C2442),
          Color(0xFF17375F),
          Color(0xFF245385),
          Color(0xFF1B4070),
        ]
      : const [
          Color(0xFF0019CF),
          Color(0xFF0831D9),
          Color(0xFF166AEE),
          Color(0xFF0855DD),
        ];

  static List<Color> get frameRightBottom => dark
      ? const [
          Color(0xFF081A30),
          Color(0xFF0F2B4D),
          Color(0xFF1D4A7E),
          Color(0xFF2A5D93),
        ]
      : const [
          Color(0xFF00138C),
          Color(0xFF001EA1),
          Color(0xFF003DDD),
          Color(0xFF0048F1),
        ];

  static List<Color> get frameInactive => dark
      ? const [
          Color(0xFF3A4250),
          Color(0xFF4B5563),
          Color(0xFF5A6474),
          Color(0xFF6B7689),
        ]
      : const [
          Color(0xFF7A96DF),
          Color(0xFFA2B8EA),
          Color(0xFFBFD0F2),
          Color(0xFFD8E4F8),
        ];
}

/// Luna gradients for title bars, buttons, check boxes and scrollbar thumbs.
abstract final class XpGradients {
  static LinearGradient get titleActive => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.08, 0.40, 0.88, 0.93, 0.95, 0.96, 1],
    colors: XpColors.dark
        ? const [
            Color(0xFF3D6EA8),
            Color(0xFF2A5C96),
            Color(0xFF244F85),
            Color(0xFF1F4679),
            Color(0xFF1D4272),
            Color(0xFF1A3B66),
            Color(0xFF16345A),
            Color(0xFF16345A),
          ]
        : const [
            Color(0xFF0997FF),
            Color(0xFF0053EE),
            Color(0xFF0050EE),
            Color(0xFF0066FF),
            Color(0xFF0066FF),
            Color(0xFF005BFF),
            Color(0xFF003DD7),
            Color(0xFF003DD7),
          ],
  );

  static LinearGradient get titleInactive => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.08, 0.88, 0.93, 0.96, 1],
    colors: XpColors.dark
        ? const [
            Color(0xFF4B5563),
            Color(0xFF3A4250),
            Color(0xFF3A4250),
            Color(0xFF424B5A),
            Color(0xFF3A4250),
            Color(0xFF3A4250),
          ]
        : const [
            Color(0xFFA6B9E6),
            Color(0xFF7A96DF),
            Color(0xFF7A96DF),
            Color(0xFF8CA5E4),
            Color(0xFF7A96DF),
            Color(0xFF7A96DF),
          ],
  );

  static LinearGradient get buttonFace => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.86, 1],
    colors: XpColors.dark
        ? const [Color(0xFF4A4A4F), Color(0xFF3A3A3E), Color(0xFF303034)]
        : const [Color(0xFFFFFFFF), Color(0xFFECEBE5), Color(0xFFD8D0C4)],
  );

  static LinearGradient get buttonPressed => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.08, 0.94, 1],
    colors: XpColors.dark
        ? const [
            Color(0xFF2A2A2D),
            Color(0xFF303034),
            Color(0xFF323236),
            Color(0xFF3A3A3E),
          ]
        : const [
            Color(0xFFCDCAC3),
            Color(0xFFE3E3DB),
            Color(0xFFE5E5DE),
            Color(0xFFF2F2F1),
          ],
  );

  static LinearGradient get checkBox => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: XpColors.dark
        ? const [Color(0xFF3C3C40), Color(0xFF2E2E31)]
        : const [Color(0xFFFFFFFF), Color(0xFFF0F0EA)],
  );

  static LinearGradient get scrollThumb => LinearGradient(
    colors: XpColors.dark
        ? const [Color(0xFF5B5B60), Color(0xFF46464B)]
        : const [Color(0xFFF6F9FF), Color(0xFFC1D2EE)],
  );
}

/// Sizes measured from Luna Notepad at 96 DPI, in logical pixels.
abstract final class XpMetrics {
  static const frame = 4.0;
  static const captionHeight = 30.0;
  static const menuBarHeight = 19.0;
  static const statusBarHeight = 19.0;
  static const scrollbar = 17.0;
  static const dialogTitleHeight = 25.0;
  static const menuRowHeight = 21.0;
  static const fieldHeight = 21.0;
  static const buttonWidth = 75.0;
  static const buttonHeight = 23.0;
}
