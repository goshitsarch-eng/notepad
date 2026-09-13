# GitHub Releases

## Trigger

`git tag vX.Y.Z && git push origin vX.Y.Z` runs `release.yml`. A manual
re-run for an existing tag is available through workflow_dispatch (Actions
▸ Release ▸ Run workflow ▸ tag input).

## Tag and version contract

- Tags are `vX.Y.Z` (existing convention: v2.0.2, v2.0.3, v2.0.4).
- `scripts/check-version.sh` fails the release unless the tag matches
  `Cargo.toml` `version`, a `<release version="X.Y.Z">` metainfo entry, and
  the README `Current release` line. `tests/packaging.rs` pins the same
  strings — bump it in the same commit when releasing.

## Publication

1. All build jobs must succeed — `release` `needs:` the full matrix.
2. Artifacts download into `dist/`; `SHA256SUMS` is generated there.
3. `scripts/verify-release.sh` enforces the complete set before anything
   is created.
4. `gh release create <tag> --draft --generate-notes --title "Notepad
   X.Y.Z"` — draft first, so a half-uploaded release is never public.
5. `gh release upload <tag> dist/* --clobber`, then `gh release edit
   --draft=false`.
6. Final step asserts the release is non-draft and carries exactly the
   five required assets.

Reruns are safe: an existing release is reused, `--clobber` replaces
same-named assets, and re-publishing is a no-op. Nothing creates a second
release for the same tag.

## Permissions

Only the `release` job has `contents: write` (required to create the
release and upload assets). Build and validation jobs are read-only.

## Assets

| Asset | Content |
|---|---|
| `notepad-vX.Y.Z-linux-x86_64.tar.gz` | native build, installable layout |
| `notepad-vX.Y.Z-linux-aarch64.tar.gz` | same, aarch64 |
| `notepad-vX.Y.Z-linux-x86_64.flatpak` | single-file bundle, x86_64 |
| `notepad-vX.Y.Z-linux-aarch64.flatpak` | same, aarch64 |
| `SHA256SUMS` | checksums for the four artifacts |

Release notes are GitHub-generated (`--generate-notes`); curated text
lives in the metainfo release entries.
