import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Window events the app reacts to. The view model implements this.
abstract interface class WindowEventHandler {
  /// The user asked to close the window: the caption button, Alt+F4 or the window manager.
  void onCloseRequested();

  void onActiveChanged(bool active);

  void onMaximizedChanged(bool maximized);

  /// The window's size changed. On Linux this arrives continuously while an edge is
  /// dragged, so the handler should wait for the resize to settle before it acts.
  void onResized();
}

/// Edges and corners the user can drag to resize the borderless window.
enum ResizeDirection {
  top,
  left,
  right,
  bottom,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Borderless window control. XP draws its own caption, so the OS frame is removed.
abstract interface class WindowService {
  void attach(WindowEventHandler handler);

  Future<({double width, double height})> currentSize();

  Future<bool> isMaximized();

  Future<void> setSize(double width, double height);

  Future<void> setTitle(String title);

  Future<void> setPreventClose(bool prevent);

  Future<void> startDragging();

  Future<void> startResizing(ResizeDirection direction);

  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> closeWindow();
}

/// [WindowService] backed by the window_manager plugin.
class WindowManagerService with WindowListener implements WindowService {
  WindowEventHandler? _handler;

  @override
  void attach(WindowEventHandler handler) {
    _handler = handler;
    windowManager.addListener(this);
  }

  @override
  Future<({double width, double height})> currentSize() async {
    final bounds = await windowManager.getBounds();
    return (width: bounds.width, height: bounds.height);
  }

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> setSize(double width, double height) =>
      windowManager.setSize(Size(width, height));

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);

  @override
  Future<void> setPreventClose(bool prevent) =>
      windowManager.setPreventClose(prevent);

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> startResizing(ResizeDirection direction) {
    final edge = switch (direction) {
      ResizeDirection.top => ResizeEdge.top,
      ResizeDirection.left => ResizeEdge.left,
      ResizeDirection.right => ResizeEdge.right,
      ResizeDirection.bottom => ResizeEdge.bottom,
      ResizeDirection.topLeft => ResizeEdge.topLeft,
      ResizeDirection.topRight => ResizeEdge.topRight,
      ResizeDirection.bottomLeft => ResizeEdge.bottomLeft,
      ResizeDirection.bottomRight => ResizeEdge.bottomRight,
    };
    return windowManager.startResizing(edge);
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> closeWindow() => windowManager.close();

  @override
  void onWindowClose() => _handler?.onCloseRequested();

  @override
  void onWindowFocus() => _handler?.onActiveChanged(true);

  @override
  void onWindowBlur() => _handler?.onActiveChanged(false);

  @override
  void onWindowResize() => _handler?.onResized();

  @override
  void onWindowMaximize() => _handler?.onMaximizedChanged(true);

  @override
  void onWindowUnmaximize() => _handler?.onMaximizedChanged(false);
}
