# macOS release

`tools/release-macos.sh` runs the tests, exports the universal (arm64 + x86_64) app, signs it with the
hardened runtime, notarizes and staples it, builds a DMG, signs, notarizes and staples that too, then checks
the result the way a customer's Mac would (Gatekeeper, stapled tickets, a quarantined launch).

Needs: Godot 4.7 with its export templates, a "Developer ID Application" certificate in the login keychain,
and Xcode command line tools.

## One-time setup

Store the notarization credentials in the keychain under a profile name. The script only ever sees the
profile name, never the password, so nothing secret goes into a file or a commit. Use an app-specific
password from appleid.apple.com.

    xcrun notarytool store-credentials "godot-notary" --apple-id "<apple id>" --team-id "<team id>"

(With no `--password`, notarytool prompts for it.)

## Release

    tools/release-macos.sh godot-notary

Output is in `release/`: `<Name>.app` and `<Name>-<version>.dmg`, plus `submission-ids.txt` with the
notarization submission IDs. The name, version and bundle ID are read from `project.godot` and the macOS
export preset in `export_presets.cfg`.

Environment overrides: `SIGN_IDENTITY` (certificate name or SHA-1), `GODOT`, `EXPORT_PRESET`, `SKIP_TESTS=1`.

## Notes

- Godot's own signing and notarization are off in the export preset (`codesign/codesign=0`,
  `notarization/notarization=0`); the script signs afterwards.
- `packaging/macos/entitlements.plist` holds the entitlements Godot needs under the hardened runtime
  (JIT, unsigned executable memory, disabled library validation).
- A universal export needs `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`.
- If notarization is rejected, the script prints `notarytool log` and stops. The usual causes are an unsigned
  nested binary, a missing timestamp or a missing hardened-runtime flag.
