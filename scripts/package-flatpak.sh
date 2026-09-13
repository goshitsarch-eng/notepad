#!/usr/bin/env bash
# Build the Flatpak and produce dist/notepad-v<ver>-linux-<arch>.flatpak
#
# Usage: scripts/package-flatpak.sh <version> <x86_64|aarch64>
#
# Requires: flatpak, flatpak-builder, cargo, and the flathub remote at user
# level (flatpak remote-add --user --if-not-exists flathub
# https://dl.flathub.org/repo/flathub.flatpakrepo). All runtime deps
# (Platform, Sdk, rust-stable, llvm21, Cosmic.BaseApp) are pulled from
# flathub per com.goshapps.Notepad.json.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?usage: package-flatpak.sh <version> <arch>}"
arch="${2:?usage: package-flatpak.sh <version> <arch>}"

./scripts/vendor.sh

# Deps per com.goshapps.Notepad.json; explicit install keeps
# --install-deps-from as a fallback instead of the only mechanism.
flatpak install --user -y --noninteractive flathub \
    org.freedesktop.Platform//25.08 \
    org.freedesktop.Sdk//25.08 \
    org.freedesktop.Sdk.Extension.rust-stable//25.08 \
    org.freedesktop.Sdk.Extension.llvm21//25.08 \
    com.system76.Cosmic.BaseApp//stable

flatpak-builder --user --repo=repo --install-deps-from=flathub \
    --force-clean --state-dir="$PWD/.flatpak-builder" \
    build-flatpak com.goshapps.Notepad.json

mkdir -p dist
out="dist/notepad-v${version}-linux-${arch}.flatpak"
flatpak build-bundle --arch="$arch" repo "$out" com.goshapps.Notepad stable

# The bundle must be for the claimed architecture. `flatpak bundle-info`
# only exists in flatpak ≥ 1.15; the ref embedded in the bundle header
# (app/<id>/<arch>/<branch>) is portable.
grep -aqm1 "app/com.goshapps.Notepad/$arch/stable" "$out" ||
    { echo "flatpak bundle is not arch $arch" >&2; exit 1; }

echo "wrote $out"
