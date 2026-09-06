// SPDX-License-Identifier: GPL-3.0-or-later

use crate::app::MenuAction;
use cosmic::iced::keyboard::{Key, key::Named};
use cosmic::widget::menu::key_bind::{KeyBind, Modifier};
use std::collections::HashMap;

/// Default Notepad key bindings for the menu bar.
#[must_use]
pub fn key_binds() -> HashMap<KeyBind, MenuAction> {
    let mut map = HashMap::new();

    let bind = |modifiers: Vec<Modifier>, key: Key, action: MenuAction| {
        (KeyBind { modifiers, key }, action)
    };

    for (key_bind, action) in [
        bind(
            vec![Modifier::Ctrl],
            Key::Character("n".into()),
            MenuAction::New,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("o".into()),
            MenuAction::Open,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("s".into()),
            MenuAction::Save,
        ),
        bind(
            vec![Modifier::Ctrl, Modifier::Shift],
            Key::Character("s".into()),
            MenuAction::SaveAs,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("q".into()),
            MenuAction::Exit,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("z".into()),
            MenuAction::Undo,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("y".into()),
            MenuAction::Redo,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("x".into()),
            MenuAction::Cut,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("c".into()),
            MenuAction::Copy,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("v".into()),
            MenuAction::Paste,
        ),
        bind(vec![], Key::Named(Named::Delete), MenuAction::Delete),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("f".into()),
            MenuAction::Find,
        ),
        bind(vec![], Key::Named(Named::F3), MenuAction::FindNext),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("h".into()),
            MenuAction::Replace,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("g".into()),
            MenuAction::GoTo,
        ),
        bind(
            vec![Modifier::Ctrl],
            Key::Character("a".into()),
            MenuAction::SelectAll,
        ),
        bind(vec![], Key::Named(Named::F5), MenuAction::InsertDateTime),
    ] {
        map.insert(key_bind, action);
    }

    map
}
