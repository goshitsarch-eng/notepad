import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// A value and the label shown for it in combo boxes and list boxes.
class XpOption<T> {
  const XpOption(this.label, this.value);

  final String label;
  final T value;
}

/// A single-line XP text box (21px, 1px blue-grey border).
class XpTextBox extends StatelessWidget {
  const XpTextBox({
    super.key,
    required this.controller,
    required this.focusNode,
    this.width,
    this.autofocus = false,
    this.inputFormatters,
    this.onSubmitted,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final double? width;
  final bool autofocus;

  /// The name a screen reader gives the box. The visible label next to a box is a
  /// separate widget, so without this the box would be announced as unnamed.
  final String? semanticLabel;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    // A container, so each box is a node of its own. Otherwise every box of a dialog, and
    // the labels beside them, merge into one node.
    return Semantics(
      container: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: XpMetrics.fieldHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: XpColors.paper,
            border: Border.all(color: XpColors.editBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EditableText(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                style: XpText.ui(),
                cursorColor: XpColors.text,
                backgroundCursorColor: XpColors.grayText,
                selectionColor: XpColors.highlight,
                maxLines: 1,
                cursorWidth: 1,
                inputFormatters: inputFormatters,
                // Enter must not take focus out of the box. Without this callback EditableText
                // unfocuses on Enter, and the next keys then reach whatever had focus before.
                onEditingComplete: () {},
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A drop-down list in the Luna style. The list opens in an overlay below the box.
class XpComboBox<T> extends StatefulWidget {
  const XpComboBox({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.width,
    this.semanticLabel,
  });

  final List<XpOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// The name a screen reader gives the box, such as "Files of type".
  final String? semanticLabel;

  /// Null fills the width the parent gives the box.
  final double? width;

  @override
  State<XpComboBox<T>> createState() => _XpComboBoxState<T>();
}

class _XpComboBoxState<T> extends State<XpComboBox<T>> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  /// Set when the box is tapped, so the list opens above the box when there is no room
  /// below it, as XP's combo boxes do.
  bool _openUpward = false;

  void _select(T value) {
    _portal.hide();
    widget.onChanged(value);
  }

  void _toggle() {
    if (_portal.isShowing) {
      _portal.hide();
      return;
    }
    if (widget.options.isEmpty) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.attached) {
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      final room = MediaQuery.sizeOf(context).height - bottom;
      // Each row is _OptionRow.height tall, inside a 1px border.
      final list = widget.options.length * _OptionRow.height + 2;
      _openUpward = room < list;
    }
    _portal.show();
  }

  @override
  Widget build(BuildContext context) {
    // The box shows the option that matches the value, else the first one, else nothing.
    final selected =
        widget.options
            .where((option) => option.value == widget.value)
            .firstOrNull ??
        widget.options.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The popup takes the box's width from the layout constraints. Reading the box's
        // size from inside the overlay builder fails, because that runs during build.
        final popupWidth =
            widget.width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        // Flutter has no checked combo box role, so the box is a button whose value is
        // the option it shows.
        return Semantics(
          container: true,
          button: true,
          label: widget.semanticLabel,
          value: selected?.label ?? '',
          onTap: _toggle,
          excludeSemantics: true,
          child: OverlayPortal(
            controller: _portal,
            overlayChildBuilder: (context) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _portal.hide,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  CompositedTransformFollower(
                    link: _link,
                    showWhenUnlinked: false,
                    targetAnchor: _openUpward
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    followerAnchor: _openUpward
                        ? Alignment.bottomLeft
                        : Alignment.topLeft,
                    child: SizedBox(
                      width: popupWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: XpColors.paper,
                          border: Border.all(color: XpColors.editBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final option in widget.options)
                              _OptionRow(
                                label: option.label,
                                selected: option.value == widget.value,
                                onTap: () => _select(option.value),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            child: CompositedTransformTarget(
              link: _link,
              child: SizedBox(
                width: widget.width,
                height: XpMetrics.fieldHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: XpColors.paper,
                      border: Border.all(color: XpColors.editBorder),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(3, 0, 20, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                selected?.label ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: XpText.ui(),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 8,
                          child: CustomPaint(
                            size: Size(7, 4),
                            painter: _ArrowPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A scrollable list box with single selection. Rows are built lazily. The box takes
/// keyboard focus: Up and Down move the selection, and Home and End jump to the ends.
class XpListBox<T> extends StatefulWidget {
  const XpListBox({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.width,
    required this.height,
    this.onActivated,
    this.autofocus = false,
    this.semanticLabel,
  });

  final List<XpOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// The name a screen reader gives the list, such as "Font style".
  final String? semanticLabel;

  /// Null fills the width the parent gives the box.
  final double? width;
  final double height;

  /// Called on a double click, which in XP accepts the dialog.
  final ValueChanged<T>? onActivated;

  /// Takes keyboard focus when its dialog opens, so the arrow keys work at once.
  final bool autofocus;

  @override
  State<XpListBox<T>> createState() => _XpListBoxState<T>();
}

class _XpListBoxState<T> extends State<XpListBox<T>> {
  static const _rowHeight = 16.0;
  late final ScrollController _scroll;
  final _focus = FocusNode(debugLabel: 'list box');

  @override
  void initState() {
    super.initState();
    // Open the list with the current selection in view, as XP's list boxes do.
    final index = _selectedIndex;
    final offset = index < 0
        ? 0.0
        : math.max(0.0, index * _rowHeight - widget.height / 2);
    _scroll = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _selectedIndex =>
      widget.options.indexWhere((option) => option.value == widget.value);

  void _select(int index) {
    widget.onChanged(widget.options[index].value);
    WidgetsBinding.instance.addPostFrameCallback((_) => _keepVisible(index));
  }

  /// Scrolls just enough to show row [index], as a list box does when the selection moves.
  void _keepVisible(int index) {
    if (!mounted || !_scroll.hasClients) return;
    final top = index * _rowHeight;
    final bottom = top + _rowHeight;
    final position = _scroll.position;
    final viewport = position.viewportDimension;
    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > position.pixels + viewport) {
      _scroll.jumpTo(bottom - viewport);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final last = widget.options.length - 1;
    if (last < 0) return KeyEventResult.ignored;
    final current = math.max(_selectedIndex, 0);
    final key = event.logicalKey;
    final int target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = math.min(current + 1, last);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = math.max(current - 1, 0);
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = last;
    } else {
      return KeyEventResult.ignored;
    }
    if (target != _selectedIndex) _select(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // The border and padding take 4 logical pixels. As in XP, the bar is shown only when
    // the rows do not fit.
    final overflows = widget.options.length * _rowHeight > widget.height - 4;
    return Semantics(
      container: true,
      label: widget.semanticLabel,
      explicitChildNodes: true,
      child: Focus(
        focusNode: _focus,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: ListenableBuilder(
          listenable: _focus,
          builder: (context, _) => SizedBox(
            width: widget.width,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: XpColors.paper,
                // A dark border shows where the keyboard is.
                border: Border.all(
                  color: _focus.hasFocus ? XpColors.text : XpColors.editBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        itemExtent: _rowHeight,
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final option = widget.options[index];
                          final selected = option.value == widget.value;
                          return _ListRow(
                            label: option.label,
                            selected: selected,
                            onTap: () {
                              _focus.requestFocus();
                              widget.onChanged(option.value);
                            },
                            onDoubleTap: widget.onActivated == null
                                ? null
                                : () => widget.onActivated!(option.value),
                          );
                        },
                      ),
                    ),
                    if (overflows)
                      XpScrollBar(
                        controller: _scroll,
                        axis: Axis.vertical,
                        lineStep: _rowHeight,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled frame around a group of controls, as XP's group boxes are drawn.
class XpGroupBox extends StatelessWidget {
  const XpGroupBox({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The legend is centred on the top border, so the box has room above it, and the
    // content starts below the legend.
    return Semantics(
      container: true,
      label: label,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
              decoration: BoxDecoration(
                border: Border.all(color: XpColors.ruleDark),
              ),
              child: child,
            ),
            Positioned(
              left: 6,
              top: -8,
              child: Container(
                color: XpColors.face,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(label, style: XpText.ui()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const height = 16.0;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.only(left: 3),
          alignment: Alignment.centerLeft,
          color: selected ? XpColors.highlight : null,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: XpText.ui(
              color: selected ? XpColors.highlightText : XpColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Select on tap-down, so a single click does not wait out the double-click window.
        onTapDown: (_) => onTap(),
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.only(left: 3),
          alignment: Alignment.centerLeft,
          color: selected ? XpColors.highlight : null,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: XpText.ui(
              color: selected ? XpColors.highlightText : XpColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter() : dark = XpColors.dark;

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(7, 0)
      ..lineTo(3.5, 4)
      ..close();
    canvas.drawPath(path, Paint()..color = XpColors.text);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.dark != dark;
}
