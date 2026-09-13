#!/usr/bin/env bash
# Fail if a release tag disagrees with the version recorded in the source.
#
# Usage: scripts/check-version.sh v3.0.0
#
# Checks tag == Cargo.toml version == latest metainfo release == README's
# "Current release" line. The packaging tests pin the same values, so a
# release also requires updating tests/packaging.rs (deliberate ratchet).
set -euo pipefail
cd "$(dirname "$0")/.."

tag="${1:?usage: scripts/check-version.sh <tag>}"
version="${tag#v}"
fail() { echo "version check failed: $*" >&2; exit 1; }

case "$version" in
    ''|*[!0-9.]*) fail "tag $tag is not a vX.Y.Z version" ;;
esac

cargo_version="$(grep -m1 '^version = ' Cargo.toml | cut -d'"' -f2)"
[ "$version" = "$cargo_version" ] ||
    fail "tag $tag but Cargo.toml says $cargo_version"

grep -q "<release version=\"$version\"" data/com.goshapps.Notepad.metainfo.xml ||
    fail "metainfo has no <release version=\"$version\"> entry"

grep -q "Current release: \*\*$version\*\*" README.md ||
    fail "README does not say \"Current release: **$version**\""

echo "version $version consistent: tag, Cargo.toml, metainfo, README"
