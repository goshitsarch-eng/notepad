#!/usr/bin/env bash
# Downloads Godot 4.7.2 (stable) for this Linux or macOS machine, checks it against the checksums
# in tools/godot-4.7.2.sha512, and puts the editor binary in <install-dir>. With --templates it
# also installs the export templates, which `godot --export-release` needs.
#
# Usage: tools/install_godot.sh <install-dir> [--templates]
# The editor is <install-dir>/godot afterwards.
set -euo pipefail

version=4.7.2
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
here=$(cd "$(dirname "$0")" && pwd)
sums="$here/godot-${version}.sha512"

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <install-dir> [--templates]" >&2
  exit 2
fi
install_dir=$(mkdir -p "$1" && cd "$1" && pwd)
templates=no
[ "${2:-}" = "--templates" ] && templates=yes

os_name=$(uname -s)
case "$os_name" in
  Darwin)
    editor="Godot_v${version}-stable_macos.universal.zip"
    binary="Godot.app/Contents/MacOS/Godot"
    ;;
  Linux)
    case "$(uname -m)" in
      x86_64) editor="Godot_v${version}-stable_linux.x86_64.zip"; binary="Godot_v${version}-stable_linux.x86_64" ;;
      aarch64|arm64) editor="Godot_v${version}-stable_linux.arm64.zip"; binary="Godot_v${version}-stable_linux.arm64" ;;
      *) echo "unsupported machine: $(uname -m)" >&2; exit 1 ;;
    esac
    ;;
  *) echo "unsupported OS: $os_name" >&2; exit 1 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sha512_file() {
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$1" | cut -d' ' -f1
  else
    shasum -a 512 "$1" | cut -d' ' -f1
  fi
}

fetch() {
  local file=$1
  curl -fsSL --retry 3 -o "$work/$file" "$base/$file"
  local expected actual
  expected=$(grep -F "  $file" "$sums" | cut -d' ' -f1)
  [ -n "$expected" ] || { echo "no pinned checksum for $file" >&2; exit 1; }
  actual=$(sha512_file "$work/$file")
  if [ "$expected" != "$actual" ]; then
    echo "checksum mismatch for $file" >&2
    exit 1
  fi
}

fetch "$editor"
unzip -oq "$work/$editor" -d "$install_dir"
chmod +x "$install_dir/$binary"
ln -sf "$binary" "$install_dir/godot"

if [ "$templates" = yes ]; then
  fetch "Godot_v${version}-stable_export_templates.tpz"
  if [ "$os_name" = "Darwin" ]; then
    target="$HOME/Library/Application Support/Godot/export_templates/${version}.stable"
  else
    target="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${version}.stable"
  fi
  mkdir -p "$target"
  unzip -oq "$work/Godot_v${version}-stable_export_templates.tpz" -d "$work/templates"
  cp -a "$work/templates/templates/." "$target/"
fi

echo "Godot ${version} is in $install_dir"
