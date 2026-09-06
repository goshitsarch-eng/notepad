// SPDX-License-Identifier: GPL-3.0-or-later

mod app;
mod commands;
mod config;
mod i18n;
mod key_bind;
mod single_instance;

use crate::app::{App, Flags};
use crate::config::{Config, theme_for};
use cosmic::Application;
use cosmic::app::Settings;
use cosmic::cosmic_config::{self, CosmicConfigEntry};
use cosmic::iced::{Limits, Size};
use std::path::PathBuf;

fn abs_path(arg: String) -> PathBuf {
    let path = PathBuf::from(arg);
    if path.is_absolute() {
        path
    } else {
        std::env::current_dir()
            .map(|cwd| cwd.join(&path))
            .unwrap_or(path)
    }
}

fn main() -> cosmic::iced::Result {
    let requested_languages = i18n_embed::DesktopLanguageRequester::requested_languages();
    i18n::init(&requested_languages);

    let files: Vec<PathBuf> = std::env::args()
        .skip(1)
        .filter(|arg| !arg.is_empty() && !arg.starts_with('-'))
        .map(abs_path)
        .collect();

    if single_instance::forward(&files) {
        return Ok(());
    }

    let startup_theme = cosmic_config::Config::new(App::APP_ID, Config::VERSION)
        .map(|handler| Config::get_entry(&handler).unwrap_or_else(|(_, config)| config))
        .unwrap_or_default();

    let settings = Settings::default()
        .size(Size::new(820.0, 600.0))
        .size_limits(Limits::NONE.min_width(360.0).min_height(180.0))
        .theme(theme_for(startup_theme.color_scheme))
        .transparent(false)
        .exit_on_close(false);

    cosmic::app::run::<App>(settings, Flags { files })
}
