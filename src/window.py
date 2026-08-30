"""NotePad main window: a classic Notepad menubar over a plain text editor."""

import datetime
import os

from PySide6.QtCore import QSize, Qt
from PySide6.QtGui import (
    QAction,
    QActionGroup,
    QFontDatabase,
    QIcon,
    QKeySequence,
    QShortcut,
)
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFontDialog,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QSizePolicy,
    QToolBar,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

import commands
import theme


def themed_icon(*names):
    """Return the first icon available from the icon theme."""
    fallback = QIcon()
    for name in names:
        icon = QIcon.fromTheme(name, fallback)
        if not icon.isNull():
            return icon
    return fallback


class FindBar(QWidget):
    """The inline find toolbar, shown by Edit -> Find (Ctrl+F)."""

    def __init__(self, window):
        super().__init__(window)
        self.window = window

        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 4, 8, 4)
        layout.setSpacing(6)

        self.entry = QLineEdit()
        self.entry.setPlaceholderText("Find")
        self.entry.setClearButtonEnabled(True)
        self.match_case_btn = QCheckBox("Match case")
        self.next_btn = QPushButton("Find Next")

        layout.addWidget(self.entry, 1)
        layout.addWidget(self.match_case_btn)
        layout.addWidget(self.next_btn)

        self.entry.returnPressed.connect(window.find_next)
        self.entry.textChanged.connect(window._on_search_text_changed)
        self.match_case_btn.toggled.connect(window._set_match_case)
        self.next_btn.clicked.connect(window.find_next)

        escape = QShortcut(QKeySequence(Qt.Key_Escape), self)
        escape.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
        escape.activated.connect(self.hide)

        self.hide()

    def focus_entry(self):
        self.entry.setFocus()
        self.entry.selectAll()


class ReplaceDialog(QDialog):
    """Modeless Replace dialog, mirroring classic Notepad."""

    def __init__(self, window):
        super().__init__(window)
        self.window = window
        self.setWindowTitle("Replace")
        self.setModal(False)

        outer = QVBoxLayout(self)

        form = QFormLayout()
        self.find_entry = QLineEdit()
        self.replace_entry = QLineEdit()
        form.addRow("Find what:", self.find_entry)
        form.addRow("Replace with:", self.replace_entry)
        outer.addLayout(form)

        self.match_case_btn = QCheckBox("Match case")
        self.match_case_btn.toggled.connect(window._set_match_case)
        outer.addWidget(self.match_case_btn)

        buttons = QHBoxLayout()
        buttons.setSpacing(6)
        self.find_next_btn = QPushButton("Find Next")
        self.replace_btn = QPushButton("Replace")
        self.replace_all_btn = QPushButton("Replace All")
        self.cancel_btn = QPushButton("Cancel")
        self.find_next_btn.setDefault(True)
        for button in (
            self.find_next_btn,
            self.replace_btn,
            self.replace_all_btn,
            self.cancel_btn,
        ):
            buttons.addWidget(button)
        outer.addLayout(buttons)

        self.find_entry.returnPressed.connect(self._on_find)
        self.replace_entry.returnPressed.connect(self._on_replace_one)
        self.find_next_btn.clicked.connect(self._on_find)
        self.replace_btn.clicked.connect(self._on_replace_one)
        self.replace_all_btn.clicked.connect(self._on_replace_all)
        self.cancel_btn.clicked.connect(self.close)

        self.resize(QSize(420, self.sizeHint().height()))

    def _sync_fields(self):
        self.window._search_text = self.find_entry.text()
        self.window._replace_text = self.replace_entry.text()
        bar_entry = self.window.find_bar.entry
        if bar_entry.text() != self.window._search_text:
            bar_entry.setText(self.window._search_text)

    def _on_find(self):
        self._sync_fields()
        self.window.find_next()

    def _on_replace_one(self):
        self._sync_fields()
        self.window.replace_one()

    def _on_replace_all(self):
        self._sync_fields()
        self.window.replace_every()

    def closeEvent(self, event):
        self.window._search_text = self.find_entry.text()
        self.window._replace_text = self.replace_entry.text()
        super().closeEvent(event)


class GoToDialog(QDialog):
    """Modal Go To Line dialog with Notepad-style validation."""

    def __init__(self, parent, current_line):
        super().__init__(parent)
        self.setWindowTitle("Go To Line")
        self.setModal(True)
        self.line = None

        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Line number:"))
        self.entry = QLineEdit(str(current_line))
        layout.addWidget(self.entry)

        buttons = QDialogButtonBox()
        go_btn = buttons.addButton("Go To", QDialogButtonBox.ButtonRole.AcceptRole)
        buttons.addButton("Cancel", QDialogButtonBox.ButtonRole.RejectRole)
        buttons.accepted.connect(self._validate_and_accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

        go_btn.setDefault(True)
        self.entry.returnPressed.connect(self._validate_and_accept)

    def _validate_and_accept(self):
        raw = self.entry.text().strip()
        try:
            self.line = int(raw)
        except ValueError:
            QMessageBox.warning(self, "NotePad", "Please enter a valid line number.")
            return
        self.accept()

    def showEvent(self, event):
        super().showEvent(event)
        self.entry.setFocus()
        self.entry.selectAll()


class NotepadWindow(QMainWindow):
    """The document window: a classic Notepad menubar over a plain text editor."""

    def __init__(self, version="dev"):
        super().__init__()
        self.version = version
        self.file_path = None
        self._search_text = ""
        self._replace_text = ""
        self._match_case = False
        self._replace_dialog = None
        self._font = QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont)

        self.resize(820, 600)

        self.edit = QPlainTextEdit()
        self.edit.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        self.edit.setFont(self._font)

        document = self.edit.document()
        document.setModified(False)
        document.modificationChanged.connect(lambda _changed: self._update_title())
        self.edit.cursorPositionChanged.connect(self._update_status)
        document.undoAvailable.connect(self._on_undo_available)
        document.redoAvailable.connect(self._on_redo_available)
        self.edit.selectionChanged.connect(self._update_selection_actions)

        self._build_actions()
        self._build_menus()
        self._build_find_bar()
        self._build_theme_toolbar()
        self._build_status_bar()

        self._update_title()
        self._update_status()

    # ---------------------------------------------------------------- UI ----
    def _build_actions(self):
        def action(text, slot=None, shortcut=None, checkable=False, checked=False):
            act = QAction(text, self)
            if shortcut is not None:
                act.setShortcut(shortcut)
            if checkable:
                act.setCheckable(True)
                act.setChecked(checked)
            if slot is not None:
                if checkable:
                    act.toggled.connect(slot)
                else:
                    act.triggered.connect(slot)
            return act

        self.new_action = action("&New", self.on_new, QKeySequence("Ctrl+N"))
        self.open_action = action("&Open…", self.on_open, QKeySequence("Ctrl+O"))
        self.save_action = action("&Save", self.on_save, QKeySequence("Ctrl+S"))
        self.save_as_action = action(
            "Save &As…", self.on_save_as, QKeySequence("Ctrl+Shift+S")
        )
        self.exit_action = action("E&xit", self.close, QKeySequence("Ctrl+Q"))

        self.undo_action = action("&Undo", self.edit.undo, QKeySequence("Ctrl+Z"))
        self.redo_action = action("&Redo", self.edit.redo, QKeySequence("Ctrl+Y"))
        self.cut_action = action("Cu&t", self.edit.cut, QKeySequence("Ctrl+X"))
        self.copy_action = action("&Copy", self.edit.copy, QKeySequence("Ctrl+C"))
        self.paste_action = action("&Paste", self.edit.paste, QKeySequence("Ctrl+V"))
        self.delete_action = action("&Delete", self.on_delete, QKeySequence(Qt.Key_Delete))
        self.find_action = action("&Find…", self.on_find, QKeySequence("Ctrl+F"))
        self.find_next_action = action("Find &Next", self.find_next, QKeySequence(Qt.Key_F3))
        self.replace_action = action("&Replace…", self.on_replace, QKeySequence("Ctrl+H"))
        self.goto_action = action("&Go To…", self.on_goto, QKeySequence("Ctrl+G"))
        self.select_all_action = action(
            "Select &All", self.edit.selectAll, QKeySequence("Ctrl+A")
        )
        self.datetime_action = action(
            "Time/&Date", self.on_insert_datetime, QKeySequence(Qt.Key_F5)
        )

        self.wrap_action = action(
            "&Word Wrap", self.on_toggle_wrap, checkable=True, checked=False
        )
        self.font_action = action("&Font…", self.on_font)

        self.status_bar_action = action(
            "&Status Bar", self.on_toggle_status_bar, checkable=True, checked=True
        )
        self.scheme_actions = {}
        group = QActionGroup(self)
        group.setExclusive(True)
        current = theme.load_scheme()
        for scheme, label in (
            (theme.ColorScheme.SYSTEM, "System"),
            (theme.ColorScheme.LIGHT, "Light"),
            (theme.ColorScheme.DARK, "Dark"),
        ):
            act = QAction(label, self)
            act.setCheckable(True)
            act.setChecked(scheme is current)
            act.triggered.connect(lambda _checked=False, s=scheme: self.on_scheme_changed(s))
            group.addAction(act)
            self.scheme_actions[scheme] = act

        self.about_action = action("&About NotePad", self.on_about)

        self.undo_action.setEnabled(self.edit.document().isUndoAvailable())
        self.redo_action.setEnabled(self.edit.document().isRedoAvailable())
        self._update_selection_actions()

    def _build_menus(self):
        menu_bar = self.menuBar()

        file_menu = menu_bar.addMenu("&File")
        file_menu.addAction(self.new_action)
        file_menu.addAction(self.open_action)
        file_menu.addAction(self.save_action)
        file_menu.addAction(self.save_as_action)
        file_menu.addAction(self.exit_action)

        edit_menu = menu_bar.addMenu("&Edit")
        edit_menu.addAction(self.undo_action)
        edit_menu.addAction(self.redo_action)
        edit_menu.addSeparator()
        edit_menu.addAction(self.cut_action)
        edit_menu.addAction(self.copy_action)
        edit_menu.addAction(self.paste_action)
        edit_menu.addAction(self.delete_action)
        edit_menu.addSeparator()
        edit_menu.addAction(self.find_action)
        edit_menu.addAction(self.find_next_action)
        edit_menu.addAction(self.replace_action)
        edit_menu.addAction(self.goto_action)
        edit_menu.addAction(self.select_all_action)
        edit_menu.addAction(self.datetime_action)

        format_menu = menu_bar.addMenu("F&ormat")
        format_menu.addAction(self.wrap_action)
        format_menu.addAction(self.font_action)

        view_menu = menu_bar.addMenu("&View")
        view_menu.addAction(self.status_bar_action)
        scheme_menu = view_menu.addMenu("&Color Scheme")
        for scheme in (
            theme.ColorScheme.SYSTEM,
            theme.ColorScheme.LIGHT,
            theme.ColorScheme.DARK,
        ):
            scheme_menu.addAction(self.scheme_actions[scheme])

        help_menu = menu_bar.addMenu("&Help")
        help_menu.addAction(self.about_action)

    def _build_find_bar(self):
        self.find_bar = FindBar(self)
        # Central column: the (hidden by default) find bar over the editor,
        # mirroring the GTK SearchBar placement.
        center = QWidget()
        layout = QVBoxLayout(center)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self.find_bar)
        layout.addWidget(self.edit, 1)
        self.setCentralWidget(center)

    def _build_theme_toolbar(self):
        bar = QToolBar(self)
        bar.setMovable(False)
        bar.setFloatable(False)
        bar.setIconSize(QSize(16, 16))
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        bar.addWidget(spacer)

        self.theme_button = QToolButton()
        self.theme_button.setAutoRaise(True)
        self.theme_button.setAccessibleName("Color scheme")
        self.theme_button.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.theme_button.clicked.connect(self.on_theme_button_clicked)
        bar.addWidget(self.theme_button)
        self.addToolBar(bar)
        self._update_scheme_ui()

    def _build_status_bar(self):
        self.wrap_label = QLabel("Word Wrap: Off")
        self.pos_label = QLabel("Ln 1, Col 1")
        self.statusBar().addWidget(self.wrap_label)
        self.statusBar().addPermanentWidget(self.pos_label)

    # ------------------------------------------------------ state syncing ----
    def _on_undo_available(self, available):
        self.undo_action.setEnabled(available)

    def _on_redo_available(self, available):
        self.redo_action.setEnabled(available)

    def _update_selection_actions(self):
        has_selection = self.edit.textCursor().hasSelection()
        self.cut_action.setEnabled(has_selection)
        self.copy_action.setEnabled(has_selection)
        self.delete_action.setEnabled(has_selection)

    def _update_title(self):
        name = os.path.basename(self.file_path) if self.file_path else "Untitled"
        marker = "•  " if self.edit.document().isModified() else ""
        self.setWindowTitle(f"{marker}{name} — NotePad")

    def _update_status(self):
        cursor = self.edit.textCursor()
        line = cursor.blockNumber() + 1
        col = cursor.columnNumber() + 1
        self.pos_label.setText(f"Ln {line}, Col {col}")

    # -------------------------------------------------------------- edit ----
    def on_delete(self):
        self.edit.textCursor().removeSelectedText()

    def on_insert_datetime(self):
        # WinXP Notepad F5 format, e.g. "3:04 PM 8/19/2026".
        now = datetime.datetime.now()
        stamp = now.strftime("%-I:%M %p %-m/%-d/%Y")
        self.edit.insertPlainText(stamp)

    def on_toggle_wrap(self, on):
        self.edit.setLineWrapMode(
            QPlainTextEdit.LineWrapMode.WidgetWidth
            if on
            else QPlainTextEdit.LineWrapMode.NoWrap
        )
        self.wrap_label.setText(f"Word Wrap: {'On' if on else 'Off'}")
        # Classic Notepad disables Go To while word wrap is on.
        self.goto_action.setEnabled(not on)

    def on_toggle_status_bar(self, visible):
        self.statusBar().setVisible(visible)

    def on_font(self):
        ok, font = QFontDialog.getFont(self._font, self, "Font")
        if ok:
            self._font = font
            self.edit.setFont(font)

    def on_about(self):
        QMessageBox.about(
            self,
            "About NotePad",
            "<h3>NotePad {}</h3>"
            "<p>A native Qt 6 clone of Microsoft Notepad.</p>"
            "<p>Light and dark theming follows the Kirigami color guidelines.</p>"
            "<p>Made by Gosh.</p>"
            "<p>© 2026 Gosh — GPL-3.0-or-later</p>".format(self.version),
        )

    # ------------------------------------------------------------ theming ----
    def on_scheme_changed(self, scheme):
        theme.apply(QApplication.instance(), scheme)
        theme.save_scheme(scheme)
        self._update_scheme_ui()

    def on_theme_button_clicked(self):
        current = theme.load_scheme()
        target = (
            theme.ColorScheme.LIGHT
            if theme.effective_is_dark(current)
            else theme.ColorScheme.DARK
        )
        self.scheme_actions[target].setChecked(True)
        self.on_scheme_changed(target)

    def _update_scheme_ui(self):
        current = theme.load_scheme()
        for scheme, act in self.scheme_actions.items():
            act.setChecked(scheme is current)
        dark = theme.effective_is_dark(current)
        if dark:
            self.theme_button.setText("Light")
            self.theme_button.setIcon(
                themed_icon(
                    "weather-clear-day-symbolic",
                    "weather-clear-day",
                    "daytime-sunrise-symbolic",
                )
            )
            self.theme_button.setToolTip("Switch to light mode")
        else:
            self.theme_button.setText("Dark")
            self.theme_button.setIcon(
                themed_icon(
                    "weather-clear-night-symbolic",
                    "weather-clear-night",
                    "nighttime-moon-symbolic",
                )
            )
            self.theme_button.setToolTip("Toggle dark mode")

    # -------------------------------------------------------------- search ----
    def on_find(self):
        self._prefill_search_from_selection()
        self.find_bar.show()
        self.find_bar.focus_entry()

    def _on_search_text_changed(self, text):
        self._search_text = text

    def _set_match_case(self, value):
        self._match_case = value
        if self.find_bar.match_case_btn.isChecked() != value:
            self.find_bar.match_case_btn.setChecked(value)
        if self._replace_dialog is not None and self._replace_dialog.isVisible():
            if self._replace_dialog.match_case_btn.isChecked() != value:
                self._replace_dialog.match_case_btn.setChecked(value)

    def _prefill_search_from_selection(self):
        selected = commands.selected_text(self.edit)
        if selected and "\n" not in selected:
            self._search_text = selected
            if self.find_bar.entry.text() != selected:
                self.find_bar.entry.setText(selected)
            if self._replace_dialog is not None:
                if self._replace_dialog.find_entry.text() != selected:
                    self._replace_dialog.find_entry.setText(selected)

    def _needle(self):
        return self.find_bar.entry.text() or self._search_text

    def find_next(self, show_not_found=True):
        text = self._needle()
        if not text:
            return False
        self._search_text = text
        if commands.find_next(self.edit, text, match_case=self._match_case):
            return True
        if show_not_found:
            self._error_dialog(f'Cannot find "{text}"')
        return False

    def on_replace(self):
        self._prefill_search_from_selection()
        if self._replace_dialog is None:
            self._replace_dialog = ReplaceDialog(self)
        self._replace_dialog.find_entry.setText(self._needle())
        self._replace_dialog.replace_entry.setText(self._replace_text)
        self._replace_dialog.match_case_btn.setChecked(self._match_case)
        self._replace_dialog.show()
        self._replace_dialog.raise_()
        self._replace_dialog.activateWindow()
        self._replace_dialog.find_entry.setFocus()
        self._replace_dialog.find_entry.selectAll()

    def replace_one(self):
        text = self._search_text
        if not text:
            return
        result = commands.replace_and_find_next(
            self.edit, text, self._replace_text, match_case=self._match_case
        )
        if result is None:
            self._error_dialog(f'Cannot find "{text}"')

    def replace_every(self):
        text = self._search_text
        if not text:
            return
        count = commands.replace_all(
            self.edit, text, self._replace_text, match_case=self._match_case
        )
        if count == 0:
            self._error_dialog(f'Cannot find "{text}"')

    def on_goto(self):
        if self.wrap_action.isChecked():
            return
        dialog = GoToDialog(self, self.edit.textCursor().blockNumber() + 1)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        if not commands.goto_line(self.edit, dialog.line):
            self._error_dialog("The line number is beyond the total number of lines.")
            return
        self.edit.setFocus()

    # ------------------------------------------------------------ file ops ----
    def on_new(self):
        self._guard_unsaved(self._reset_document)

    def _reset_document(self):
        self.edit.clear()
        self.edit.document().setModified(False)
        self.file_path = None
        self._update_title()

    def on_open(self):
        def do_open():
            start_dir = os.path.dirname(self.file_path) if self.file_path else ""
            path, _filter = QFileDialog.getOpenFileName(
                self,
                "Open",
                start_dir,
                "Text files (*.txt);;All files (*)",
            )
            if path:
                self.load_path(path)

        self._guard_unsaved(do_open)

    def load_path(self, path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                content = fh.read()
        except (OSError, UnicodeDecodeError) as err:
            self._error_dialog(f"Could not open file:\n{err}")
            return
        self.edit.setPlainText(content)
        self.edit.document().setModified(False)
        self.file_path = path
        self._update_title()

    def on_save(self):
        if self.file_path:
            self._write_to(self.file_path)
        else:
            self.on_save_as()

    def on_save_as(self):
        initial = (
            os.path.basename(self.file_path) if self.file_path else "Untitled.txt"
        )
        path, _filter = QFileDialog.getSaveFileName(
            self,
            "Save As",
            initial,
            "Text files (*.txt);;All files (*)",
        )
        if path:
            self._write_to(path)

    def _write_to(self, path):
        text = self.edit.toPlainText()
        try:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(text)
        except OSError as err:
            self._error_dialog(f"Could not save file:\n{err}")
            return
        self.file_path = path
        self.edit.document().setModified(False)
        self._update_title()

    # ----------------------------------------------------- unsaved changes ----
    def _guard_unsaved(self, proceed):
        if not self.edit.document().isModified():
            proceed()
            return
        box = QMessageBox(self)
        box.setWindowTitle("Save changes?")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("Save changes?")
        box.setInformativeText("Your changes will be lost if you don't save them.")
        save_btn = box.addButton("Save", QMessageBox.ButtonRole.AcceptRole)
        discard_btn = box.addButton("Discard", QMessageBox.ButtonRole.DestructiveRole)
        box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(save_btn)
        box.exec()
        clicked = box.clickedButton()
        if clicked is save_btn:
            self.on_save()
            if not self.edit.document().isModified():
                proceed()
        elif clicked is discard_btn:
            proceed()

    def _error_dialog(self, message):
        QMessageBox.warning(self, "Error", message)

    def closeEvent(self, event):
        if not self.edit.document().isModified():
            event.accept()
            return
        box = QMessageBox(self)
        box.setWindowTitle("Save changes?")
        box.setIcon(QMessageBox.Icon.Warning)
        box.setText("Save changes?")
        box.setInformativeText("Your changes will be lost if you don't save them.")
        save_btn = box.addButton("Save", QMessageBox.ButtonRole.AcceptRole)
        discard_btn = box.addButton("Discard", QMessageBox.ButtonRole.DestructiveRole)
        box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(save_btn)
        box.exec()
        clicked = box.clickedButton()
        if clicked is save_btn:
            self.on_save()
            if self.edit.document().isModified():
                event.ignore()
            else:
                event.accept()
        elif clicked is discard_btn:
            event.accept()
        else:
            event.ignore()
