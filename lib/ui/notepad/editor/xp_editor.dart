import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xp_notepad/domain/models/notepad_settings.dart';
import 'package:xp_notepad/domain/text/text_scan.dart';
import 'package:xp_notepad/ui/core/xp_scrollbar.dart';
import 'package:xp_notepad/ui/notepad/editor/longest_line_meter.dart';
import 'package:xp_notepad/ui/notepad/editor/notepad_text_controller.dart';
import 'package:xp_notepad/ui/notepad/editor/windowed_text.dart';
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
    this.windowed,
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

  /// Set for a large document. The text box then holds only the lines around what is on
  /// screen, taken from [windowed], and the space above and below them is empty room that
  /// keeps the scroll bar and the wheel working over the whole document.
  final WindowedText? windowed;

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

  // ---- A large document: the text box holds a window of it ----

  /// The text box needs an undo controller, but the window keeps its own undo list.
  final _windowUndo = UndoHistoryController();

  /// Empty room above and below the window, as tall as the lines that are not in it.
  double _topSpacer = 0;
  double _bottomSpacer = 0;

  /// Height of one line, as far as it is known. It sets the room that stands for the lines
  /// outside the window.
  double _rowHeight = 13;

  /// Height of the window as last laid out.
  double _windowHeight = 0;
  int _seenGeneration = 0;
  bool _shifting = false;
  bool _pointerDown = false;
  bool _checkQueued = false;

  /// True from a change of the window until it has been laid out. Its size and the
  /// positions in it cannot be read before that.
  bool _layoutPending = false;

  WindowedText? get _windowed => widget.windowed;

  @override
  void didUpdateWidget(XpEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The horizontal view exists only without word wrap, so its flag is stale after a switch.
    if (oldWidget.wordWrap != widget.wordWrap) _horizontalNeeded = false;
    if (_windowed != null &&
        (oldWidget.wordWrap != widget.wordWrap ||
            oldWidget.font != widget.font)) {
      // Lines have a different height now, so the room for the other lines is wrong.
      _layoutPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rebuildWindowAroundCaret();
      });
    }
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
    final windowed = _windowed;
    if (windowed != null) {
      windowed.addListener(_onWindowChanged);
      _vertical.addListener(_onScrolled);
      _seenGeneration = windowed.generation;
      _rowHeight = _plainRowHeight();
      _resetSpacers();
      _layoutPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _layoutPending = false;
        _afterLayout();
        if (widget.controller.selection.extentOffset > 0) _centerCaret();
      });
    }
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
    _windowed?.removeListener(_onWindowChanged);
    _vertical.removeListener(_onScrolled);
    _vertical.dispose();
    _horizontal.dispose();
    _windowUndo.dispose();
    super.dispose();
  }

  void _revealCaret() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _editableKey.currentState;
      final offset = widget.controller.selection.extentOffset;
      if (!mounted || state == null || offset < 0) return;
      final windowed = _windowed;
      if (windowed != null) {
        if (!windowed.covers(offset)) {
          // The caret is in a part of the document the window does not hold. Rebuilding
          // the window moves the text box there; _onWindowChanged scrolls to it.
          windowed.teleportTo(offset);
          return;
        }
        final render = state.renderEditable;
        final caret = render.getLocalRectForCaret(
          TextPosition(offset: offset - windowed.start),
        );
        render.showOnScreen(rect: caret.inflate(4));
        return;
      }
      final render = state.renderEditable;
      final caret = render.getLocalRectForCaret(TextPosition(offset: offset));
      render.showOnScreen(rect: caret.inflate(4));
    });
  }

  // ---- Keeping the window where the user is looking ----

  /// The height of a line in the editor's font, found without a text box.
  double _plainRowHeight() {
    final painter = TextPainter(
      text: TextSpan(text: 'X', style: XpText.editor(widget.font)),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height <= 0 ? 13 : height;
  }

  /// Sizes the empty room around the window from the line numbers, which is exact when
  /// every line is one row high and close when lines wrap.
  void _resetSpacers() {
    final windowed = _windowed!;
    _topSpacer = windowed.startLine * _rowHeight;
    final below =
        windowed.lineCount - windowed.startLine - windowed.viewLineCount;
    _bottomSpacer = below > 0 ? below * _rowHeight : 0;
  }

  void _onWindowChanged() {
    final windowed = _windowed;
    if (windowed == null || _shifting) return;
    if (windowed.generation == _seenGeneration) return;
    // The window was rebuilt around another part of the document.
    _seenGeneration = windowed.generation;
    setState(_resetSpacers);
    _layoutPending = true;
    _scrollNearCaret();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _layoutPending = false;
      _afterLayout();
      _centerCaret();
    });
  }

  /// The text box cannot be measured yet, so put the caret about where it will be. The
  /// first frame then already shows the right part of the document.
  void _scrollNearCaret() {
    final windowed = _windowed!;
    if (!_vertical.hasClients) return;
    final position = _vertical.position;
    if (!position.hasViewportDimension) return;
    final offset = widget.controller.selection.extentOffset;
    if (offset < 0) return;
    final line = windowed.lineIndexAt(offset);
    final target =
        line * _rowHeight - (position.viewportDimension - _rowHeight) / 2;
    position.jumpTo(target < 0 ? 0 : target);
  }

  /// Scrolls so that the caret is in the middle of the screen, once the text box has been
  /// laid out and the caret's place in it is known.
  void _centerCaret() {
    final windowed = _windowed;
    final render = _editableKey.currentState?.renderEditable;
    if (windowed == null ||
        render == null ||
        !_vertical.hasClients ||
        !_vertical.position.hasViewportDimension) {
      return;
    }
    final offset = widget.controller.selection.extentOffset;
    if (offset < 0 || offset < windowed.start || offset > windowed.end) return;
    final caret = render.getLocalRectForCaret(
      TextPosition(offset: offset - windowed.start),
    );
    final position = _vertical.position;
    final target =
        _topSpacer +
        caret.top -
        (position.viewportDimension - caret.height) / 2;
    final limit = position.hasContentDimensions
        ? position.maxScrollExtent
        : double.infinity;
    position.jumpTo(target.clamp(0.0, limit));
    // The caret may also be out of sight sideways, for example at the start of a line when
    // the view was scrolled along a long line before.
    render.showOnScreen(rect: caret.inflate(4));
  }

  void _rebuildWindowAroundCaret() {
    final windowed = _windowed;
    if (windowed == null) return;
    _rowHeight = _plainRowHeight();
    final offset = widget.controller.selection.extentOffset;
    windowed.teleportTo(offset < 0 ? 0 : offset);
    // teleportTo has reset the spacers through _onWindowChanged.
  }

  /// Records what a laid-out window says about line heights and its own height.
  void _afterLayout() {
    final windowed = _windowed;
    final render = _editableKey.currentState?.renderEditable;
    if (windowed == null || render == null || !render.hasSize) return;
    _windowHeight = render.size.height;
    final lines = windowed.viewLineCount;
    if (lines >= 20) _rowHeight = _windowHeight / lines;
  }

  void _onScrolled() {
    final windowed = _windowed;
    if (windowed == null || _shifting || !_vertical.hasClients) return;
    if (!_layoutPending) {
      final position = _vertical.position;
      if (position.hasContentDimensions && _windowHeight > 0) {
        final pixels = position.pixels;
        final outside =
            pixels + position.viewportDimension < _topSpacer ||
            pixels > _topSpacer + _windowHeight;
        if (outside) {
          // The scroll bar was dragged somewhere the window does not reach. Rebuild the
          // window before the next frame, so that frame does not draw empty room.
          _teleportToScroll(pixels);
          return;
        }
      }
    }
    _requestCheck();
  }

  void _teleportToScroll(double pixels) {
    final windowed = _windowed!;
    final line = (pixels / _rowHeight).floor().clamp(0, windowed.lineCount - 1);
    final offset = windowed.offsetOfLine(line);
    _shifting = true;
    try {
      windowed.teleportTo(offset);
    } finally {
      _shifting = false;
    }
    _seenGeneration = windowed.generation;
    setState(_resetSpacers);
    _layoutPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _layoutPending = false;
      _afterLayout();
      _requestCheck();
    });
  }

  void _requestCheck() {
    if (_checkQueued || _windowed == null) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (mounted) _checkWindow();
    });
  }

  /// Moves the window when the screen is close to one of its edges, or when it holds a lot
  /// more than the screen shows.
  void _checkWindow() {
    final windowed = _windowed;
    final render = _editableKey.currentState?.renderEditable;
    if (windowed == null ||
        render == null ||
        _shifting ||
        _layoutPending ||
        _pointerDown ||
        !render.hasSize ||
        !_vertical.hasClients) {
      return;
    }
    final composing = windowed.view.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    final position = _vertical.position;
    if (!position.hasContentDimensions) return;
    _afterLayout();

    final top = position.pixels - _topSpacer;
    final bottom = top + position.viewportDimension;
    if (bottom < 0 || top > _windowHeight) {
      _teleportToScroll(position.pixels);
      return;
    }
    int charAt(double y) {
      final local = Offset(0, y.clamp(0.0, _windowHeight - 1.0));
      return render.getPositionForPoint(render.localToGlobal(local)).offset;
    }

    final viewLength = windowed.view.text.length;
    final above = charAt(top);
    final below = viewLength - charAt(bottom);
    final document = windowed.master.text;
    final needTop =
        (windowed.start > 0 && above < windowed.triggerCharacters) ||
        above > 3 * windowed.marginCharacters;
    final needBottom =
        (windowed.end < document.length &&
            below < windowed.triggerCharacters) ||
        below > 3 * windowed.marginCharacters;
    if (!needTop && !needBottom) return;
    final newStart = needTop
        ? TextScan.lineStartBefore(
            document,
            windowed.start + above,
            windowed.marginCharacters,
          )
        : windowed.start;
    final newEnd = needBottom
        ? TextScan.lineEndAfter(
            document,
            windowed.start + viewLength - below,
            windowed.marginCharacters,
          )
        : windowed.end;
    _shift(windowed, render, newStart, newEnd);
  }

  /// Moves the window and sizes the room around it, so the text on screen stays exactly
  /// where it was.
  void _shift(
    WindowedText windowed,
    RenderEditable render,
    int newStart,
    int newEnd,
  ) {
    final width = render.size.width;
    final style = XpText.editor(widget.font);
    final scaler = MediaQuery.textScalerOf(context);
    double heightOf(String lines, {required bool leadingFeed}) =>
        _heightOfLines(lines, leadingFeed, style, scaler, width);

    _shifting = true;
    final WindowShift shift;
    try {
      shift = windowed.moveWindow(newStart, newEnd);
    } finally {
      _shifting = false;
    }
    final removedTop = heightOf(shift.removedBefore, leadingFeed: false);
    final addedTop = heightOf(shift.addedBefore, leadingFeed: false);
    final removedBottom = heightOf(shift.removedAfter, leadingFeed: true);
    final addedBottom = heightOf(shift.addedAfter, leadingFeed: true);

    // Text that left the top makes the room above taller by its height, and text that
    // entered makes it shorter, so the lines in view keep their place on screen.
    var top = _topSpacer + removedTop - addedTop;
    var bottom = _bottomSpacer + removedBottom - addedBottom;
    var correction = 0.0;
    if (windowed.start == 0 || top < 0) {
      // Nothing lies above the first line, and room cannot be negative. The lines in view
      // are kept in place by moving the scroll position by what was taken away.
      correction = -top;
      top = 0;
    }
    if (windowed.end >= windowed.master.text.length || bottom < 0) bottom = 0;
    setState(() {
      _topSpacer = top;
      _bottomSpacer = bottom;
    });
    if (correction != 0) {
      final position = _vertical.position;
      position.jumpTo(position.pixels + correction);
    }
    _layoutPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _layoutPending = false;
      _afterLayout();
      _requestCheck();
    });
  }

  /// Height of whole lines laid out like the text box lays them out. [lines] ends with a
  /// line feed, or begins with one when [leadingFeed] is set.
  double _heightOfLines(
    String lines,
    bool leadingFeed,
    TextStyle style,
    TextScaler scaler,
    double width,
  ) {
    if (lines.isEmpty) return 0;
    final text = leadingFeed ? '${lines.substring(1)}\n' : lines;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: width);
    // The caret after the last line feed sits at the top of an empty line below the text,
    // so its distance from the caret at the start is the height of all the lines.
    final end = painter.getOffsetForCaret(
      TextPosition(offset: text.length),
      Rect.zero,
    );
    final start = painter.getOffsetForCaret(
      const TextPosition(offset: 0),
      Rect.zero,
    );
    painter.dispose();
    return end.dy - start.dy;
  }

  static final _caretKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.backspace,
    LogicalKeyboardKey.delete,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  /// A key that moves the caret or types. If the view was scrolled away from the caret,
  /// the text box would act on the edge of the window instead, so the window is first
  /// brought back to the caret, as any editor scrolls back to it. The key itself goes on
  /// to the text box, which now finds the caret where it belongs.
  KeyEventResult _onEditorKey(FocusNode node, KeyEvent event) {
    final windowed = _windowed;
    if (windowed == null || event is KeyUpEvent || !windowed.caretOutside) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final bool acts;
    if (_caretKeys.contains(key)) {
      // Ctrl+Home and Ctrl+End are made on the whole document by the window itself.
      acts =
          !((key == LogicalKeyboardKey.home || key == LogicalKeyboardKey.end) &&
              keyboard.isControlPressed);
    } else {
      final character = event.character;
      acts =
          character != null &&
          character.isNotEmpty &&
          !keyboard.isControlPressed &&
          !keyboard.isAltPressed &&
          !keyboard.isMetaPressed;
    }
    if (acts) windowed.teleportTo(widget.controller.selection.extentOffset);
    return KeyEventResult.ignored;
  }

  late final _meter = widget.meter ?? LongestLineMeter();

  @override
  Widget build(BuildContext context) {
    final style = XpText.editor(widget.font);
    final windowed = _windowed;
    final box = Semantics(
      label: 'Text editor',
      child: EditableText(
        key: _editableKey,
        controller: windowed?.view ?? widget.controller,
        focusNode: widget.focusNode,
        undoController: windowed == null ? widget.undoHistory : _windowUndo,
        style: style,
        cursorColor: XpColors.text,
        backgroundCursorColor: XpColors.grayText,
        selectionColor: XpColors.highlight,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        cursorWidth: 1,
      ),
    );

    // For a large document the keys are watched on their way to the text box: see
    // _onEditorKey.
    final editable = windowed == null
        ? box
        : Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onEditorKey,
            child: box,
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
    final windowed = _windowed;
    if (windowed != null) {
      return _buildWindowedText(constraints, style, editable);
    }
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

  /// The text box of a large document: the window between two empty spaces that stand for
  /// the lines outside it. A pointer that is down keeps the window from moving under a
  /// selection being dragged.
  Widget _buildWindowedText(
    BoxConstraints constraints,
    TextStyle style,
    Widget editable,
  ) {
    final windowed = _windowed!;
    Widget column(double width) => SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _topSpacer),
          editable,
          SizedBox(height: _bottomSpacer),
        ],
      ),
    );

    final Widget scrolled;
    if (widget.wordWrap) {
      scrolled = SingleChildScrollView(
        controller: _vertical,
        physics: const ClampingScrollPhysics(),
        child: column(constraints.maxWidth),
      );
    } else {
      scrolled = ListenableBuilder(
        listenable: windowed,
        builder: (context, _) {
          final longest = _meter.measureLine(windowed.longestLine, style);
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
                child: column(contentWidth),
              ),
            ),
          );
        },
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _pointerDown = true,
      onPointerUp: (_) {
        _pointerDown = false;
        _requestCheck();
      },
      onPointerCancel: (_) {
        _pointerDown = false;
        _requestCheck();
      },
      child: scrolled,
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
