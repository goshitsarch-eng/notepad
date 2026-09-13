# Contributing

## Setup

You need a recent stable Rust toolchain (1.93 or newer — libcosmic requires
it), plus the usual desktop build deps. On Fedora:

```bash
sudo dnf install cargo git just cmake pkgconf \
    expat-devel fontconfig-devel freetype-devel libxkbcommon-devel
```

On Pop!_OS / Ubuntu:

```bash
sudo apt install cargo cmake just libexpat1-dev libfontconfig-dev \
    libfreetype-dev libxkbcommon-dev pkgconf
```

`just` is optional — the build/test/lint recipes wrap the cargo commands
shown below (`install`/`uninstall`/`vendor*` are plain file operations).

## Build, run, test

```bash
cargo build --locked      # debug build
just run                  # release build + run (RUST_BACKTRACE=full)
cargo test --locked       # unit + packaging tests (49 tests)
cargo clippy --all-targets --locked -- -D warnings   # lint gate
just check                # optional stricter pass (clippy::pedantic, warnings only)
cargo fmt --check         # formatting gate
```

Keep the tree green: `fmt`, `clippy -D warnings`, and `cargo test --locked`
should all pass before you send a change.

`tests/packaging.rs` pins more than you might expect — it asserts on
README strings (the current-release line, "leading check column"), the
manifest's finish-args (exactly six), the libcosmic rev pin in both
`Cargo.toml` and `Cargo.lock`, and license installation lines. If you
intentionally change any of those, update the test in the same commit.

## Vendored dependencies

`cargo` builds from the network by default. The vendored copy under `vendor/`
exists only for the **offline Flatpak build** — `scripts/vendor.sh`
materializes `vendor/` + `.cargo/config.toml` (both gitignored) and caches
them in `vendor.tar`. While `vendor/` is materialized, all cargo commands run
offline against it; `just clean-vendor` removes it again. Re-run the script
whenever `Cargo.lock` changes.

Use `scripts/vendor.sh`, not `just vendor`: the just recipe deletes `vendor/`
after tarring it, leaving `.cargo/config.toml` pointed at a directory that no
longer exists — plain cargo commands fail until `just vendor-extract` (or
`just clean-vendor`) puts the tree back.

## Flatpak development build

```bash
./scripts/vendor.sh
flatpak-builder --user --install-deps-from=flathub --install --force-clean \
    build-flatpak com.goshapps.Notepad.json
flatpak run com.goshapps.Notepad
```

## Style notes

- `app.rs` is a monolith on purpose: `Message` enum + one `update` match, iced
  style. Editor logic that can be pure (find/replace/go-to/caret math) lives
  in `commands.rs` so it stays unit-testable.
- User-visible strings go through `fl!()` with keys in
  `i18n/en/notepad.ftl`.
- Tests that touch the app state use the `#[cfg(test)]` harness
  (`src/app_test_harness.rs`) — never the real `~/.config`.
- No open PR/MR process is formalized — this is a personal project. Filing an
  issue first is a good idea for anything beyond a small fix.

## Translations

Only `i18n/en/notepad.ftl` ships today. To add a locale, copy it to
`i18n/<lang>/notepad.ftl` and translate the values; the loader picks the
session language automatically.
