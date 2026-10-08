import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_icons.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// A menu label such as "&File" or "Page Se&tup...". The character after '&' is the
/// mnemonic, which is underlined while the keyboard cues are showing.
class MenuLabel {
  const MenuLabel._(this.text, this.mnemonicIndex);

  factory MenuLabel.parse(String raw) {
    final amp = raw.indexOf('&');
    if (amp < 0 || amp == raw.length - 1) return MenuLabel._(raw, null);
    return MenuLabel._(raw.replaceFirst('&', ''), amp);
  }

  /// The label without the '&' marker.
  final String text;

  /// Index into [text] of the mnemonic character, if there is one.
  final int? mnemonicIndex;

  /// The lower-case mnemonic letter, used to match key presses.
  String? get mnemonic {
    final index = mnemonicIndex;
    return index == null ? null : text[index].toLowerCase();
  }

  TextSpan span(TextStyle style, {required bool underline}) {
    final index = mnemonicIndex;
    if (!underline || index == null) return TextSpan(text: text, style: style);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, index)),
        TextSpan(
          text: text[index],
          style: style.copyWith(decoration: TextDecoration.underline),
        ),
        TextSpan(text: text.substring(index + 1)),
      ],
    );
  }
}

/// One row of a popup menu, or a separator line.
class XpMenuItem {
  const XpMenuItem({
    required this.label,
    this.shortcut,
    this.enabled = true,
    this.checked = false,
    this.onSelected,
  }) : isSeparator = false;

  const XpMenuItem.separator()
    : label = '',
      shortcut = null,
      enabled = false,
      checked = false,
      onSelected = null,
      isSeparator = true;

  final String label;
  final String? shortcut;
  final bool enabled;
  final bool checked;
  final VoidCallback? onSelected;
  final bool isSeparator;
}

/// A top-level menu: its label and the rows of its popup.
class XpMenu {
  const XpMenu(this.label, this.items);

  final String label;
  final List<XpMenuItem> items;
}

/// Widths that Luna menus reserve, measured from the Luna menu metrics.
abstract final class XpMenuLayout {
  static const _labelPadding = 11.0;
  static const _rowLeftInset = 22.0;
  static const _rowRightInset = 20.0;
  static const _shortcutGap = 24.0;
  static const _minWidth = 168.0;

  /// Width of a menu-bar label, including its 5.5px padding on each side.
  static double barLabelWidth(String label) {
    return measureUiText(MenuLabel.parse(label).text) + _labelPadding;
  }

  static double popupWidth(List<XpMenuItem> items) {
    var width = _minWidth;
    for (final item in items) {
      if (item.isSeparator) continue;
      final label = measureUiText(MenuLabel.parse(item.label).text);
      final shortcut = item.shortcut == null
          ? 0.0
          : _shortcutGap + measureUiText(item.shortcut!);
      width = math.max(
        width,
        _rowLeftInset + label + shortcut + _rowRightInset,
      );
    }
    return width;
  }
}

/// The Luna menu bar: a 19px face-coloured strip of labels.
class XpMenuBar extends StatelessWidget {
  const XpMenuBar({
    super.key,
    required this.menus,
    required this.openIndex,
    required this.showMnemonics,
    required this.onPressed,
    required this.onHovered,
  });

  final List<XpMenu> menus;
  final int? openIndex;
  final bool showMnemonics;
  final ValueChanged<int> onPressed;
  final ValueChanged<int> onHovered;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: XpMetrics.menuBarHeight,
      color: XpColors.face,
      child: Row(
        children: [
          for (var i = 0; i < menus.length; i++)
            _MenuBarLabel(
              label: menus[i].label,
              open: openIndex == i,
              showMnemonic: showMnemonics,
              onPressed: () => onPressed(i),
              onHovered: () => onHovered(i),
            ),
        ],
      ),
    );
  }
}

class _MenuBarLabel extends StatelessWidget {
  const _MenuBarLabel({
    required this.label,
    required this.open,
    required this.showMnemonic,
    required this.onPressed,
    required this.onHovered,
  });

  final String label;
  final bool open;
  final bool showMnemonic;
  final VoidCallback onPressed;
  final VoidCallback onHovered;

  @override
  Widget build(BuildContext context) {
    final parsed = MenuLabel.parse(label);
    final color = open ? XpColors.highlightText : XpColors.text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHovered(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressed(),
        child: Container(
          height: XpMetrics.menuBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 5.5),
          alignment: Alignment.center,
          color: open ? XpColors.highlight : null,
          child: Text.rich(
            parsed.span(XpText.ui(color: color), underline: showMnemonic),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

/// A popup menu under a menu-bar label. Rows highlight on hover or keyboard movement.
class XpMenuPopup extends StatelessWidget {
  const XpMenuPopup({
    super.key,
    required this.items,
    required this.highlight,
    required this.showMnemonics,
    required this.onHighlight,
    required this.onActivate,
  });

  final List<XpMenuItem> items;
  final int? highlight;
  final bool showMnemonics;
  final ValueChanged<int> onHighlight;
  final ValueChanged<int> onActivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: XpMenuLayout.popupWidth(items),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: XpColors.paper,
        border: Border.all(color: XpColors.menuBorder),
        boxShadow: [
          BoxShadow(
            color: XpColors.menuShadow,
            offset: Offset(2, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            if (items[i].isSeparator)
              const _MenuSeparator()
            else
              _MenuRow(
                item: items[i],
                highlighted: highlight == i,
                showMnemonic: showMnemonics,
                onEnter: () => onHighlight(i),
                onTap: () => onActivate(i),
              ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.highlighted,
    required this.showMnemonic,
    required this.onEnter,
    required this.onTap,
  });

  final XpMenuItem item;
  final bool highlighted;
  final bool showMnemonic;
  final VoidCallback onEnter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = item.enabled;
    final active = highlighted && enabled;
    final color = !enabled
        ? XpColors.grayText
        : (active ? XpColors.highlightText : XpColors.text);
    final label = MenuLabel.parse(item.label);
    return MouseRegion(
      onEnter: enabled ? (_) => onEnter() : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: XpMetrics.menuRowHeight,
          color: active ? XpColors.highlight : null,
          child: Stack(
            children: [
              if (item.checked)
                Positioned(
                  left: 7,
                  top: 6,
                  child: CustomPaint(
                    size: const Size.square(9),
                    painter: _CheckGlyphPainter(color),
                  ),
                ),
              Positioned(
                left: 22,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    label.span(
                      XpText.ui(color: color),
                      underline: showMnemonic,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              if (item.shortcut != null)
                Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      item.shortcut!,
                      maxLines: 1,
                      style: XpText.ui(color: color),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SizedBox(
        height: 2,
        child: Column(
          // Stretch, so each 1px rule spans the full width of the menu.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 1, child: ColoredBox(color: XpColors.ruleDark)),
            SizedBox(height: 1, child: ColoredBox(color: XpColors.ruleLight)),
          ],
        ),
      ),
    );
  }
}

class _CheckGlyphPainter extends CustomPainter {
  const _CheckGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, 4.5)
      ..lineTo(3.5, 7)
      ..lineTo(8, 1.5);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.square
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_CheckGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}
