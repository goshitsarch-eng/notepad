# Releasing NotePad

Releases are tag-driven. GitHub Actions builds the artifacts; nobody builds or
uploads anything by hand.

1. Bump `version` in `Cargo.toml` and refresh `Cargo.lock`
   (`cargo update -p notepad` or a build does it).
2. Add a `<release version="X.Y.Z" date="…">` entry to
   `data/com.goshapps.Notepad.metainfo.xml`.
3. Update the `Current release: **X.Y.Z**` line in `README.md`.
4. Update the pinned strings in `tests/packaging.rs` — the packaging tests
   deliberately hard-fail on the old version otherwise.
5. Commit, then tag and push:

   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The release workflow validates the version, builds the x86_64 and aarch64
tarballs and Flatpaks on native runners, checksums everything, and publishes
the GitHub Release. If any architecture fails, nothing is published.

To re-run a release for an existing tag: Actions ▸ Release ▸ Run workflow ▸
enter the tag. The publish step is idempotent — it reuses the release and
overwrites same-named assets.
