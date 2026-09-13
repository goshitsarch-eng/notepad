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
- Architecture is verified, not assumed: `file` on each binary,
  `flatpak bundle-info` on each bundle.

## Run log

_To be filled after the first live run._
