import datetime
import os

from gi.repository import Adw, Gdk, Gio, GLib, Gtk, Pango

import commands


class NotepadWindow(Adw.ApplicationWindow):
    """The document window: a classic Notepad menubar over a plain text editor."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.set_default_size(820, 600)
        self.file = None
        self._search_text = ""
        self._replace_text = ""
        self._match_case = False
        self._replace_window = None
        self._font_desc = None
        self._font_chooser = None

        self.buffer = Gtk.TextBuffer()
        self.buffer.set_enable_undo(True)
        self.buffer.connect("notify::cursor-position", self._update_status)
        self.buffer.connect("changed", self._on_changed)
        self.buffer.connect("modified-changed", self._update_title)

        self.textview = Gtk.TextView(buffer=self.buffer)
        self.textview.add_css_class("notepad-text")
        self.textview.set_monospace(True)
        self.textview.set_wrap_mode(Gtk.WrapMode.NONE)
        self.textview.set_left_margin(6)
        self.textview.set_top_margin(6)

        self._font_css = Gtk.CssProvider()
        display = self.get_display() or Gdk.Display.get_default()
        if display is not None:
            Gtk.StyleContext.add_provider_for_display(
                display,
                self._font_css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
            )

        self._build_actions()
        self._build_ui()
        self._update_title()
        self._update_status()

    # ---------------------------------------------------------------- UI ----
    def _build_ui(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        header = Adw.HeaderBar()
        self.window_title = Adw.WindowTitle(title="Untitled", subtitle="NotePad")
        header.set_title_widget(self.window_title)

        self.theme_button = Gtk.ToggleButton(icon_name="weather-clear-night-symbolic")
        self.theme_button.set_tooltip_text("Toggle dark mode")
        self.theme_button.connect("toggled", self._on_theme_toggled)
        header.pack_end(self.theme_button)
        root.append(header)

        menubar = Gtk.PopoverMenuBar.new_from_model(self._build_menu_model())
        root.append(menubar)

        self.search_bar = self._build_search_bar()
        root.append(self.search_bar)

        scrolled = Gtk.ScrolledWindow(vexpand=True, hexpand=True)
        scrolled.set_child(self.textview)
        root.append(scrolled)

        self.status_bar = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL, spacing=16
        )
        self.status_bar.add_css_class("toolbar")
        self.status_bar.set_margin_start(8)
        self.status_bar.set_margin_end(8)
        self.status_bar.set_margin_top(2)
        self.status_bar.set_margin_bottom(2)
        self.pos_label = Gtk.Label(label="Ln 1, Col 1", xalign=1.0, hexpand=True)
        self.wrap_label = Gtk.Label(label="Word Wrap: Off")
        self.status_bar.append(self.wrap_label)
        self.status_bar.append(self.pos_label)
        root.append(self.status_bar)

        self.set_content(root)

    def _build_search_bar(self):
        search_bar = Gtk.SearchBar()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.search_entry = Gtk.SearchEntry(placeholder_text="Find")
        self.search_entry.set_hexpand(True)
        self.search_entry.connect("activate", lambda *_: self.find_next())
        self.search_entry.connect("search-changed", self._on_search_changed)
        next_btn = Gtk.Button(label="Find Next")
        next_btn.connect("clicked", lambda *_: self.find_next())
        self.match_case_btn = Gtk.CheckButton(label="Match case")
        self.match_case_btn.connect("toggled", self._on_match_case_toggled)
        box.append(self.search_entry)
        box.append(self.match_case_btn)
        box.append(next_btn)
        search_bar.set_child(box)
        search_bar.connect_entry(self.search_entry)
        return search_bar

    def _build_menu_model(self):
        menu = Gio.Menu()

        file_menu = Gio.Menu()
        file_menu.append("New", "win.new")
        file_menu.append("Open…", "win.open")
        file_menu.append("Save", "win.save")
        file_menu.append("Save As…", "win.save-as")
        file_menu.append("Exit", "win.close-window")
        menu.append_submenu("File", file_menu)

        edit_menu = Gio.Menu()
        section1 = Gio.Menu()
        section1.append("Undo", "win.undo")
        section1.append("Redo", "win.redo")
        edit_menu.append_section(None, section1)
        section2 = Gio.Menu()
        section2.append("Cut", "win.cut")
        section2.append("Copy", "win.copy")
        section2.append("Paste", "win.paste")
        section2.append("Delete", "win.delete")
        edit_menu.append_section(None, section2)
        section3 = Gio.Menu()
        section3.append("Find…", "win.find")
        section3.append("Find Next", "win.find-next")
        section3.append("Replace…", "win.replace")
        section3.append("Go To…", "win.go-to")
        section3.append("Select All", "win.select-all")
        section3.append("Time/Date", "win.insert-datetime")
        edit_menu.append_section(None, section3)
        menu.append_submenu("Edit", edit_menu)

        format_menu = Gio.Menu()
        format_menu.append("Word Wrap", "win.word-wrap")
        format_menu.append("Font…", "win.font")
        menu.append_submenu("Format", format_menu)

        view_menu = Gio.Menu()
        view_menu.append("Status Bar", "win.status-bar")
        view_menu.append("Dark Mode", "win.dark-mode")
        menu.append_submenu("View", view_menu)

        help_menu = Gio.Menu()
        help_menu.append("About NotePad", "app.about")
        menu.append_submenu("Help", help_menu)

        return menu

    def _build_actions(self):
        simple = {
            "new": self.on_new,
            "open": self.on_open,
            "save": self.on_save,
            "save-as": self.on_save_as,
            "close-window": lambda *_: self.close(),
            "undo": lambda *_: self.buffer.undo(),
            "redo": lambda *_: self.buffer.redo(),
            "cut": self.on_cut,
            "copy": self.on_copy,
            "paste": self.on_paste,
            "delete": self.on_delete,
            "select-all": self.on_select_all,
            "find": self.on_find,
            "find-next": lambda *_: self.find_next(),
            "replace": self.on_replace,
            "go-to": self.on_go_to,
            "font": self.on_font,
            "insert-datetime": self.on_insert_datetime,
        }
        for name, cb in simple.items():
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", cb)
            self.add_action(action)

        self.goto_action = self.lookup_action("go-to")

        self.wrap_action = Gio.SimpleAction.new_stateful(
            "word-wrap", None, GLib.Variant.new_boolean(False)
        )
        self.wrap_action.connect("change-state", self.on_toggle_wrap)
        self.add_action(self.wrap_action)

        self.status_action = Gio.SimpleAction.new_stateful(
            "status-bar", None, GLib.Variant.new_boolean(True)
        )
        self.status_action.connect("change-state", self.on_toggle_status_bar)
        self.add_action(self.status_action)

        self.dark_action = Gio.SimpleAction.new_stateful(
            "dark-mode", None, GLib.Variant.new_boolean(False)
        )
        self.dark_action.connect("change-state", self.on_toggle_dark)
        self.add_action(self.dark_action)

        app = self.get_application()
        if app:
            accels = {
                "win.new": ["<primary>n"],
                "win.open": ["<primary>o"],
                "win.save": ["<primary>s"],
                "win.save-as": ["<primary><shift>s"],
                "win.undo": ["<primary>z"],
                "win.redo": ["<primary>y"],
                "win.cut": ["<primary>x"],
                "win.copy": ["<primary>c"],
                "win.paste": ["<primary>v"],
                "win.select-all": ["<primary>a"],
                "win.find": ["<primary>f"],
                "win.find-next": ["F3"],
                "win.replace": ["<primary>h"],
                "win.go-to": ["<primary>g"],
                "win.insert-datetime": ["F5"],
            }
            for name, keys in accels.items():
                app.set_accels_for_action(name, keys)

    # ------------------------------------------------------------ actions ----
    def on_cut(self, *_):
        self.buffer.cut_clipboard(self.get_clipboard(), True)

    def on_copy(self, *_):
        self.buffer.copy_clipboard(self.get_clipboard())

    def on_paste(self, *_):
        self.buffer.paste_clipboard(self.get_clipboard(), None, True)

    def on_delete(self, *_):
        self.buffer.delete_selection(True, True)

    def on_select_all(self, *_):
        self.buffer.select_range(
            self.buffer.get_start_iter(), self.buffer.get_end_iter()
        )

    def on_insert_datetime(self, *_):
        # WinXP Notepad F5 format, e.g. "3:04 PM 8/19/2026".
        now = datetime.datetime.now()
        stamp = now.strftime("%-I:%M %p %-m/%-d/%Y")
        self.buffer.insert_at_cursor(stamp)

    def on_toggle_wrap(self, action, value):
        action.set_state(value)
        on = value.get_boolean()
        self.textview.set_wrap_mode(
            Gtk.WrapMode.WORD_CHAR if on else Gtk.WrapMode.NONE
        )
        self.wrap_label.set_label(f"Word Wrap: {'On' if on else 'Off'}")
        # Classic Notepad disables Go To while word wrap is on.
        if self.goto_action:
            self.goto_action.set_enabled(not on)

    def on_toggle_status_bar(self, action, value):
        action.set_state(value)
        self.status_bar.set_visible(value.get_boolean())

    def on_toggle_dark(self, action, value):
        action.set_state(value)
        self._apply_theme(value.get_boolean())

    def _on_theme_toggled(self, button):
        self.dark_action.change_state(GLib.Variant.new_boolean(button.get_active()))

    def _apply_theme(self, dark):
        mgr = Adw.StyleManager.get_default()
        mgr.set_color_scheme(
            Adw.ColorScheme.FORCE_DARK if dark else Adw.ColorScheme.FORCE_LIGHT
        )
        if self.theme_button.get_active() != dark:
            self.theme_button.set_active(dark)

    # -------------------------------------------------------------- search ----
    def on_find(self, *_):
        self._prefill_search_from_selection()
        self.search_bar.set_search_mode(True)
        self.search_entry.grab_focus()

    def _on_search_changed(self, entry):
        self._search_text = entry.get_text()

    def _on_match_case_toggled(self, button):
        self._set_match_case(button.get_active())

    def _set_match_case(self, value):
        self._match_case = value
        if self.match_case_btn.get_active() != value:
            self.match_case_btn.set_active(value)
        if self._replace_window is not None:
            btn = getattr(self._replace_window, "match_case_btn", None)
            if btn is not None and btn.get_active() != value:
                btn.set_active(value)

    def _prefill_search_from_selection(self):
        selected = commands.selected_text(self.buffer)
        if selected and "\n" not in selected:
            self._search_text = selected
            if self.search_entry.get_text() != selected:
                self.search_entry.set_text(selected)
            if self._replace_window is not None:
                find_entry = getattr(self._replace_window, "find_entry", None)
                if find_entry is not None and find_entry.get_text() != selected:
                    find_entry.set_text(selected)

    def _needle(self):
        return self.search_entry.get_text() or self._search_text

    def find_next(self, show_not_found=True):
        text = self._needle()
        if not text:
            return False
        self._search_text = text
        if commands.find_next(self.buffer, text, match_case=self._match_case):
            self.textview.scroll_to_mark(self.buffer.get_insert(), 0.1, False, 0, 0)
            return True
        if show_not_found:
            self._error_dialog(f'Cannot find "{text}"')
        return False

    def on_replace(self, *_):
        self._prefill_search_from_selection()
        if self._replace_window is not None:
            self._replace_window.present()
            self._replace_window.find_entry.grab_focus()
            return
        self._replace_window = self._build_replace_window()
        self._replace_window.present()
        self._replace_window.find_entry.grab_focus()

    def _build_replace_window(self):
        win = Gtk.Window(
            title="Replace",
            transient_for=self,
            modal=False,
            resizable=False,
        )
        win.set_default_size(420, -1)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(12)
        box.set_margin_bottom(12)
        box.set_margin_start(12)
        box.set_margin_end(12)

        grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        find_label = Gtk.Label(label="Find what:", xalign=0)
        find_entry = Gtk.Entry()
        find_entry.set_hexpand(True)
        find_entry.set_text(self._needle())
        replace_label = Gtk.Label(label="Replace with:", xalign=0)
        replace_entry = Gtk.Entry()
        replace_entry.set_hexpand(True)
        replace_entry.set_text(self._replace_text)
        grid.attach(find_label, 0, 0, 1, 1)
        grid.attach(find_entry, 1, 0, 1, 1)
        grid.attach(replace_label, 0, 1, 1, 1)
        grid.attach(replace_entry, 1, 1, 1, 1)
        box.append(grid)

        match_case_btn = Gtk.CheckButton(label="Match case")
        match_case_btn.set_active(self._match_case)
        match_case_btn.connect(
            "toggled", lambda btn: self._set_match_case(btn.get_active())
        )
        box.append(match_case_btn)

        buttons = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        buttons.set_halign(Gtk.Align.END)
        find_next_btn = Gtk.Button(label="Find Next")
        find_next_btn.add_css_class("suggested-action")
        replace_btn = Gtk.Button(label="Replace")
        replace_all_btn = Gtk.Button(label="Replace All")
        cancel_btn = Gtk.Button(label="Cancel")
        buttons.append(find_next_btn)
        buttons.append(replace_btn)
        buttons.append(replace_all_btn)
        buttons.append(cancel_btn)
        box.append(buttons)

        win.set_child(box)
        win.set_default_widget(find_next_btn)

        def sync_fields():
            self._search_text = find_entry.get_text()
            self._replace_text = replace_entry.get_text()
            if self.search_entry.get_text() != self._search_text:
                self.search_entry.set_text(self._search_text)

        def on_find(*_):
            sync_fields()
            self.find_next()

        def on_replace_one(*_):
            sync_fields()
            text = self._search_text
            if not text:
                return
            result = commands.replace_and_find_next(
                self.buffer,
                text,
                self._replace_text,
                match_case=self._match_case,
            )
            if result is None:
                self._error_dialog(f'Cannot find "{text}"')
                return
            self.textview.scroll_to_mark(self.buffer.get_insert(), 0.1, False, 0, 0)

        def on_replace_all(*_):
            sync_fields()
            text = self._search_text
            if not text:
                return
            count = commands.replace_all(
                self.buffer, text, self._replace_text, match_case=self._match_case
            )
            if count == 0:
                self._error_dialog(f'Cannot find "{text}"')

        def on_cancel(*_):
            win.close()

        find_entry.connect("activate", on_find)
        replace_entry.connect("activate", on_replace_one)
        find_next_btn.connect("clicked", on_find)
        replace_btn.connect("clicked", on_replace_one)
        replace_all_btn.connect("clicked", on_replace_all)
        cancel_btn.connect("clicked", on_cancel)
        win.connect("close-request", self._on_replace_closed)

        win.find_entry = find_entry
        win.replace_entry = replace_entry
        win.match_case_btn = match_case_btn
        return win

    def _on_replace_closed(self, _window):
        if self._replace_window is not None:
            self._search_text = self._replace_window.find_entry.get_text()
            self._replace_text = self._replace_window.replace_entry.get_text()
        self._replace_window = None
        return False

    def on_go_to(self, *_):
        if self.wrap_action.get_state().get_boolean():
            return

        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Go To Line",
            body="Line number:",
        )
        entry = Gtk.Entry()
        entry.set_input_purpose(Gtk.InputPurpose.NUMBER)
        insert = self.buffer.get_iter_at_mark(self.buffer.get_insert())
        entry.set_text(str(insert.get_line() + 1))
        entry.set_activates_default(True)
        dialog.set_extra_child(entry)
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("go", "Go To")
        dialog.set_response_appearance("go", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("go")

        def on_response(_dlg, response):
            if response != "go":
                return
            raw = entry.get_text().strip()
            try:
                line = int(raw)
            except ValueError:
                self._error_dialog("Please enter a valid line number.")
                return
            if not commands.goto_line(self.buffer, line):
                self._error_dialog(
                    "The line number is beyond the total number of lines."
                )
                return
            self.textview.scroll_to_mark(
                self.buffer.get_insert(), 0.25, True, 0.0, 0.5
            )
            self.textview.grab_focus()

        entry.connect("activate", lambda *_: dialog.response("go"))
        dialog.connect("response", on_response)
        dialog.present()
        entry.select_region(0, -1)
        entry.grab_focus()

    def on_font(self, *_):
        if self._font_chooser is None:
            self._font_chooser = Gtk.FontDialog(title="Font", modal=True)
        self._font_chooser.choose_font(
            self, self._current_font(), None, self._on_font_chosen
        )

    def _current_font(self):
        if self._font_desc is not None:
            return self._font_desc
        ctx = self.textview.get_pango_context()
        return ctx.get_font_description()

    def _on_font_chosen(self, dialog, result):
        try:
            font_desc = dialog.choose_font_finish(result)
        except GLib.Error:
            return
        if font_desc is None:
            return
        self._apply_font(font_desc)

    def _apply_font(self, font_desc: Pango.FontDescription):
        self._font_desc = font_desc
        self.textview.set_monospace(False)
        self._font_css.load_from_string(commands.font_css(font_desc))

    # ------------------------------------------------------------ file ops ----
    def on_new(self, *_):
        self._guard_unsaved(self._reset_document)

    def _reset_document(self):
        self.buffer.set_text("")
        self.buffer.set_modified(False)
        self.file = None
        self._update_title()

    def on_open(self, *_):
        def do_open():
            dialog = Gtk.FileDialog(title="Open")
            dialog.open(self, None, self._open_finish)

        self._guard_unsaved(do_open)

    def _open_finish(self, dialog, result):
        try:
            gfile = dialog.open_finish(result)
        except GLib.Error:
            return
        if gfile:
            self.load_file(gfile)

    def load_file(self, gfile):
        path = gfile.get_path()
        try:
            with open(path, "r", encoding="utf-8") as fh:
                content = fh.read()
        except (OSError, UnicodeDecodeError) as err:
            self._error_dialog(f"Could not open file:\n{err}")
            return
        self.buffer.set_text(content)
        self.buffer.set_modified(False)
        self.file = gfile
        self._update_title()

    def on_save(self, *_):
        if self.file:
            self._write_to(self.file)
        else:
            self.on_save_as()

    def on_save_as(self, *_):
        dialog = Gtk.FileDialog(title="Save As")
        if self.file:
            dialog.set_initial_name(self.file.get_basename())
        else:
            dialog.set_initial_name("Untitled.txt")
        dialog.save(self, None, self._save_finish)

    def _save_finish(self, dialog, result):
        try:
            gfile = dialog.save_finish(result)
        except GLib.Error:
            return
        if gfile:
            self._write_to(gfile)

    def _write_to(self, gfile):
        start, end = self.buffer.get_bounds()
        text = self.buffer.get_text(start, end, True)
        try:
            with open(gfile.get_path(), "w", encoding="utf-8") as fh:
                fh.write(text)
        except OSError as err:
            self._error_dialog(f"Could not save file:\n{err}")
            return
        self.file = gfile
        self.buffer.set_modified(False)
        self._update_title()

    # ----------------------------------------------------- unsaved changes ----
    def _guard_unsaved(self, proceed):
        if not self.buffer.get_modified():
            proceed()
            return
        dialog = Adw.MessageDialog(
            transient_for=self,
            heading="Save changes?",
            body="Your changes will be lost if you don't save them.",
        )
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("discard", "Discard")
        dialog.add_response("save", "Save")
        dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("save")

        def on_response(dlg, response):
            if response == "discard":
                proceed()
            elif response == "save":
                self.on_save()
                if not self.buffer.get_modified():
                    proceed()

        dialog.connect("response", on_response)
        dialog.present()

    def _error_dialog(self, message):
        dialog = Adw.MessageDialog(
            transient_for=self, heading="Error", body=message
        )
        dialog.add_response("ok", "OK")
        dialog.present()

    # ------------------------------------------------------------- display ----
    def _on_changed(self, *_):
        self._update_status()

    def _update_title(self, *_):
        name = self.file.get_basename() if self.file else "Untitled"
        modified = "•  " if self.buffer.get_modified() else ""
        self.window_title.set_title(f"{modified}{name}")
        subtitle = os.path.dirname(self.file.get_path()) if self.file else "NotePad"
        self.window_title.set_subtitle(subtitle)

    def _update_status(self, *_):
        insert = self.buffer.get_iter_at_mark(self.buffer.get_insert())
        line = insert.get_line() + 1
        col = insert.get_line_offset() + 1
        self.pos_label.set_label(f"Ln {line}, Col {col}")
