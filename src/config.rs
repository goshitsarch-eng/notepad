// SPDX-License-Identifier: GPL-3.0-or-later

use cosmic::cosmic_config::{self, CosmicConfigEntry, cosmic_config_derive::CosmicConfigEntry};
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
