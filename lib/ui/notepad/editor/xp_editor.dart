import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/notepad/editor/longest_line_meter.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/theme/xp_palette.dart';
import 'package:xp_notepad/ui/theme/xp_text.dart';

/// The XP edit control: a white, bordered text area with a vertical scrollbar, and a
/// horizontal one when word wrap is off. Text editing, undo and the caret come from
/// [EditableText]. This widget adds the scrolling, wrapping and reveal behaviour.
class XpEditor extends StatefulWidget {
  const XpEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.undoHistory,
    required this.font,
    required this.wordWrap,
    required this.revealSerial,
    required this.onTab,
    this.meter,
  });

  final NotepadTextController controller;
  final FocusNode focusNode;
  final UndoHistoryController undoHistory;
  final EditorFont font;
  final bool wordWrap;

  /// Increments when the caret should be scrolled into view, such as after Find.
  final ValueListenable<int> revealSerial;

  /// Tab inserts a tab character instead of moving focus, as in Notepad.
  final VoidCallback onTab;

  /// Measures the longest line when word wrap is off. Tests pass their own to count the
  /// measurements. The editor makes one for itself when this is null.
  final LongestLineMeter? meter;

  @override
  State<XpEditor> createState() => _XpEditorState();
}

class _XpEditorState extends State<XpEditor> {
  final _editableKey = GlobalKey<EditableTextState>();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  // As in XP, a scroll bar appears only when the text overflows that way.
  bool _verticalNeeded = false;
  bool _horizontalNeeded = false;

  @override
  void didUpdateWidget(XpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The horizontal view exists only without word wrap, so its flag is stale after a switch.
    if (oldWidget.wordWrap != widget.wordWrap) _horizontalNeeded = false;
  }

  void _onScrollMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    final needed = metrics.maxScrollExtent > 0;
    if (metrics.axis == Axis.vertical) {
      if (needed != _verticalNeeded) setState(() => _verticalNeeded = needed);
    } else if (needed != _horizontalNeeded) {
      setState(() => _horizontalNeeded = needed);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.revealSerial.addListener(_revealCaret);
    // A new EditableText opens its keyboard connection only on a focus change, so one built
    // under a focus node that already has focus, as after File > New or Open, would ignore
    // typing until a click. Requesting the keyboard here does what a click does.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.focusNode.hasFocus) {
        _editableKey.currentState?.requestKeyboard();
      }
    });
  }

  @override
  void dispose() {
    widget.revealSerial.removeListener(_revealCaret);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _revealCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _editableKey.currentState;
      final offset = widget.controller.selection.extentOffset;
      if (!mounted || state == null || offset < 0) return;
      final render = state.renderEditable;
      final caret = render.getLocalRectForCaret(TextPosition(offset: offset));
      render.showOnScreen(rect: caret.inflate(4));
    });
  }

  late final _meter = widget.meter ?? LongestLineMeter();

  @override
  Widget build(BuildContext context) {
    final style = XpText.editor(widget.font);
    final editable = Semantics(
      label: 'Text editor',
      child: EditableText(
        key: _editableKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        undoController: widget.undoHistory,
        style: style,
        cursorColor: XpColors.text,
        backgroundCursorColor: XpColors.grayText,
        selectionColor: XpColors.highlight,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        cursorWidth: 1,
      ),
    );

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.tab): widget.onTab},
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: XpColors.paper,
          border: Border.all(color: XpColors.editBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(2, 1, 2, 0),
                      child: NotificationListener<ScrollMetricsNotification>(
                        onNotification: (notification) {
                          _onScrollMetrics(notification);
                          return false;
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildText(constraints, style, editable);
                          },
                        ),
                      ),
                    ),
                  ),
                  if (_horizontalNeeded)
                    SizedBox(
                      height: XpMetrics.scrollbar,
                      child: XpScrollBar(
                        controller: _horizontal,
                        axis: Axis.horizontal,
                        lineStep: 8,
                      ),
                    ),
                ],
              ),
            ),
            if (_verticalNeeded)
              SizedBox(
                width: XpMetrics.scrollbar,
                child: Column(
                  // Stretch so the corner box fills the bar's width. Otherwise an empty
                  // ColoredBox collapses to zero width and the corner shows the paper colour.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: XpScrollBar(
                        controller: _vertical,
                        axis: Axis.vertical,
                      ),
                    ),
                    if (_horizontalNeeded)
                      SizedBox(
                        height: XpMetrics.scrollbar,
                        child: ColoredBox(color: XpColors.face),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildText(
    BoxConstraints constraints,
    TextStyle style,
    Widget editable,
  ) {
    if (widget.wordWrap) {
      return SingleChildScrollView(
        controller: _vertical,
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          width: constraints.maxWidth,
          child: _fillViewport(constraints, editable),
        ),
      );
    }
    // EditableText has no soft-wrap switch, so the text box is made wider than its longest
    // line. Lines then never wrap, and the horizontal scrollbar pans across them.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final longest = _meter.measure(widget.controller.text, style);
        final contentWidth = math.max(constraints.maxWidth, longest + 16);
        return SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              controller: _vertical,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: contentWidth,
                child: _fillViewport(constraints, editable),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Makes the text box at least as tall as the visible area. EditableText's tap region
  /// is only as tall as its text, so a click in the blank area below a short document
  /// counted as outside the editor and dropped focus. Filling the area keeps the click
  /// in the edit control, which places the caret at the nearest position, as XP does.
  Widget _fillViewport(BoxConstraints constraints, Widget editable) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: editable,
    );
  }
}
