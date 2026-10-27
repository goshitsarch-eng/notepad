#!/usr/bin/env bash
# Builds a single-file Flatpak bundle from the Godot Linux export.
#
# Usage: packaging/flatpak/build.sh <executable> <version> <arch> <output-dir>
#   executable  the exported xp_notepad file, from `godot --export-release "Linux x86_64"`
#   version     the app version, for example 0.2.0
#   arch        x64 or arm64, used in the file name
#   output-dir  receives xp-notepad-<version>-<arch>.flatpak
#
# The build runs in a scratch folder, so nothing in the repository changes. The
# freedesktop runtime and SDK come from Flathub and must be built for the host architecture.
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <executable> <version> <arch> <output-dir>" >&2
  exit 2
fi

executable=$(realpath "$1")
version=$2
arch=$3
output_dir=$(realpath -m "$4")
here=$(cd "$(dirname "$0")" && pwd)
runtime_version=25.08
flathub_repo=https://dl.flathub.org/repo/

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cp "$executable" "$work/xp_notepad"
cp "$here/com.goshapps.Notepad.yml" \
   "$here/com.goshapps.Notepad.desktop" \
   "$here/com.goshapps.Notepad.metainfo.xml" \
   "$here/../icons/com.goshapps.Notepad.svg" \
   "$work/"

flatpak remote-add --user --if-not-exists flathub "${flathub_repo}flathub.flatpakrepo"
flatpak install --user --noninteractive flathub \
  "org.freedesktop.Platform//${runtime_version}" "org.freedesktop.Sdk//${runtime_version}"

# The state directory must be on the same filesystem as the build folder. flatpak-builder's
# default, .flatpak-builder in the current folder, would put files in the repository.
flatpak-builder --user --force-clean --disable-rofiles-fuse \
  --state-dir="$work/state" --repo="$work/repo" "$work/build-dir" "$work/com.goshapps.Notepad.yml"

mkdir -p "$output_dir"
flatpak build-bundle --runtime-repo="${flathub_repo}flathub.flatpakrepo" \
  "$work/repo" "$output_dir/xp-notepad-${version}-${arch}.flatpak" com.goshapps.Notepad

echo "wrote $output_dir/xp-notepad-${version}-${arch}.flatpak"
