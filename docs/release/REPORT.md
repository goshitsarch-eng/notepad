# Release pipeline report

## Setup verified before writing workflows

- No `.github/` existed — this is the first CI/release automation.
- Tag convention: `vX.Y.Z` (v2.0.2–v2.0.4 exist; releases for them exist
  on GitHub). v3.0.0 not yet tagged — the source tree is 3.0.0.
- Version of record: `Cargo.toml`; `tests/packaging.rs` pins it against
  metainfo and README.
- Repo is private; arm64 standard runners (`ubuntu-24.04-arm`) are
  free-tier eligible in private repos as of the Jan 2026 rollout — native
  ARM builds, no emulation.
- Flathub serves aarch64 for every dep in the manifest: Platform 25.08,
  Sdk 25.08, `Sdk.Extension.rust-stable`, `Sdk.Extension.llvm21`, and
  `com.system76.Cosmic.BaseApp//stable` (an `app/` ref — `remote-ls
  --runtime` doesn't list it; confirmed via `remote-info`).

## Design

- `ci.yml`: fmt + pedantic clippy + tests on `ubuntu-24.04`;
  `cargo check` on `ubuntu-24.04-arm`.
- `release.yml`: `validate` (version consistency + full lint/test) →
  `native` + `flatpak` matrices (x86_64 on `ubuntu-24.04`, aarch64 on
  `ubuntu-24.04-arm`) → `release` (collect, checksum, verify, draft,
  upload, publish, assert assets).
- Scripts: `check-version.sh`, `package-tarball.sh`,
  `package-flatpak.sh`, `verify-release.sh` — logic lives in the repo,
  YAML only orchestrates.
- Permissions: `contents: read` everywhere except the `release` job
  (`contents: write`).
- Architecture is verified, not assumed: `file` on each binary, embedded
  `app/<id>/<arch>/<branch>` ref in each bundle.

## Run log

### Run 1 — tag push v3.0.0 (34775311520)

- `validate`: pass (version consistency + fmt/clippy/test on the tag).
- `native` x86_64 + aarch64: pass.
- `flatpak` x86_64 + aarch64: **fail** — the builds and exports succeeded;
  only the arch check failed: `flatpak bundle-info` does not exist in
  Ubuntu 24.04's flatpak 1.14 (added in 1.15). Fixed by grepping the
  `app/<id>/<arch>/<branch>` ref embedded in the bundle, which also
  removed verify-release.sh's flatpak dependency.
- `release`: correctly skipped — no partial release.

### Tag move

v3.0.0 re-tagged to the fix commit (`git tag -f`, force-pushed) — the tag
must contain the working scripts because jobs check out the tag. No
release existed yet, so nothing was corrupted.

### Run 2 — tag push v3.0.0 (34776238706)

- All four builds passed; draft release created, five assets uploaded,
  published.
- `release` job then **failed** on the post-publish asset assertion: the
  check built names without the `v` prefix (`notepad-3.0.0-*` vs actual
  `notepad-v3.0.0-*`). Cosmetic workflow bug — the release itself was
  complete and correct. Fixed; v3.0.0 re-tagged again.

### Manual verification of the published release

All five assets downloaded from GitHub; `sha256sum -c` passes; the x86_64
tarball contains an x86-64 ELF, the aarch64 tarball an ARM aarch64 ELF;
each bundle embeds `app/com.goshapps.Notepad/<arch>/stable` for the right
arch; the x86_64 bundle was installed with `flatpak install --user
--bundle` and launched successfully.

### Run 3 — tag push v3.0.0 (34777241142) — green end-to-end

All six jobs succeeded in 14m: validate, both native tarballs, both
Flatpaks, and release (verify → draft → upload → publish → asset
assertion). Same-tag reruns reuse the release and `--clobber` identical
asset names.

Final state: https://github.com/goshitsarch-eng/notepad/releases/tag/v3.0.0
— `Notepad 3.0.0`, non-draft, five assets:
`notepad-v3.0.0-linux-{x86_64,aarch64}.{tar.gz,flatpak}` + `SHA256SUMS`.

