# Packaging

Version comes from the git tag (`vX.Y.Z` → `X.Y.Z`), verified against
`Cargo.toml` by `scripts/check-version.sh` before anything builds.

## Tarball — `scripts/package-tarball.sh <version> <arch>`

`cargo build --release --locked`, then an intentional staging layout:

```
notepad-v3.0.0-linux-x86_64/
├── bin/notepad
├── share/applications/com.goshapps.Notepad.desktop
├── share/metainfo/com.goshapps.Notepad.metainfo.xml
├── share/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg
├── share/licenses/com.goshapps.Notepad/{LICENSE,COPYRIGHT}
├── README.md
└── install.sh          # copies into $PREFIX (default ~/.local)
```

`file` on the binary must match the matrix arch (`x86-64` / `aarch64`)
or the script fails. Output: `dist/notepad-v<ver>-linux-<arch>.tar.gz`.

## Flatpak — `scripts/package-flatpak.sh <version> <arch>`

1. `./scripts/vendor.sh` — materializes `vendor/` + `.cargo/config.toml`
   (the manifest builds `cargo build --release --frozen --offline` from a
   `type: dir` source, so vendored sources must exist on disk).
2. `flatpak install --user` of the manifest's runtime set: Platform 25.08,
   Sdk 25.08, `Sdk.Extension.rust-stable` + `llvm21`, and
   `com.system76.Cosmic.BaseApp//stable` — all served by flathub for both
   x86_64 and aarch64 (the BaseApp is an `app/` ref).
3. `flatpak-builder --user --repo=repo --install-deps-from=flathub
   --force-clean build-flatpak com.goshapps.Notepad.json`
4. `flatpak build-bundle --arch=<arch> repo dist/…flatpak
   com.goshapps.Notepad stable`
5. The bundle's embedded `app/com.goshapps.Notepad/<arch>/stable` ref must
   match the matrix arch (checked with `grep -a` — `flatpak bundle-info`
   requires flatpak ≥ 1.15, newer than Ubuntu 24.04's 1.14).

The bundle is a single-file installable: `flatpak install --user x.flatpak`.

## Whole-set check — `scripts/verify-release.sh <dir> <version>`

Asserts all five files exist and are non-empty, extracts each tarball and
`file`-checks `bin/notepad`, checks each flatpak's embedded ref arch, runs
`sha256sum -c SHA256SUMS`, and fails on stray/duplicate files.

## Checksums

The release job writes `SHA256SUMS` over the four artifacts after
downloading them — the file is verified before upload and shipped as a
release asset.
