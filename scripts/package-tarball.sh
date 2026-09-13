#!/usr/bin/env bash
# Build the release binary and package dist/notepad-v<ver>-linux-<arch>.tar.gz
#
# Usage: scripts/package-tarball.sh <version> <x86_64|aarch64>
#
# The archive contains an intentional layout (bin/, share/, licenses,
# install.sh) — not a dump of target/release.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: package-tarball.sh <version> <arch>}"
arch="${2:?usage: package-tarball.sh <version> <arch>}"

case "$arch" in
    x86_64)  elf_arch='x86-64' ;;
    aarch64) elf_arch='aarch64' ;;
    *) echo "unknown arch: $arch" >&2; exit 1 ;;
esac

name="notepad-v${version}-linux-${arch}"
stage="dist/stage/$name"

cargo build --release --locked

# The archive must contain a binary for the claimed architecture.
file target/release/notepad | grep -q "$elf_arch" ||
    { file target/release/notepad; echo "binary is not $arch ($elf_arch)" >&2; exit 1; }

rm -rf "$stage"
mkdir -p "$stage/bin" "$stage/share/applications" "$stage/share/metainfo" \
    "$stage/share/icons/hicolor/scalable/apps" \
    "$stage/share/licenses/com.goshapps.Notepad"

install -Dm0755 target/release/notepad "$stage/bin/notepad"
install -Dm0644 data/com.goshapps.Notepad.desktop \
    "$stage/share/applications/com.goshapps.Notepad.desktop"
install -Dm0644 data/com.goshapps.Notepad.metainfo.xml \
    "$stage/share/metainfo/com.goshapps.Notepad.metainfo.xml"
install -Dm0644 data/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg \
    "$stage/share/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg"
install -Dm0644 LICENSE "$stage/share/licenses/com.goshapps.Notepad/LICENSE"
install -Dm0644 COPYRIGHT "$stage/share/licenses/com.goshapps.Notepad/COPYRIGHT"
install -Dm0644 README.md "$stage/README.md"

cat > "$stage/install.sh" <<'EOF'
#!/bin/sh
# Install into $PREFIX (default ~/.local); use PREFIX=/usr for system-wide.
set -eu
prefix="${PREFIX:-$HOME/.local}"
self="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
install -Dm0755 "$self/bin/notepad" "$prefix/bin/notepad"
install -Dm0644 "$self/share/applications/com.goshapps.Notepad.desktop" \
    "$prefix/share/applications/com.goshapps.Notepad.desktop"
install -Dm0644 "$self/share/metainfo/com.goshapps.Notepad.metainfo.xml" \
    "$prefix/share/metainfo/com.goshapps.Notepad.metainfo.xml"
install -Dm0644 "$self/share/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg" \
    "$prefix/share/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg"
install -Dm0644 "$self/share/licenses/com.goshapps.Notepad/LICENSE" \
    "$prefix/share/licenses/com.goshapps.Notepad/LICENSE"
install -Dm0644 "$self/share/licenses/com.goshapps.Notepad/COPYRIGHT" \
    "$prefix/share/licenses/com.goshapps.Notepad/COPYRIGHT"
echo "installed notepad under $prefix"
EOF
chmod +x "$stage/install.sh"

mkdir -p dist
tar -C dist/stage -czf "dist/$name.tar.gz" "$name"
rm -rf dist/stage
echo "wrote dist/$name.tar.gz"
