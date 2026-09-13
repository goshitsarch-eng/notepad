#!/usr/bin/env bash
# Verify a release-artifact directory contains the complete, correct set.
#
# Usage: scripts/verify-release.sh <dir> <version>
#
# Requires all of:
#   notepad-v<ver>-linux-x86_64.tar.gz
#   notepad-v<ver>-linux-aarch64.tar.gz
#   notepad-v<ver>-linux-x86_64.flatpak
#   notepad-v<ver>-linux-aarch64.flatpak
#   SHA256SUMS        (verified with sha256sum -c when present)
#
# Each tarball must extract and contain an executable bin/notepad of the
# claimed architecture; each flatpak bundle must embed the matching
# app/<id>/<arch>/stable ref.
set -euo pipefail

dir="${1:?usage: verify-release.sh <dir> <version>}"
version="${2:?usage: verify-release.sh <dir> <version>}"
fail() { echo "verify-release: $*" >&2; exit 1; }

cd "$dir"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for arch in x86_64 aarch64; do
    tb="notepad-v${version}-linux-${arch}.tar.gz"
    fp="notepad-v${version}-linux-${arch}.flatpak"
    case "$arch" in x86_64) elf='x86-64' ;; *) elf='aarch64' ;; esac

    [ -s "$tb" ] || fail "missing or empty: $tb"
    [ -s "$fp" ] || fail "missing or empty: $fp"

    tar -xzf "$tb" -C "$tmp" ||
        fail "$tb is not a valid gzip tarball"
    bin="$tmp/notepad-v${version}-linux-${arch}/bin/notepad"
    [ -x "$bin" ] || fail "$tb lacks executable bin/notepad"
    file "$bin" | grep -q "$elf" ||
        fail "$tb contains wrong-arch binary: $(file "$bin")"

    grep -aqm1 "app/com.goshapps.Notepad/$arch/stable" "$fp" ||
        fail "$fp is not arch $arch"
    echo "ok: $tb ($arch binary verified)"
    echo "ok: $fp (arch $arch verified)"
done

[ -s SHA256SUMS ] || fail "missing or empty: SHA256SUMS"
sha256sum -c SHA256SUMS ||
    fail "SHA256SUMS does not match the artifacts"

# Exactly the five expected assets — no strays, no duplicates.
count="$(find . -maxdepth 1 -type f | wc -l)"
[ "$count" -eq 5 ] || fail "expected 5 files, found $count"

echo "release artifact set complete: v$version (x86_64 + aarch64)"
