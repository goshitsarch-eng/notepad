// SPDX-License-Identifier: GPL-3.0-or-later

use crate::commands::{self, ReplaceResult};
use crate::config::{ColorScheme, Config, theme_for};
use crate::fl;
use crate::key_bind;
use crate::single_instance;
use chrono::Datelike;
use cosmic::app::Task;
use cosmic::app::context_drawer::{self, ContextDrawer};
use cosmic::cosmic_config::{self, CosmicConfigEntry};
use cosmic::dialog::file_chooser::{self, FileFilter};
use cosmic::iced::clipboard;
use cosmic::iced::core::text::Wrapping;
use cosmic::iced::font::{Family, Stretch, Style as FontStyle, Weight};
use cosmic::iced::keyboard::{Key, key::Named};
use cosmic::iced::window;
use cosmic::iced::{Alignment, Font, Length, Subscription};
use cosmic::prelude::*;
use cosmic::widget::about::About;
use cosmic::widget::menu::{self, ItemHeight, ItemWidth};
use cosmic::widget::text_editor::{self, Action, Binding, Content, Edit, KeyPress};
use cosmic::widget::{self, icon};
use cosmic::{command, iced};
use std::borrow::Cow;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use url::Url;

const REPOSITORY: &str = env!("CARGO_PKG_REPOSITORY");
const APP_ICON: &[u8] =
    include_bytes!("../data/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg");

const FONT_FAMILIES: &[&str] = &[
    "monospace",
    "sans-serif",
    "serif",
    "Noto Sans Mono",
    "Open Sans",
    "DejaVu Sans Mono",
    "Liberation Mono",
    "FreeMono",
    "Ubuntu Mono",
    "Source Code Pro",
    "Fira Code",
    "JetBrains Mono",
    "Noto Sans",
    "Noto Serif",
];

const FONT_SIZES: &[u16] = &[8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36];

/// Data passed into [`App::init`].
#[derive(Clone, Debug, Default)]
pub struct Flags {
    pub files: Vec<PathBuf>,
}

/// What to do after the unsaved-changes dialog is resolved.
#[derive(Clone, Debug)]
pub enum AfterSave {
    New,
    Open,
    OpenPath(PathBuf),
    Close,
}

/// Modal dialog currently shown in the window.
#[derive(Clone, Debug)]
pub enum PendingDialog {
    SaveChanges {
        after: AfterSave,
    },
    GoTo {
        input: String,
        error: Option<String>,
    },
    Font,
    Error {
        message: String,
    },
}

/// The application model.
pub struct App {
    core: cosmic::Core,
    about: About,
    context_page: ContextPage,
    key_binds: HashMap<menu::KeyBind, MenuAction>,
    config: Config,
    config_handler: Option<cosmic_config::Config>,
    content: Content,
    file_path: Option<PathBuf>,
    saved_text: String,
    editor_font: Font,
    find_visible: bool,
    replace_visible: bool,
    find_text: String,
    replace_text: String,
    match_case: bool,
    goto_input: String,
    font_family_input: String,
    font_size_index: usize,
    pending: Option<PendingDialog>,
    pending_after: Option<AfterSave>,
    undo_stack: Vec<(String, text_editor::Cursor)>,
    redo_stack: Vec<(String, text_editor::Cursor)>,
    font_family_labels: Vec<String>,
    font_size_labels: Vec<String>,
}

/// Messages emitted by the application and its widgets.
#[derive(Clone, Debug)]
pub enum Message {
    Editor(Action),
    New,
    Open,
    OpenSelected(Url),
    OpenExternal(Vec<PathBuf>),
    Save,
    SaveAs,
    SaveSelected(Url),
    Exit,
    Undo,
    Redo,
    Cut,
    Copy,
    Paste,
    ClipboardPaste(Option<String>),
    Delete,
    Find,
    FindNext,
    Replace,
    ReplaceOne,
    ReplaceAll,
    CloseFind,
    FindText(String),
    ReplaceText(String),
    MatchCase(bool),
    GoTo,
    GoToInput(String),
    GoToConfirm,
    SelectAll,
    InsertDateTime,
    ToggleWrap,
    ToggleStatusBar,
    Font,
    FontFamily(usize),
    FontSize(usize),
    FontFamilyInput(String),
    ApplyFont,
    Scheme(ColorScheme),
    ToggleScheme,
    LaunchUrl(String),
    ToggleContextPage(ContextPage),
    DialogCancel,
    DialogSave,
    DialogDiscard,
    CloseError,
    UpdateConfig(Config),
    Error(String),
    Cancelled,
}

#[derive(Copy, Clone, Debug, Default, Eq, PartialEq)]
pub enum ContextPage {
    #[default]
    About,
}

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum MenuAction {
    New,
    Open,
    Save,
    SaveAs,
    Exit,
    Undo,
    Redo,
    Cut,
    Copy,
    Paste,
    Delete,
    Find,
    FindNext,
    Replace,
    GoTo,
    SelectAll,
    InsertDateTime,
    ToggleWrap,
    Font,
    ToggleStatusBar,
    Scheme(ColorScheme),
    About,
}

impl menu::action::MenuAction for MenuAction {
    type Message = Message;

    fn message(&self) -> Self::Message {
        match self {
            MenuAction::New => Message::New,
            MenuAction::Open => Message::Open,
            MenuAction::Save => Message::Save,
            MenuAction::SaveAs => Message::SaveAs,
            MenuAction::Exit => Message::Exit,
            MenuAction::Undo => Message::Undo,
            MenuAction::Redo => Message::Redo,
            MenuAction::Cut => Message::Cut,
            MenuAction::Copy => Message::Copy,
            MenuAction::Paste => Message::Paste,
            MenuAction::Delete => Message::Delete,
            MenuAction::Find => Message::Find,
            MenuAction::FindNext => Message::FindNext,
            MenuAction::Replace => Message::Replace,
            MenuAction::GoTo => Message::GoTo,
            MenuAction::SelectAll => Message::SelectAll,
            MenuAction::InsertDateTime => Message::InsertDateTime,
            MenuAction::ToggleWrap => Message::ToggleWrap,
            MenuAction::Font => Message::Font,
            MenuAction::ToggleStatusBar => Message::ToggleStatusBar,
            MenuAction::Scheme(scheme) => Message::Scheme(*scheme),
            MenuAction::About => Message::ToggleContextPage(ContextPage::About),
        }
    }
}

/// Leading check column matching `Item::CheckBox`, which renders a
/// `Fixed(16.0)` spacer plus a `space_xxs` gap and no icon when none is given.
/// Command and folder rows replicate that gutter so labels line up across menus.
const MENU_CHECK_COL: f32 = 16.0;

fn menu_shortcut(action: MenuAction, key_binds: &HashMap<menu::KeyBind, MenuAction>) -> String {
    key_binds
        .iter()
        .find_map(|(bind, bound)| (*bound == action).then(|| bind.to_string()))
        .unwrap_or_default()
}

fn menu_check_gutter() -> [Element<'static, Message>; 2] {
    let spacing = cosmic::theme::spacing();
    [
        widget::space::horizontal()
            .width(Length::Fixed(MENU_CHECK_COL))
            .into(),
        widget::space::horizontal().width(spacing.space_xxs).into(),
    ]
}

fn aligned_disabled_item(
    label: impl Into<Cow<'static, str>>,
    shortcut: impl Into<Cow<'static, str>>,
) -> menu::Tree<Message> {
    let [gutter, gap] = menu_check_gutter();
    menu::Tree::from(Element::from(menu::menu_button(vec![
        gutter,
        gap,
        widget::text(label.into()).into(),
        widget::space::horizontal().into(),
        widget::text(shortcut.into()).into(),
    ])))
}

fn aligned_folder(
    label: impl Into<Cow<'static, str>>,
    children: Vec<menu::Tree<Message>>,
) -> menu::Tree<Message> {
    let [gutter, gap] = menu_check_gutter();
    menu::Tree::with_children(
        menu::menu_button(vec![
            gutter,
            gap,
            widget::text(label.into()).align_x(Alignment::Start).into(),
            widget::space::horizontal().into(),
            widget::icon::from_name("pan-end-symbolic")
                .size(16)
                .icon()
                .into(),
        ])
        .class(cosmic::theme::Button::MenuFolder)
        .apply(Element::from),
        children,
    )
}

impl cosmic::Application for App {
    type Executor = cosmic::executor::Default;
    type Flags = Flags;
    type Message = Message;
    const APP_ID: &'static str = "com.goshapps.Notepad";

    fn core(&self) -> &cosmic::Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut cosmic::Core {
        &mut self.core
    }

    fn init(core: cosmic::Core, flags: Self::Flags) -> (Self, Task<Self::Message>) {
        let (config_handler, config) =
            match cosmic_config::Config::new(Self::APP_ID, Config::VERSION) {
                Ok(handler) => {
                    let config = Config::get_entry(&handler).unwrap_or_else(|(_, config)| config);
                    (Some(handler), config)
                }
                Err(_) => (None, Config::default()),
            };

        Self::with_config(core, flags, config, config_handler)
    }

    fn header_start(&self) -> Vec<Element<'_, Self::Message>> {
        let wrap = self.config.word_wrap;

        // CheckBox(false) keeps the leading check column on command rows so
        // labels line up with Word Wrap / Status Bar / color-scheme checks.
        let menu_bar = menu::bar(vec![
            menu::Tree::with_children(
                menu::root(fl!("file")).apply(Element::from),
                menu::items(
                    &self.key_binds,
                    vec![
                        menu::Item::CheckBox(fl!("new"), None, false, MenuAction::New),
                        menu::Item::CheckBox(fl!("open"), None, false, MenuAction::Open),
                        menu::Item::CheckBox(fl!("save"), None, false, MenuAction::Save),
                        menu::Item::CheckBox(fl!("save-as"), None, false, MenuAction::SaveAs),
                        menu::Item::CheckBox(fl!("exit"), None, false, MenuAction::Exit),
                    ],
                ),
            ),
            menu::Tree::with_children(
                menu::root(fl!("edit")).apply(Element::from),
                self.edit_menu_items(),
            ),
            menu::Tree::with_children(
                menu::root(fl!("format")).apply(Element::from),
                menu::items(
                    &self.key_binds,
                    vec![
                        menu::Item::CheckBox(fl!("word-wrap"), None, wrap, MenuAction::ToggleWrap),
                        menu::Item::CheckBox(fl!("font"), None, false, MenuAction::Font),
                    ],
                ),
            ),
            menu::Tree::with_children(
                menu::root(fl!("view")).apply(Element::from),
                self.view_menu_items(),
            ),
            menu::Tree::with_children(
                menu::root(fl!("help")).apply(Element::from),
                menu::items(
                    &self.key_binds,
                    vec![menu::Item::CheckBox(
                        fl!("about"),
                        None,
                        false,
                        MenuAction::About,
                    )],
                ),
            ),
        ])
        .item_height(ItemHeight::Dynamic(40))
        .item_width(ItemWidth::Uniform(280))
        .spacing(4.0);

        vec![menu_bar.into()]
    }

    fn header_end(&self) -> Vec<Element<'_, Self::Message>> {
        let dark = self.effective_is_dark();
        let (label, icon_name, tooltip) = if dark {
            (
                fl!("light"),
                "weather-clear-day-symbolic",
                fl!("switch-to-light"),
            )
        } else {
            (
                fl!("dark"),
                "weather-clear-night-symbolic",
                fl!("toggle-dark"),
            )
        };

        vec![
            widget::button::standard(label)
                .leading_icon(icon::from_name(icon_name))
                .on_press(Message::ToggleScheme)
                .tooltip(tooltip)
                .into(),
        ]
    }

    fn context_drawer(&self) -> Option<ContextDrawer<'_, Self::Message>> {
        if !self.core.window.show_context {
            return None;
        }

        Some(match self.context_page {
            ContextPage::About => context_drawer::about(
                &self.about,
                |url: &str| Message::LaunchUrl(url.to_string()),
                Message::ToggleContextPage(ContextPage::About),
            ),
        })
    }

    fn dialog(&self) -> Option<Element<'_, Self::Message>> {
        match &self.pending {
            None => None,
            Some(PendingDialog::SaveChanges { .. }) => Some(
                widget::dialog()
                    .title(fl!("save-changes"))
                    .body(fl!("save-changes-body"))
                    .primary_action(
                        widget::button::suggested(fl!("save")).on_press(Message::DialogSave),
                    )
                    .secondary_action(
                        widget::button::standard(fl!("cancel")).on_press(Message::DialogCancel),
                    )
                    .tertiary_action(
                        widget::button::destructive(fl!("discard"))
                            .on_press(Message::DialogDiscard),
                    )
                    .into(),
            ),
            Some(PendingDialog::GoTo { input, error }) => {
                let mut dialog = widget::dialog()
                    .title(fl!("go-to-line"))
                    .control(
                        widget::column::with_capacity(2)
                            .spacing(8)
                            .push(widget::text::body(fl!("line-number")))
                            .push(
                                widget::text_input("", input)
                                    .on_input(Message::GoToInput)
                                    .on_submit(|_| Message::GoToConfirm),
                            ),
                    )
                    .primary_action(
                        widget::button::suggested(fl!("go-to-button"))
                            .on_press(Message::GoToConfirm),
                    )
                    .secondary_action(
                        widget::button::standard(fl!("cancel")).on_press(Message::DialogCancel),
                    );
                if let Some(error) = error {
                    dialog = dialog.body(error.clone());
                }
                Some(dialog.into())
            }
            Some(PendingDialog::Font) => {
                let family_idx = FONT_FAMILIES
                    .iter()
                    .position(|f| *f == self.font_family_input)
                    .unwrap_or(0);
                let size_idx = self.font_size_index.min(FONT_SIZES.len() - 1);
                Some(
                    widget::dialog()
                        .title(fl!("font-title"))
                        .control(
                            widget::column::with_capacity(4)
                                .spacing(8)
                                .push(widget::text::body(fl!("font-family")))
                                .push(widget::dropdown(
                                    &self.font_family_labels,
                                    Some(family_idx),
                                    Message::FontFamily,
                                ))
                                .push(
                                    widget::text_input("", &self.font_family_input)
                                        .on_input(Message::FontFamilyInput),
                                )
                                .push(widget::text::body(fl!("font-size")))
                                .push(widget::dropdown(
                                    &self.font_size_labels,
                                    Some(size_idx),
                                    Message::FontSize,
                                )),
                        )
                        .primary_action(
                            widget::button::suggested(fl!("ok")).on_press(Message::ApplyFont),
                        )
                        .secondary_action(
                            widget::button::standard(fl!("cancel")).on_press(Message::DialogCancel),
                        )
                        .into(),
                )
            }
            Some(PendingDialog::Error { message }) => Some(
                widget::dialog()
                    .title(fl!("error"))
                    .body(message.clone())
                    .primary_action(
                        widget::button::suggested(fl!("ok")).on_press(Message::CloseError),
                    )
                    .into(),
            ),
        }
    }

    fn footer(&self) -> Option<Element<'_, Self::Message>> {
        if !self.config.show_status_bar {
            return None;
        }
        let text = self.content.text();
        let cursor = self.content.cursor();
        let (line, col) =
            commands::caret_line_col(&text, cursor.position.line, cursor.position.column);
        let wrap = if self.config.word_wrap {
            fl!("word-wrap-on")
        } else {
            fl!("word-wrap-off")
        };
        Some(
            widget::row::with_capacity(3)
                .push(widget::text::body(wrap))
                .push(widget::space::horizontal())
                .push(widget::text::body(fl!("ln-col", line = line, col = col)))
                .padding(8)
                .align_y(Alignment::Center)
                .into(),
        )
    }

    fn view(&self) -> Element<'_, Self::Message> {
        let mut column = widget::column::with_capacity(2).width(Length::Fill);

        if self.find_visible {
            column = column.push(self.find_bar());
        }

        let wrapping = if self.config.word_wrap {
            Wrapping::Word
        } else {
            Wrapping::None
        };

        let word_wrap = self.config.word_wrap;
        let editor = widget::text_editor::text_editor(&self.content)
            .on_action(Message::Editor)
            .font(self.editor_font)
            .size(f32::from(self.config.font_size))
            .wrapping(wrapping)
            .height(Length::Fill)
            .key_binding(move |press| editor_key_binding(press, word_wrap));

        column.push(editor).into()
    }

    fn subscription(&self) -> Subscription<Self::Message> {
        Subscription::batch(vec![
            self.core()
                .watch_config::<Config>(Self::APP_ID)
                .map(|update| Message::UpdateConfig(update.config)),
            single_instance::subscription().map(Message::OpenExternal),
            window::close_requests().map(|_| Message::Exit),
        ])
    }

    #[allow(clippy::too_many_lines)]
    fn update(&mut self, message: Self::Message) -> Task<Self::Message> {
        match message {
            Message::Editor(action) => {
                if action.is_edit() {
                    let before = self.content.text();
                    let cursor = self.content.cursor();
                    self.content.perform(action);
                    let after = self.content.text();
                    if before != after {
                        self.undo_stack.push((before, cursor));
                        if self.undo_stack.len() > MAX_UNDO_DEPTH {
                            self.undo_stack.remove(0);
                        }
                        self.redo_stack.clear();
                    }
                } else {
                    self.content.perform(action);
                }
                return self.update_title();
            }
            Message::New => return self.guard_unsaved(AfterSave::New),
            Message::Open => return self.guard_unsaved(AfterSave::Open),
            Message::OpenSelected(url) => match url.to_file_path() {
                Ok(path) => return self.guard_unsaved(AfterSave::OpenPath(path)),
                Err(()) => {
                    self.pending = Some(PendingDialog::Error {
                        message: format!("{}\n{url}", fl!("could-not-open")),
                    });
                }
            },
            Message::OpenExternal(files) => {
                let focus = self.core.main_window_id().map(window::gain_focus);
                let open = files
                    .into_iter()
                    .next()
                    .map(|path| self.guard_unsaved(AfterSave::OpenPath(path)));
                return match (focus, open) {
                    (Some(focus), Some(open)) => Task::batch([focus, open]),
                    (Some(focus), None) => focus,
                    (None, Some(open)) => open,
                    (None, None) => Task::none(),
                };
            }
            Message::Save => return self.save(false),
            Message::SaveAs => return self.save_as_dialog(),
            Message::SaveSelected(url) => match url.to_file_path() {
                Ok(path) => return self.write_to(path),
                Err(()) => {
                    self.pending = Some(PendingDialog::Error {
                        message: format!("{}\n{url}", fl!("could-not-save")),
                    });
                }
            },
            Message::Exit => {
                if let Some(PendingDialog::SaveChanges { after }) = &mut self.pending {
                    *after = AfterSave::Close;
                    return Task::none();
                }
                return self.guard_unsaved(AfterSave::Close);
            }
            Message::Undo => {
                if let Some((prev, cursor)) = self.undo_stack.pop() {
                    self.redo_stack
                        .push((self.content.text(), self.content.cursor()));
                    self.content = Content::with_text(&prev);
                    self.content.move_to(cursor);
                    return self.update_title();
                }
            }
            Message::Redo => {
                if let Some((next, cursor)) = self.redo_stack.pop() {
                    self.undo_stack
                        .push((self.content.text(), self.content.cursor()));
                    self.content = Content::with_text(&next);
                    self.content.move_to(cursor);
                    return self.update_title();
                }
            }
            Message::Cut => {
                if let Some(selected) = self.content.selection() {
                    self.push_undo();
                    self.content.perform(Action::Edit(Edit::Delete));
                    return clipboard::write(selected);
                }
            }
            Message::Copy => {
                if let Some(selected) = self.content.selection() {
                    return clipboard::write(selected);
                }
            }
            Message::Paste => {
                return clipboard::read()
                    .map(|value| cosmic::Action::App(Message::ClipboardPaste(value)));
            }
            Message::ClipboardPaste(text) => {
                if let Some(text) = text {
                    self.push_undo();
                    self.content
                        .perform(Action::Edit(Edit::Paste(Arc::new(text))));
                    return self.update_title();
                }
            }
            Message::Delete => {
                self.push_undo();
                self.content.perform(Action::Edit(Edit::Delete));
                return self.update_title();
            }
            Message::Find => {
                self.prefill_search_from_selection();
                self.find_visible = true;
                self.replace_visible = false;
            }
            Message::FindNext => return self.find_next(true),
            Message::Replace => {
                self.prefill_search_from_selection();
                self.find_visible = true;
                self.replace_visible = true;
            }
            Message::ReplaceOne => return self.replace_one(),
            Message::ReplaceAll => return self.replace_all(),
            Message::CloseFind => {
                self.find_visible = false;
                self.replace_visible = false;
            }
            Message::FindText(text) => self.find_text = text,
            Message::ReplaceText(text) => self.replace_text = text,
            Message::MatchCase(value) => self.match_case = value,
            Message::GoTo => {
                if !self.config.word_wrap {
                    let text = self.content.text();
                    let cursor = self.content.cursor();
                    let offset = commands::offset_at_line_col(
                        &text,
                        cursor.position.line,
                        cursor.position.column,
                    );
                    let (line, _) = commands::line_col_at(&text, offset);
                    self.goto_input = line.to_string();
                    self.pending = Some(PendingDialog::GoTo {
                        input: self.goto_input.clone(),
                        error: None,
                    });
                }
            }
            Message::GoToInput(input) => {
                self.goto_input.clone_from(&input);
                if let Some(PendingDialog::GoTo {
                    input: stored,
                    error,
                }) = &mut self.pending
                {
                    *stored = input;
                    *error = None;
                }
            }
            Message::GoToConfirm => return self.confirm_goto(),
            Message::SelectAll => self.content.perform(Action::SelectAll),
            Message::InsertDateTime => {
                self.push_undo();
                self.content
                    .perform(Action::Edit(Edit::Paste(Arc::new(datetime_stamp()))));
                return self.update_title();
            }
            Message::ToggleWrap => {
                self.config.word_wrap = !self.config.word_wrap;
                self.persist_config();
            }
            Message::ToggleStatusBar => {
                self.config.show_status_bar = !self.config.show_status_bar;
                self.persist_config();
            }
            Message::Font => {
                self.font_family_input = self.config.font_family.clone();
                self.font_size_index = FONT_SIZES
                    .iter()
                    .position(|s| *s == self.config.font_size)
                    .unwrap_or(5);
                self.pending = Some(PendingDialog::Font);
            }
            Message::FontFamily(index) => {
                if let Some(family) = FONT_FAMILIES.get(index) {
                    self.font_family_input = (*family).to_string();
                }
            }
            Message::FontSize(index) => self.font_size_index = index.min(FONT_SIZES.len() - 1),
            Message::FontFamilyInput(input) => self.font_family_input = input,
            Message::ApplyFont => {
                self.config.font_family = self.font_family_input.clone();
                self.config.font_size = FONT_SIZES[self.font_size_index.min(FONT_SIZES.len() - 1)];
                self.editor_font = font_from_family(&self.config.font_family);
                self.pending = None;
                self.persist_config();
            }
            Message::Scheme(scheme) => return self.apply_scheme(scheme),
            Message::ToggleScheme => {
                let target = if self.effective_is_dark() {
                    ColorScheme::Light
                } else {
                    ColorScheme::Dark
                };
                return self.apply_scheme(target);
            }
            Message::ToggleContextPage(ContextPage::About) => {
                if self.context_page == ContextPage::About {
                    self.core.window.show_context = !self.core.window.show_context;
                } else {
                    self.context_page = ContextPage::About;
                    self.core.window.show_context = true;
                }
            }
            Message::LaunchUrl(url) => {
                if let Err(err) = open::that_detached(&url) {
                    eprintln!("failed to open {url:?}: {err}");
                }
            }
            Message::DialogCancel => {
                self.pending = None;
                self.pending_after = None;
            }
            Message::DialogSave => {
                if let Some(PendingDialog::SaveChanges { after }) = self.pending.take() {
                    self.pending_after = Some(after);
                    return self.save(false);
                }
            }
            Message::DialogDiscard => {
                if let Some(PendingDialog::SaveChanges { after }) = self.pending.take() {
                    self.pending_after = None;
                    self.saved_text = self.content.text();
                    return self.proceed(after);
                }
            }
            Message::CloseError => {
                if let Some(after) = self.pending_after.clone() {
                    self.pending = Some(PendingDialog::SaveChanges { after });
                } else {
                    self.pending = None;
                }
            }
            Message::UpdateConfig(config) => {
                let scheme_changed = self.config.color_scheme != config.color_scheme;
                self.config = config;
                self.editor_font = font_from_family(&self.config.font_family);
                if scheme_changed {
                    return command::set_theme(theme_for(self.config.color_scheme));
                }
            }
            Message::Error(message) => {
                self.pending = Some(PendingDialog::Error { message });
            }
            Message::Cancelled => {
                self.pending_after = None;
            }
        }

        Task::none()
    }

    fn on_escape(&mut self) -> Task<Self::Message> {
        if self.pending.is_some() {
            self.pending = None;
            self.pending_after = None;
            return Task::none();
        }
        if self.core.window.show_context {
            self.core.window.show_context = false;
            return Task::none();
        }
        if self.find_visible {
            self.find_visible = false;
            self.replace_visible = false;
        }
        Task::none()
    }

    fn on_app_exit(&mut self) -> Option<Self::Message> {
        Some(Message::Exit)
    }

    fn on_close_requested(&self, _id: window::Id) -> Option<Self::Message> {
        if matches!(self.pending, Some(PendingDialog::SaveChanges { .. })) {
            return Some(Message::Exit);
        }
        if self.is_dirty() {
            Some(Message::Exit)
        } else {
            None
        }
    }

    fn system_theme_update(
        &mut self,
        _keys: &[&'static str],
        _new_theme: &cosmic::cosmic_theme::Theme,
    ) -> Task<Self::Message> {
        if self.config.color_scheme == ColorScheme::System {
            command::set_theme(cosmic::theme::system_preference())
        } else {
            Task::none()
        }
    }
}

impl App {
    /// Builds the app from an already-resolved config — the test seam
    /// (T02; architecture.md §3.5). `init` delegates here with the real
    /// config; tests inject `None` or a `with_custom_path` handler so no
    /// real `~/.config` is ever touched (R4). Behavior is unchanged.
    fn with_config(
        core: cosmic::Core,
        flags: Flags,
        config: Config,
        config_handler: Option<cosmic_config::Config>,
    ) -> (Self, Task<Message>) {
        let about = About::default()
            .name(fl!("app-title"))
            .icon(widget::icon::from_svg_bytes(APP_ICON))
            .version(env!("CARGO_PKG_VERSION"))
            .links([(fl!("repository"), REPOSITORY)])
            .license(env!("CARGO_PKG_LICENSE"));

        let mut app = App {
            core,
            about,
            context_page: ContextPage::About,
            key_binds: key_bind::key_binds(),
            editor_font: font_from_family(&config.font_family),
            font_family_input: config.font_family.clone(),
            font_size_index: FONT_SIZES
                .iter()
                .position(|s| *s == config.font_size)
                .unwrap_or(5),
            config,
            config_handler,
            content: Content::new(),
            file_path: None,
            saved_text: String::new(),
            pending_after: None,
            find_visible: false,
            replace_visible: false,
            find_text: String::new(),
            replace_text: String::new(),
            match_case: false,
            goto_input: String::from("1"),
            pending: None,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            font_family_labels: FONT_FAMILIES.iter().map(|s| (*s).to_string()).collect(),
            font_size_labels: FONT_SIZES.iter().map(ToString::to_string).collect(),
        };
        app.saved_text = app.content.text();

        let mut tasks = vec![
            app.update_title(),
            command::set_theme(theme_for(app.config.color_scheme)),
        ];

        if let Some(path) = flags.files.first() {
            tasks.push(app.load_path(path.clone()));
        }

        (app, Task::batch(tasks))
    }

    fn edit_menu_items(&self) -> Vec<menu::Tree<Message>> {
        let mut items = menu::items(
            &self.key_binds,
            vec![
                menu::Item::CheckBox(fl!("undo"), None, false, MenuAction::Undo),
                menu::Item::CheckBox(fl!("redo"), None, false, MenuAction::Redo),
                menu::Item::Divider,
                menu::Item::CheckBox(fl!("cut"), None, false, MenuAction::Cut),
                menu::Item::CheckBox(fl!("copy"), None, false, MenuAction::Copy),
                menu::Item::CheckBox(fl!("paste"), None, false, MenuAction::Paste),
                menu::Item::CheckBox(fl!("delete"), None, false, MenuAction::Delete),
                menu::Item::Divider,
                menu::Item::CheckBox(fl!("find"), None, false, MenuAction::Find),
                menu::Item::CheckBox(fl!("find-next"), None, false, MenuAction::FindNext),
                menu::Item::CheckBox(fl!("replace"), None, false, MenuAction::Replace),
            ],
        );
        if self.config.word_wrap {
            items.push(aligned_disabled_item(
                fl!("go-to"),
                menu_shortcut(MenuAction::GoTo, &self.key_binds),
            ));
        } else {
            items.extend(menu::items(
                &self.key_binds,
                vec![menu::Item::CheckBox(
                    fl!("go-to"),
                    None,
                    false,
                    MenuAction::GoTo,
                )],
            ));
        }
        items.extend(menu::items(
            &self.key_binds,
            vec![
                menu::Item::CheckBox(fl!("select-all"), None, false, MenuAction::SelectAll),
                menu::Item::CheckBox(fl!("time-date"), None, false, MenuAction::InsertDateTime),
            ],
        ));
        items
    }

    fn view_menu_items(&self) -> Vec<menu::Tree<Message>> {
        let scheme = self.config.color_scheme;
        let mut items = menu::items(
            &self.key_binds,
            vec![menu::Item::CheckBox(
                fl!("status-bar"),
                None,
                self.config.show_status_bar,
                MenuAction::ToggleStatusBar,
            )],
        );
        items.push(aligned_folder(
            fl!("color-scheme"),
            menu::items(
                &self.key_binds,
                vec![
                    menu::Item::CheckBox(
                        fl!("system"),
                        None,
                        scheme == ColorScheme::System,
                        MenuAction::Scheme(ColorScheme::System),
                    ),
                    menu::Item::CheckBox(
                        fl!("light"),
                        None,
                        scheme == ColorScheme::Light,
                        MenuAction::Scheme(ColorScheme::Light),
                    ),
                    menu::Item::CheckBox(
                        fl!("dark"),
                        None,
                        scheme == ColorScheme::Dark,
                        MenuAction::Scheme(ColorScheme::Dark),
                    ),
                ],
            ),
        ));
        items
    }

    fn is_dirty(&self) -> bool {
        self.content.text() != self.saved_text
    }

    fn effective_is_dark(&self) -> bool {
        match self.config.color_scheme {
            ColorScheme::Dark => true,
            ColorScheme::Light => false,
            ColorScheme::System => cosmic::theme::is_dark(),
        }
    }

    fn persist_config(&self) {
        if let Some(handler) = &self.config_handler {
            let _ = self.config.write_entry(handler);
        }
    }

    fn apply_scheme(&mut self, scheme: ColorScheme) -> Task<Message> {
        self.config.color_scheme = scheme;
        self.persist_config();
        command::set_theme(theme_for(scheme))
    }

    fn update_title(&mut self) -> Task<Message> {
        let untitled = fl!("untitled");
        let name = self
            .file_path
            .as_ref()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .unwrap_or(&untitled);
        let marker = if self.is_dirty() { "•  " } else { "" };
        let title = format!("{marker}{name} — {}", fl!("app-title"));
        self.set_header_title(title.clone());
        if let Some(id) = self.core.main_window_id() {
            self.set_window_title(title, id)
        } else {
            Task::none()
        }
    }

    fn push_undo(&mut self) {
        self.undo_stack
            .push((self.content.text(), self.content.cursor()));
        if self.undo_stack.len() > MAX_UNDO_DEPTH {
            self.undo_stack.remove(0);
        }
        self.redo_stack.clear();
    }

    fn find_bar(&self) -> Element<'_, Message> {
        let close = widget::button::icon(icon::from_name("window-close-symbolic"))
            .on_press(Message::CloseFind)
            .tooltip(fl!("close-find-tooltip"));

        // FlexRow keeps the desktop single-line look but wraps the search
        // field onto its own line on narrow windows (360px minimum) instead
        // of crushing it between the fixed-size controls.
        let find_row = widget::flex_row(vec![
            close.into(),
            widget::text_input(fl!("find-placeholder"), &self.find_text)
                .on_input(Message::FindText)
                .on_submit(|_| Message::FindNext)
                .apply(widget::container)
                .width(Length::Fill)
                .into(),
            widget::checkbox(self.match_case)
                .label(fl!("match-case"))
                .on_toggle(Message::MatchCase)
                .into(),
            widget::button::standard(fl!("find-next"))
                .on_press(Message::FindNext)
                .into(),
        ])
        .spacing(6)
        .padding(8)
        .justify_items(Alignment::Center)
        .min_item_width(160.0)
        .width(Length::Fill);

        if self.replace_visible {
            widget::column::with_capacity(2)
                .push(find_row)
                .push(
                    widget::flex_row(vec![
                        widget::text_input(fl!("replace-placeholder"), &self.replace_text)
                            .on_input(Message::ReplaceText)
                            .on_submit(|_| Message::ReplaceOne)
                            .apply(widget::container)
                            .width(Length::Fill)
                            .into(),
                        widget::button::standard(fl!("replace-one"))
                            .on_press(Message::ReplaceOne)
                            .into(),
                        widget::button::standard(fl!("replace-all"))
                            .on_press(Message::ReplaceAll)
                            .into(),
                    ])
                    .spacing(6)
                    .padding([0, 8, 8, 8])
                    .justify_items(Alignment::Center)
                    .min_item_width(160.0)
                    .width(Length::Fill),
                )
                .into()
        } else {
            find_row.into()
        }
    }

    fn prefill_search_from_selection(&mut self) {
        if let Some(selected) = self.content.selection()
            && !selected.is_empty()
            && !selected.contains('\n')
        {
            self.find_text = selected;
        }
    }

    fn needle(&self) -> String {
        self.find_text.clone()
    }

    fn find_next(&mut self, show_not_found: bool) -> Task<Message> {
        let needle = self.needle();
        if needle.is_empty() {
            return Task::none();
        }
        let text = self.content.text();
        let cursor = self.content.cursor();
        let start = cursor_end(&text, cursor);
        if let Some((from, to)) = commands::find_next(&text, start, &needle, self.match_case, true)
        {
            self.select_range(&text, from, to);
        } else if show_not_found {
            self.pending = Some(PendingDialog::Error {
                message: fl!("cannot-find", text = needle.as_str()),
            });
        }
        Task::none()
    }

    fn replace_one(&mut self) -> Task<Message> {
        let needle = self.needle();
        if needle.is_empty() {
            return Task::none();
        }
        let text = self.content.text();
        let cursor = self.content.cursor();
        let selection = cursor_selection(&text, cursor);
        match commands::replace_and_find_next(
            &text,
            selection,
            &needle,
            &self.replace_text,
            self.match_case,
            true,
        ) {
            None => {
                self.pending = Some(PendingDialog::Error {
                    message: fl!("cannot-find", text = needle.as_str()),
                });
            }
            Some(ReplaceResult::Found { range }) => {
                self.select_range(&text, range.0, range.1);
            }
            Some(ReplaceResult::Replaced {
                text: new_text,
                next,
            }) => {
                self.push_undo();
                self.content = Content::with_text(&new_text);
                if let Some((from, to)) = next {
                    self.select_range(&new_text, from, to);
                }
                return self.update_title();
            }
        }
        Task::none()
    }

    fn replace_all(&mut self) -> Task<Message> {
        let needle = self.needle();
        if needle.is_empty() {
            return Task::none();
        }
        let text = self.content.text();
        let (new_text, count) =
            commands::replace_all(&text, &needle, &self.replace_text, self.match_case);
        if count == 0 {
            self.pending = Some(PendingDialog::Error {
                message: fl!("cannot-find", text = needle.as_str()),
            });
            Task::none()
        } else {
            self.push_undo();
            self.content = Content::with_text(&new_text);
            self.update_title()
        }
    }

    fn select_range(&mut self, text: &str, from: usize, to: usize) {
        self.content.move_to(text_editor::Cursor {
            position: offset_to_position(text, to),
            selection: Some(offset_to_position(text, from)),
        });
    }

    fn confirm_goto(&mut self) -> Task<Message> {
        let raw = self.goto_input.trim();
        let Ok(line) = raw.parse::<usize>() else {
            if let Some(PendingDialog::GoTo { error, .. }) = &mut self.pending {
                *error = Some(fl!("invalid-line-number"));
            } else {
                self.pending = Some(PendingDialog::Error {
                    message: fl!("invalid-line-number"),
                });
            }
            return Task::none();
        };
        let text = self.content.text();
        match commands::goto_line(&text, line) {
            Some(offset) => {
                self.pending = None;
                self.content.move_to(text_editor::Cursor {
                    position: offset_to_position(&text, offset),
                    selection: None,
                });
            }
            None => {
                if let Some(PendingDialog::GoTo { error, .. }) = &mut self.pending {
                    *error = Some(fl!("line-beyond-end"));
                } else {
                    self.pending = Some(PendingDialog::GoTo {
                        input: self.goto_input.clone(),
                        error: Some(fl!("line-beyond-end")),
                    });
                }
            }
        }
        Task::none()
    }

    fn guard_unsaved(&mut self, after: AfterSave) -> Task<Message> {
        if self.is_dirty() {
            self.pending = Some(PendingDialog::SaveChanges { after });
            Task::none()
        } else {
            self.proceed(after)
        }
    }

    fn proceed(&mut self, after: AfterSave) -> Task<Message> {
        match after {
            AfterSave::New => self.reset_document(),
            AfterSave::Open => self.open_dialog(),
            AfterSave::OpenPath(path) => self.load_path(path),
            AfterSave::Close => self.close_window(),
        }
    }

    fn reset_document(&mut self) -> Task<Message> {
        self.content = Content::new();
        self.saved_text = self.content.text();
        self.file_path = None;
        self.undo_stack.clear();
        self.redo_stack.clear();
        self.update_title()
    }

    fn load_path(&mut self, path: PathBuf) -> Task<Message> {
        // `read` + lossy conversion: plain-text files in legacy encodings
        // (Latin-1, Windows-1252) still open instead of failing outright.
        // Valid UTF-8 round-trips byte-identically.
        match std::fs::read(&path) {
            Ok(bytes) => {
                let text = String::from_utf8_lossy(&bytes).into_owned();
                self.content = Content::with_text(&text);
                self.saved_text = self.content.text();
                self.file_path = Some(path);
                self.undo_stack.clear();
                self.redo_stack.clear();
                self.update_title()
            }
            Err(err) => {
                self.pending = Some(PendingDialog::Error {
                    message: format!("{}\n{err}", fl!("could-not-open")),
                });
                Task::none()
            }
        }
    }

    fn save(&mut self, force_as: bool) -> Task<Message> {
        if !force_as && let Some(path) = self.file_path.clone() {
            return self.write_to(path);
        }
        self.save_as_dialog()
    }

    fn write_to(&mut self, path: PathBuf) -> Task<Message> {
        let text = self.content.text();
        match std::fs::write(&path, &text) {
            Ok(()) => {
                self.file_path = Some(path);
                self.saved_text = text;
                let title = self.update_title();
                if let Some(after) = self.pending_after.take() {
                    // A New/Open/Exit requested while the save dialog was in
                    // flight may have raised a second save prompt. The
                    // document is saved now, so that prompt is stale.
                    if matches!(self.pending, Some(PendingDialog::SaveChanges { .. })) {
                        self.pending = None;
                    }
                    Task::batch([title, self.proceed(after)])
                } else {
                    title
                }
            }
            Err(err) => {
                self.pending = Some(PendingDialog::Error {
                    message: format!("{}\n{err}", fl!("could-not-save")),
                });
                Task::none()
            }
        }
    }

    fn open_dialog(&self) -> Task<Message> {
        let directory = self
            .file_path
            .as_ref()
            .and_then(|p| p.parent().map(Path::to_path_buf));
        cosmic::task::future(async move {
            let mut dialog = file_chooser::open::Dialog::new()
                .title(fl!("open-title"))
                .filter(FileFilter::new(&fl!("text-files")).glob("*.txt"))
                .filter(FileFilter::new(&fl!("all-files")).glob("*"));
            if let Some(directory) = directory {
                dialog = dialog.directory(directory);
            }
            match dialog.open_file().await {
                Ok(response) => Message::OpenSelected(response.url().clone()),
                Err(file_chooser::Error::Cancelled) => Message::Cancelled,
                Err(why) => Message::Error(why.to_string()),
            }
        })
    }

    fn save_as_dialog(&self) -> Task<Message> {
        let untitled = format!("{}.txt", fl!("untitled"));
        let name = self
            .file_path
            .as_ref()
            .and_then(|p| p.file_name())
            .and_then(|n| n.to_str())
            .unwrap_or(&untitled)
            .to_string();
        let directory = self
            .file_path
            .as_ref()
            .and_then(|p| p.parent().map(Path::to_path_buf));
        cosmic::task::future(async move {
            let mut dialog = file_chooser::save::Dialog::new()
                .title(fl!("save-as-title"))
                .file_name(name)
                .filter(FileFilter::new(&fl!("text-files")).glob("*.txt"))
                .filter(FileFilter::new(&fl!("all-files")).glob("*"));
            if let Some(directory) = directory {
                dialog = dialog.directory(directory);
            }
            match dialog.save_file().await {
                Ok(response) => match response.url() {
                    Some(url) => Message::SaveSelected(url.clone()),
                    None => Message::Cancelled,
                },
                Err(file_chooser::Error::Cancelled) => Message::Cancelled,
                Err(why) => Message::Error(why.to_string()),
            }
        })
    }

    fn close_window(&self) -> Task<Message> {
        let exit = iced::exit();
        if let Some(id) = self.core.main_window_id() {
            Task::batch([iced::window::close(id), exit])
        } else {
            exit
        }
    }
}

fn editor_key_binding(press: KeyPress, word_wrap: bool) -> Option<Binding<Message>> {
    match &press.key {
        Key::Named(Named::F5) => Some(Binding::Custom(Message::InsertDateTime)),
        Key::Named(Named::F3) => Some(Binding::Custom(Message::FindNext)),
        Key::Character(c) if press.modifiers.control() => match c.as_str() {
            "f" => Some(Binding::Custom(Message::Find)),
            "h" => Some(Binding::Custom(Message::Replace)),
            "g" if !word_wrap => Some(Binding::Custom(Message::GoTo)),
            "n" => Some(Binding::Custom(Message::New)),
            "o" => Some(Binding::Custom(Message::Open)),
            "s" if press.modifiers.shift() => Some(Binding::Custom(Message::SaveAs)),
            "s" => Some(Binding::Custom(Message::Save)),
            "q" => Some(Binding::Custom(Message::Exit)),
            "z" if press.modifiers.shift() => Some(Binding::Custom(Message::Redo)),
            "z" => Some(Binding::Custom(Message::Undo)),
            "y" => Some(Binding::Custom(Message::Redo)),
            _ => Binding::from_key_press(press),
        },
        _ => Binding::from_key_press(press),
    }
}

fn intern_family(name: &str) -> &'static str {
    static FAMILIES: OnceLock<Mutex<HashMap<String, &'static str>>> = OnceLock::new();
    let mut map = FAMILIES
        .get_or_init(|| Mutex::new(HashMap::new()))
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(existing) = map.get(name) {
        return existing;
    }
    let leaked: &'static str = Box::leak(name.to_string().into_boxed_str());
    map.insert(name.to_string(), leaked);
    leaked
}

fn font_from_family(family: &str) -> Font {
    let family = match family {
        "monospace" | "Monospace" => Family::Monospace,
        "sans-serif" | "Sans Serif" | "sans" => Family::SansSerif,
        "serif" | "Serif" => Family::Serif,
        other => Family::Name(intern_family(other)),
    };
    Font {
        family,
        weight: Weight::Normal,
        stretch: Stretch::Normal,
        style: FontStyle::Normal,
    }
}

/// Maximum undo/redo entries. Snapshots hold the whole document, so an
/// unbounded stack grows without limit during long editing sessions.
const MAX_UNDO_DEPTH: usize = 100;

fn datetime_stamp() -> String {
    let now = chrono::Local::now();
    let hour = now.format("%I").to_string();
    let hour = hour.trim_start_matches('0');
    let hour = if hour.is_empty() { "12" } else { hour };
    format!(
        "{hour}:{} {} {}/{}/{}",
        now.format("%M"),
        now.format("%p"),
        now.month(),
        now.day(),
        now.year()
    )
}

fn offset_to_position(text: &str, mut offset: usize) -> text_editor::Position {
    offset = offset.min(text.len());
    while offset > 0 && !text.is_char_boundary(offset) {
        offset -= 1;
    }
    let prefix = &text[..offset];
    let line = prefix.bytes().filter(|&b| b == b'\n').count();
    let start = prefix.rfind('\n').map_or(0, |i| i + 1);
    let column = text[start..offset].chars().count();
    text_editor::Position { line, column }
}

fn cursor_end(text: &str, cursor: text_editor::Cursor) -> usize {
    let caret = commands::offset_at_line_col(text, cursor.position.line, cursor.position.column);
    if let Some(sel) = cursor.selection {
        let other = commands::offset_at_line_col(text, sel.line, sel.column);
        caret.max(other)
    } else {
        caret
    }
}

fn cursor_selection(text: &str, cursor: text_editor::Cursor) -> Option<(usize, usize)> {
    let caret = commands::offset_at_line_col(text, cursor.position.line, cursor.position.column);
    cursor.selection.map(|sel| {
        let other = commands::offset_at_line_col(text, sel.line, sel.column);
        if caret <= other {
            (caret, other)
        } else {
            (other, caret)
        }
    })
}

#[cfg(test)]
#[path = "app_test_harness.rs"]
mod app_test_harness;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn intern_family_reuses_the_same_pointer() {
        let first = intern_family("JetBrains Mono");
        let second = intern_family("JetBrains Mono");
        assert!(std::ptr::eq(first, second));
        assert_eq!(first, "JetBrains Mono");
    }

    #[test]
    fn offset_to_position_snaps_mid_utf8() {
        let text = "é\n日本語";
        let at_mid = offset_to_position(text, 1);
        assert_eq!(at_mid.line, 0);
        assert_eq!(at_mid.column, 0);
        let second_line = offset_to_position(text, "é\n".len());
        assert_eq!(second_line.line, 1);
        assert_eq!(second_line.column, 0);
    }

    #[test]
    fn cursor_end_uses_the_end_of_the_selection() {
        let text = "abc";
        let cursor = text_editor::Cursor {
            position: text_editor::Position { line: 0, column: 1 },
            selection: Some(text_editor::Position { line: 0, column: 3 }),
        };
        assert_eq!(cursor_end(text, cursor), 3);
    }
}
