# CI / release architecture

## Workflows

- `.github/workflows/ci.yml` — push to `main` and pull requests:
  `cargo fmt --check`, `cargo clippy --all-features --locked -- -W
  clippy::pedantic`, `cargo test --locked` on `ubuntu-24.04`; a native
  `cargo check --locked` on `ubuntu-24.04-arm` keeps aarch64 honest
  between releases. No publishing happens here.
- `.github/workflows/release.yml` — tag push (`v*`) or manual dispatch
  with a tag input.

## Release flow

```
validate            tag ↔ Cargo.toml ↔ metainfo ↔ README consistency,
                    fmt + clippy + tests on the tagged commit
   │
   ├── native       matrix x86_64 → ubuntu-24.04 / aarch64 → ubuntu-24.04-arm
   │                cargo build --release --locked, `file` arch check,
   │                scripts/package-tarball.sh → dist/*.tar.gz
   │
   └── flatpak      same matrix; scripts/package-flatpak.sh →
                    vendor.sh → flatpak-builder → build-bundle →
                    bundle-info arch check → dist/*.flatpak
   │
release             downloads all four artifacts, writes SHA256SUMS,
                    scripts/verify-release.sh enforces the complete set,
                    draft release → upload --clobber → publish →
                    asserts the five expected assets are attached
```

`fail-fast: false` on both matrices so one architecture's failure can't
cancel the other — but `release` needs both, so a failed arch means no
release, not a partial one.

## Runners

- x86_64: `ubuntu-24.04`
- aarch64: `ubuntu-24.04-arm` (native arm64, free-tier in private repos —
  2 vCPU on private repos vs 4 on public, so arm jobs are slower)

No QEMU, no cross-emulation, no cross-compile: each architecture builds on
real hardware and the output is arch-verified with `file` on the binary and
the `app/<id>/<arch>/<branch>` ref embedded in each Flatpak bundle.

## Caching

- Cargo registry/git/target: `cargo-<os>-<arch>-<Cargo.lock hash>` — arch is
  in the key, so x86 and arm builds can never share a cache.
- `vendor.tar`: `vendor-<arch>-<Cargo.lock hash>`; restored tar is `touch`ed
  because `scripts/vendor.sh` compares mtime against `Cargo.lock`.

## Permissions

Workflow-level `contents: read`. Only the `release` job gets
`contents: write`, which `gh release` needs.

## Third-party actions

`actions/checkout@v7`, `actions/cache@v6`, `actions/upload-artifact@v7`,
`actions/download-artifact@v8` — first-party actions pinned to major tags.
Rust comes from rustup (respects `rust-toolchain.toml`); the release is
created with the `gh` CLI — no third-party release action.
