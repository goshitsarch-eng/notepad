// SPDX-License-Identifier: GPL-3.0-or-later

use cosmic::cosmic_config::{self, CosmicConfigEntry, cosmic_config_derive::CosmicConfigEntry};
use cosmic::theme::ThemeType;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Default, Eq, Hash, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ColorScheme {
    #[default]
    System,
    Light,
    Dark,
}

#[derive(Debug, Clone, CosmicConfigEntry, Eq, PartialEq, Serialize, Deserialize)]
#[version = 1]
pub struct Config {
    pub color_scheme: ColorScheme,
    pub word_wrap: bool,
    pub show_status_bar: bool,
    pub font_family: String,
    pub font_size: u16,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            color_scheme: ColorScheme::System,
            word_wrap: false,
            show_status_bar: true,
            font_family: "monospace".into(),
            font_size: 14,
        }
    }
}

/// Theme for the given scheme.
///
/// Light/Dark must not use `ThemeType::System`. libcosmic overwrites System
/// themes with the desktop palette, which made Light/Dark appear to do nothing
/// and left window-control icons on the wrong contrast.
pub fn theme_for(scheme: ColorScheme) -> cosmic::Theme {
    match scheme {
        ColorScheme::System => cosmic::theme::system_preference(),
        ColorScheme::Light => pin_independent(cosmic::theme::system_light()),
        ColorScheme::Dark => pin_independent(cosmic::theme::system_dark()),
    }
}

fn pin_independent(mut theme: cosmic::Theme) -> cosmic::Theme {
    theme.theme_type = match theme.theme_type {
        ThemeType::System { theme: inner, .. } => ThemeType::Custom(inner),
        other => other,
    };
    theme
}
