"""NotePad application object: window management and single-instance handling.

A second launch forwards its file arguments to the running instance over a
Unix domain socket, mirroring the old GApplication HANDLES_OPEN behavior.
The socket server uses the Python standard library (not QtNetwork) so it has
no native library dependencies beyond Qt Core/Widgets themselves.
"""

import os
import socket
import tempfile

from PySide6.QtCore import QSocketNotifier
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication

from window import NotepadWindow

APP_ID = "com.goshapps.Notepad"


def _server_socket_path():
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir()
    return os.path.join(runtime_dir, f"{APP_ID}.sock")


def _find_icon():
    candidates = [
        os.environ.get("NOTEPAD_ICON"),
        os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "data", "icons", "hicolor", "scalable", "apps",
            f"{APP_ID}.svg",
        ),
        os.path.join(
            "/usr/share/icons/hicolor/scalable/apps", f"{APP_ID}.svg"
        ),
        os.path.join(
            "/app/share/icons/hicolor/scalable/apps", f"{APP_ID}.svg"
        ),
    ]
    for candidate in candidates:
        if candidate and os.path.isfile(candidate):
            return QIcon(candidate)
    icon = QIcon.fromTheme(APP_ID)
    if not icon.isNull():
        return icon
    return QIcon()


class NotepadApplication(QApplication):
    """The main application singleton."""

    def __init__(self, argv=None, version="dev"):
        super().__init__(argv or [])
        self.version = version
        self.setApplicationName("NotePad")
        self.setApplicationVersion(version)
        self.setOrganizationName("goshapps")
        self.setDesktopFileName(APP_ID)
        self.setWindowIcon(_find_icon())
        self.window = None
        self._server = None

    # --------------------------------------------- single-instance wiring ----
    def forward_to_running_instance(self, files):
        """Send ``files`` to an already-running instance. Returns True if one
        was found and the payload was delivered."""
        path = _server_socket_path()
        if not os.path.exists(path):
            return False
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            try:
                client.settimeout(2.0)
                client.connect(path)
                client.sendall("\n".join(files).encode("utf-8"))
                client.shutdown(socket.SHUT_WR)
                # Wait for the ack so the server finishes reading before the
                # forwarding process exits.
                client.recv(1)
            finally:
                client.close()
            return True
        except OSError:
            return False

    def listen_for_instances(self):
        path = _server_socket_path()
        try:
            if os.path.exists(path):
                stale = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                try:
                    stale.settimeout(1.0)
                    stale.connect(path)
                except OSError:
                    os.unlink(path)
                else:
                    # Someone else already owns a live server socket.
                    return
                finally:
                    stale.close()
            self._server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self._server_socket.bind(path)
            self._server_socket.listen(4)
            self._server_socket.setblocking(False)
        except OSError:
            self._server_socket = None
            return
        self._socket_notifier = QSocketNotifier(
            self._server_socket.fileno(), QSocketNotifier.Type.Read, self
        )
        self._socket_notifier.activated.connect(self._on_new_connection)

    def _on_new_connection(self, *_args):
        try:
            connection, _addr = self._server_socket.accept()
        except OSError:
            return
        connection.setblocking(False)
        if not hasattr(self, "_connections"):
            self._connections = {}

        def _read(*_signal_args, connection=connection):
            try:
                data = connection.recv(4096)
            except BlockingIOError:
                return
            except OSError:
                data = b""
            if data:
                self._payloads[connection.fileno()].append(data)
                return
            # EOF: payload complete, acknowledge and act on it.
            notifier = self._connections.pop(connection.fileno(), None)
            if notifier is not None:
                notifier.setEnabled(False)
            chunks = self._payloads.pop(connection.fileno(), [])
            try:
                connection.sendall(b"\x00")
            except OSError:
                pass
            try:
                connection.close()
            except OSError:
                pass
            payload = b"".join(chunks).decode("utf-8", "replace")
            files = [path for path in payload.split("\n") if path]
            self.open_paths(files, present=True)

        notifier = QSocketNotifier(
            connection.fileno(), QSocketNotifier.Type.Read, self
        )
        self._connections[connection.fileno()] = notifier
        if not hasattr(self, "_payloads"):
            self._payloads = {}
        self._payloads[connection.fileno()] = []
        notifier.activated.connect(_read)

    # ------------------------------------------------------- window access ----
    def ensure_window(self):
        if self.window is None:
            self.window = NotepadWindow(version=self.version)
        return self.window

    def open_paths(self, files, present=False):
        window = self.ensure_window()
        if files:
            window.open_path(files[0])
        if present:
            window.show()
            window.raise_()
            window.activateWindow()
