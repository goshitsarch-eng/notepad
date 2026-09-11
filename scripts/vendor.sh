#!/usr/bin/env bash
# Materialize vendored cargo sources for offline Flatpak builds (D9, P2-T05).
#
# Cache contract (gitignored vendor.tar): holds vendor/ AND .cargo/config.toml
# (config-inside-tar delta, approved). Freshness key: Cargo.lock — the vendor
# stanzas are source-replacement entries keyed on cargo source ID, so a lock
# change (e.g. the T05 rev-pin rewrite) invalidates the cache. A-before-B
# ordering is load-bearing: never materialize vendor/ from a stale lock.
#
# CI note (T25/RV-16): after restoring vendor.tar from a job cache, run
# `touch vendor.tar` so the cache wins the freshness comparison.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f vendor.tar ] && [ vendor.tar -nt Cargo.lock ]; then
    tar pxf vendor.tar
else
    rm -rf vendor
    mkdir -p .cargo
    cargo vendor | head -n -1 > .cargo/config.toml
    echo 'directory = "vendor"' >> .cargo/config.toml
    tar pcf vendor.tar vendor .cargo/config.toml
fi
# vendor/ stays materialized: the Flatpak manifest source is `type: dir`,
# which copies the working tree — vendor/ must exist on disk at build time.
