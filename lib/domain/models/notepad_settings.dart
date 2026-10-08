/// The smallest size the window may have, in logical pixels. The menu bar, caption and
/// status bar stop fitting below this.
const kMinimumWindowSize = (width: 400.0, height: 240.0);

/// The largest saved window size. Anything bigger in the settings file is treated as
/// damaged, so the window cannot open off the screen.
const _maximumSavedWindowSide = 8192.0;

/// Font styles offered by the Font dialog's "Font style" list.
enum FontFaceStyle {
  regular('Regular'),
  italic('Italic'),
  bold('Bold'),
  boldItalic('Bold Italic');

  const FontFaceStyle(this.label);

  final String label;

  bool get isBold => this == bold || this == boldItalic;
  bool get isItalic => this == italic || this == boldItalic;
}

/// The editor font chosen in Format > Font. Sizes are points, as the XP dialog shows them.
class EditorFont {
  const EditorFont({
    this.family = 'Lucida Console',
    this.sizePoints = 10,
    this.style = FontFaceStyle.regular,
  });

  /// Families listed in the Font dialog. Fonts missing on a platform fall back at draw time.
  static const families = <String>[
    'Arial',
    'Comic Sans MS',
    'Courier New',
    'Georgia',
    'Impact',
    'Lucida Console',
    'Lucida Sans Unicode',
    'Microsoft Sans Serif',
    'Palatino Linotype',
    'Tahoma',
    'Times New Roman',
    'Trebuchet MS',
    'Verdana',
  ];

  static const sizes = <int>[
    8,
    9,
    10,
    11,
    12,
    14,
    16,
    18,
    20,
    22,
    24,
    26,
    28,
    36,
    48,
    72,
  ];

  /// The smallest and largest sizes, in points, that the Font dialog accepts. A size read
  /// from the settings file outside this range falls back to the default.
  static const minimumSizePoints = 1.0;
  static const maximumSizePoints = 1638.0;

  final String family;
  final double sizePoints;
  final FontFaceStyle style;

  /// Pixel size at 96 DPI, which is how Windows XP draws point sizes.
  double get sizePixels => sizePoints * 96 / 72;

  EditorFont copyWith({
    String? family,
    double? sizePoints,
    FontFaceStyle? style,
  }) {
    return EditorFont(
      family: family ?? this.family,
      sizePoints: sizePoints ?? this.sizePoints,
      style: style ?? this.style,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EditorFont &&
        other.family == family &&
        other.sizePoints == sizePoints &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(family, sizePoints, style);

  Map<String, Object?> toJson() => {
    'family': family,
    'size': sizePoints,
    'style': style.name,
  };

  factory EditorFont.fromJson(Map<String, Object?> json) {
    return EditorFont(
      family: _text(json['family'], 'Lucida Console'),
      sizePoints: _fontPoints(json['size'], 10),
      style: _enumByName(
        FontFaceStyle.values,
        json['style'],
        FontFaceStyle.regular,
      ),
    );
  }
}

/// Header, footer and margins from File > Page Setup. Margins are in inches. The printer
/// lays out letter paper, so margins must leave at least an inch of printable space.
class PageSetup {
  const PageSetup({
    this.header = '&f',
    this.footer = 'Page &p',
    this.leftInches = 0.75,
    this.topInches = 1,
    this.rightInches = 0.75,
    this.bottomInches = 1,
  });

  final String header;
  final String footer;
  final double leftInches;
  final double topInches;
  final double rightInches;
  final double bottomInches;

  static const maximumMarginInches = 6.0;
  static const _letterWidthInches = 8.5;
  static const _letterHeightInches = 11.0;
  static const _minimumPrintableInches = 1.0;

  /// Why these margins cannot be used, or null when they can.
  String? get marginProblem {
    final margins = [leftInches, topInches, rightInches, bottomInches];
    if (margins.any((m) => !m.isFinite || m < 0 || m > maximumMarginInches)) {
      return 'Each margin must be from 0 to 6 inches.';
    }
    if (leftInches + rightInches >
        _letterWidthInches - _minimumPrintableInches) {
      return 'The left and right margins leave no room to print.';
    }
    if (topInches + bottomInches >
        _letterHeightInches - _minimumPrintableInches) {
      return 'The top and bottom margins leave no room to print.';
    }
    return null;
  }

  PageSetup copyWith({
    String? header,
    String? footer,
    double? leftInches,
    double? topInches,
    double? rightInches,
    double? bottomInches,
  }) {
    return PageSetup(
      header: header ?? this.header,
      footer: footer ?? this.footer,
      leftInches: leftInches ?? this.leftInches,
      topInches: topInches ?? this.topInches,
      rightInches: rightInches ?? this.rightInches,
      bottomInches: bottomInches ?? this.bottomInches,
    );
  }

  Map<String, Object?> toJson() => {
    'header': header,
    'footer': footer,
    'left': leftInches,
    'top': topInches,
    'right': rightInches,
    'bottom': bottomInches,
  };

  factory PageSetup.fromJson(Map<String, Object?> json) {
    // A margin outside the allowed range, or one that leaves no room to print, is damaged.
    // Those settings fall back to the defaults rather than failing the print later.
    final loaded = PageSetup(
      header: _text(json['header'], '&f'),
      footer: _text(json['footer'], 'Page &p'),
      leftInches: _inches(json['left'], 0.75),
      topInches: _inches(json['top'], 1),
      rightInches: _inches(json['right'], 0.75),
      bottomInches: _inches(json['bottom'], 1),
    );
    return loaded.marginProblem == null
        ? loaded
        : PageSetup(header: loaded.header, footer: loaded.footer);
  }
}

/// Everything Notepad remembers between runs.
class NotepadSettings {
  const NotepadSettings({
    this.wordWrap = true,
    this.statusBarVisible = true,
    this.font = const EditorFont(),
    this.pageSetup = const PageSetup(),
    this.lastDirectory,
    this.windowWidth = 600,
    this.windowHeight = 404,
    this.darkMode = false,
  });

  final bool wordWrap;

  /// The View > Status Bar setting. The bar is hidden while word wrap is on, as in XP.
  final bool statusBarVisible;
  final EditorFont font;
  final PageSetup pageSetup;
  final String? lastDirectory;
  final double windowWidth;
  final double windowHeight;
  final bool darkMode;

  NotepadSettings copyWith({
    bool? wordWrap,
    bool? statusBarVisible,
    EditorFont? font,
    PageSetup? pageSetup,
    String? lastDirectory,
    double? windowWidth,
    double? windowHeight,
    bool? darkMode,
  }) {
    return NotepadSettings(
      wordWrap: wordWrap ?? this.wordWrap,
      statusBarVisible: statusBarVisible ?? this.statusBarVisible,
      font: font ?? this.font,
      pageSetup: pageSetup ?? this.pageSetup,
      lastDirectory: lastDirectory ?? this.lastDirectory,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      darkMode: darkMode ?? this.darkMode,
    );
  }

  Map<String, Object?> toJson() => {
    'wordWrap': wordWrap,
    'statusBarVisible': statusBarVisible,
    'font': font.toJson(),
    'pageSetup': pageSetup.toJson(),
    'lastDirectory': lastDirectory,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
    'darkMode': darkMode,
  };

  factory NotepadSettings.fromJson(Map<String, Object?> json) {
    final font = json['font'];
    final pageSetup = json['pageSetup'];
    final lastDirectory = _text(json['lastDirectory'], '');
    return NotepadSettings(
      wordWrap: _flag(json['wordWrap'], true),
      statusBarVisible: _flag(json['statusBarVisible'], true),
      font: font is Map<String, Object?>
          ? EditorFont.fromJson(font)
          : const EditorFont(),
      pageSetup: pageSetup is Map<String, Object?>
          ? PageSetup.fromJson(pageSetup)
          : const PageSetup(),
      lastDirectory: lastDirectory.isEmpty ? null : lastDirectory,
      windowWidth: _windowSide(
        json['windowWidth'],
        600,
        kMinimumWindowSize.width,
      ),
      windowHeight: _windowSide(
        json['windowHeight'],
        404,
        kMinimumWindowSize.height,
      ),
      darkMode: _flag(json['darkMode'], false),
    );
  }
}

String _text(Object? value, String fallback) =>
    value is String ? value : fallback;

double _number(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

/// A font size from the settings file, or the fallback when the Font dialog could not have
/// chosen it. Sizes such as negative or huge ones leave the editor blank.
double _fontPoints(Object? value, double fallback) {
  final points = _number(value, fallback);
  return points.isFinite &&
          points >= EditorFont.minimumSizePoints &&
          points <= EditorFont.maximumSizePoints
      ? points
      : fallback;
}

/// A margin in inches from the settings file, or the fallback when it is not a usable
/// number.
double _inches(Object? value, double fallback) {
  final inches = _number(value, fallback);
  return inches.isFinite &&
          inches >= 0 &&
          inches <= PageSetup.maximumMarginInches
      ? inches
      : fallback;
}

bool _flag(Object? value, bool fallback) => value is bool ? value : fallback;

/// A saved window side, kept between the minimum and a sane maximum. Anything else falls
/// back to the default.
double _windowSide(Object? value, double fallback, double minimum) {
  final side = _number(value, fallback);
  if (!side.isFinite) return fallback;
  return side.clamp(minimum, _maximumSavedWindowSide).toDouble();
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
