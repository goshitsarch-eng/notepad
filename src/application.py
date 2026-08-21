from gi.repository import Adw, Gio, Gtk

from window import NotepadWindow

APP_ID = "com.goshapps.Notepad"


class NotepadApplication(Adw.Application):
    """The main application singleton."""

    def __init__(self, version="dev"):
        super().__init__(
            application_id=APP_ID,
            flags=Gio.ApplicationFlags.HANDLES_OPEN,
        )
        self.version = version
        self.create_action("quit", self.on_quit, ["<primary>q"])
        self.create_action("about", self.on_about)

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = NotepadWindow(application=self)
        win.present()

    def do_open(self, files, n_files, _hint):
        win = self.props.active_window
        if not win:
            win = NotepadWindow(application=self)
        if files:
            win.load_file(files[0])
        win.present()

    def on_quit(self, *_args):
        win = self.props.active_window
        if win:
            win.close()
        else:
            self.quit()

    def on_about(self, *_args):
        about = Adw.AboutWindow(
            transient_for=self.props.active_window,
            application_name="NotePad",
            application_icon=APP_ID,
            developer_name="Vaughan Jones",
            version=self.version,
            comments="A native GTK4 + Adwaita clone of Microsoft Notepad.",
            website="https://linear.app/vaughan-jones",
            license_type=Gtk.License.GPL_3_0,
            copyright="© 2026 Vaughan Jones",
        )
        about.present()

    def create_action(self, name, callback, shortcuts=None):
        action = Gio.SimpleAction.new(name, None)
        action.connect("activate", callback)
        self.add_action(action)
        if shortcuts:
            self.set_accels_for_action(f"app.{name}", shortcuts)
