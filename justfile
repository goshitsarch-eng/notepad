# Name of the application's binary.
name := 'notepad'
# The unique ID of the application.
appid := 'com.goshapps.Notepad'

# Path to root file system, which defaults to `/`.
rootdir := ''
# The prefix for the `/usr` directory.
prefix := '/usr'
# The location of the cargo target directory.
cargo-target-dir := env('CARGO_TARGET_DIR', 'target')

# Application's appstream metadata
appdata := appid + '.metainfo.xml'
# Application's desktop entry
desktop := appid + '.desktop'

# Install destinations
base-dir := absolute_path(clean(rootdir / prefix))
metainfo-dst := base-dir / 'share' / 'metainfo' / appdata
bin-dst := base-dir / 'bin' / name
desktop-dst := base-dir / 'share' / 'applications' / desktop
icon-svg-dst := base-dir / 'share' / 'icons' / 'hicolor' / 'scalable' / 'apps' / appid + '.svg'
license-dst := base-dir / 'share' / 'licenses' / appid

# Default recipe which runs `just build-release`
default: build-release

# Runs `cargo clean`
clean:
    cargo clean

# Removes vendored dependencies
clean-vendor:
    rm -rf .cargo vendor vendor.tar

# `cargo clean` and removes vendored dependencies
clean-dist: clean clean-vendor

# Compiles with debug profile
build-debug *args:
    cargo build --locked {{args}}

# Compiles with release profile
build-release *args: (build-debug '--release' args)

# Compiles release profile with vendored dependencies
build-vendored *args: vendor-extract (build-release '--frozen --offline' args)

# Runs a clippy check
check *args:
    cargo clippy --all-features --locked {{args}} -- -W clippy::pedantic

# Runs a clippy check with JSON message format
check-json: (check '--message-format=json')

# Run the application for testing purposes
run *args:
    env RUST_BACKTRACE=full cargo run --release --locked {{args}}

# Run unit and packaging tests
test:
    cargo test --locked

# Packaging identity and metadata checks
test-packaging:
    cargo test --test packaging --locked

# Installs files
install:
    install -Dm0755 {{ cargo-target-dir / 'release' / name }} {{bin-dst}}
    install -Dm0644 {{ 'data' / desktop }} {{desktop-dst}}
    install -Dm0644 {{ 'data' / appdata }} {{metainfo-dst}}
    install -Dm0644 {{ 'data' / 'icons' / 'hicolor' / 'scalable' / 'apps' / appid + '.svg' }} {{icon-svg-dst}}
    install -Dm0644 LICENSE {{ license-dst / 'LICENSE' }}
    install -Dm0644 COPYRIGHT {{ license-dst / 'COPYRIGHT' }}

# Uninstalls installed files
uninstall:
    rm -f {{bin-dst}} {{desktop-dst}} {{metainfo-dst}} {{icon-svg-dst}} {{ license-dst / 'LICENSE' }} {{ license-dst / 'COPYRIGHT' }}

# Vendor dependencies locally
vendor:
    mkdir -p .cargo
    cargo vendor | head -n -1 > .cargo/config.toml
    echo 'directory = "vendor"' >> .cargo/config.toml
    tar pcf vendor.tar vendor
    rm -rf vendor

# Extracts vendored dependencies
vendor-extract:
    rm -rf vendor
    tar pxf vendor.tar
