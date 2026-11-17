#!/usr/bin/env bash
# Builds, signs, notarizes and staples a macOS release: release/<Name>.app and release/<Name>-<version>.dmg.
#
# Usage: tools/release-macos.sh [keychain-profile]      (default profile: godot-notary)
#
# The password is never passed to this script. Store it once in the keychain, see docs/MACOS-RELEASE.md.
# Environment overrides: GODOT (godot binary), SIGN_IDENTITY (name or SHA-1 of the Developer ID
# Application certificate; default: the first one in the keychain), EXPORT_PRESET (default: macOS),
# SKIP_TESTS=1.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
profile="${1:-godot-notary}"
godot_bin="${GODOT:-godot}"
preset="${EXPORT_PRESET:-macOS}"
entitlements="$root/packaging/macos/entitlements.plist"

step() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Name, version and bundle ID come from the project, never from this script.
name="$(sed -n 's/^config\/name="\(.*\)"/\1/p' project.godot | head -1)"
version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot | head -1)"
bundle_id="$(awk -v p="$preset" '
  /^\[preset\.[0-9]+\]$/ { sec = $0; next }
  $0 == "name=\"" p "\"" { want = sec; sub(/\]$/, ".options]", want) }
  /^\[/ { cur = $0 }
  want != "" && cur == want && /^application\/bundle_identifier=/ { gsub(/^[^"]*"|"$/, ""); print; exit }
' export_presets.cfg)"
[[ -n "$name" && -n "$version" && -n "$bundle_id" ]] || die "could not read name/version/bundle ID from project.godot and export_presets.cfg"
printf 'App: %s  Version: %s  Bundle ID: %s  Profile: %s\n' "$name" "$version" "$bundle_id" "$profile"

identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application/ { print $2; exit }')}"
[[ -n "$identity" ]] || die "no Developer ID Application identity in the keychain"
xcrun notarytool history --keychain-profile "$profile" > /dev/null 2>&1 \
  || die "keychain profile '$profile' does not work; see docs/MACOS-RELEASE.md"

out="$root/release"
app="$out/$name.app"
dmg="$out/$name-$version.dmg"
work="$(mktemp -d "${TMPDIR:-/tmp}/release-macos.XXXXXX")"
trap 'hdiutil detach "$work/mnt" -quiet 2>/dev/null || true; rm -rf "$work"' EXIT

# Runs notarytool and fails unless the submission is Accepted. Prints the submission ID.
notarize() {
  local file="$1" result id status
  result="$work/notary.json"
  xcrun notarytool submit "$file" --keychain-profile "$profile" --wait --output-format json > "$result" || true
  id="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$result")"
  status="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$result")"
  printf 'Submission ID: %s  Status: %s\n' "$id" "$status"
  echo "$id" >> "$out/submission-ids.txt"
  if [[ "$status" != "Accepted" ]]; then
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$profile" >&2 || true
    die "notarization of $(basename "$file") was not accepted"
  fi
}

step "1. Test and export"
if [[ "${SKIP_TESTS:-0}" != 1 ]]; then tools/run_tests.sh | tail -3; fi
rm -rf "$app" "$dmg" "$out/$name.zip" "$out/submission-ids.txt"
mkdir -p "$out"
"$godot_bin" --headless --path . --import > /dev/null 2>&1 || true
"$godot_bin" --headless --path . --export-release "$preset" "$out/$name.zip"
ditto -x -k "$out/$name.zip" "$out"
rm -f "$out/$name.zip"
[[ -d "$app" ]] || die "export did not produce $app"
lipo -archs "$app/Contents/MacOS/"* | sed 's/^/Architectures: /'

step "2. Sign the app (inside-out)"
sign() { codesign --force --options runtime --timestamp --entitlements "$entitlements" --sign "$identity" "$@"; }
# Nested code first, deepest paths first: Mach-O files plus bundles (frameworks, helper apps, plug-ins).
main_exe="$app/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")"
{
  while IFS= read -r -d '' f; do
    [[ "$f" == "$main_exe" ]] && continue
    file -b "$f" | grep -q 'Mach-O' && printf '%s\n' "$f"
  done < <(find "$app/Contents" -type f -print0)
  find "$app/Contents" -type d \( -name '*.framework' -o -name '*.app' -o -name '*.bundle' -o -name '*.xpc' \)
} | awk -F/ '{ print NF "\t" $0 }' | sort -rn | cut -f2- | while IFS= read -r f; do
  echo "  signing ${f#$app/}"
  sign "$f"
done
sign "$main_exe"
sign "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dvv "$app" 2>&1 | grep -E 'Identifier|Authority|TeamIdentifier|Timestamp|flags'

step "3. Notarize and staple the app"
ditto -c -k --keepParent "$app" "$work/app.zip"
notarize "$work/app.zip"
xcrun stapler staple "$app"
xcrun stapler validate "$app"

step "4. Build the DMG from the stapled app"
stage="$work/stage"
mkdir -p "$stage"
ditto "$app" "$stage/$name.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "$name" -srcfolder "$stage" -ov -format UDZO "$dmg"

step "5. Sign, notarize and staple the DMG"
codesign --force --timestamp --sign "$identity" "$dmg"
notarize "$dmg"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

step "6. Verify like a customer"
spctl -a -t exec -vv "$app"
spctl -a -t open --context context:primary-signature -vv "$dmg"
xcrun stapler validate "$app"
xcrun stapler validate "$dmg"
cust="$work/customer"
mkdir -p "$cust" "$work/mnt"
ditto "$dmg" "$cust/$name-$version.dmg"
xattr -w com.apple.quarantine "0081;00000000;Safari;" "$cust/$name-$version.dmg"
hdiutil attach "$cust/$name-$version.dmg" -mountpoint "$work/mnt" -nobrowse -quiet
ditto "$work/mnt/$name.app" "$cust/$name.app"
hdiutil detach "$work/mnt" -quiet
xattr -w com.apple.quarantine "0081;00000000;Safari;" "$cust/$name.app"
spctl -a -t exec -vv "$cust/$name.app"
before="$(pgrep -x "$name" || true)"
open -n "$cust/$name.app"
sleep 5
# A quarantined app runs from an AppTranslocation path, so find it by the PIDs that are new.
started="$(comm -13 <(echo "$before" | sort) <(pgrep -x "$name" | sort) || true)"
if [[ -n "$started" ]]; then
  echo "Launched under Gatekeeper with quarantine, running as PID $(echo $started): OK"
  kill $started || true
else
  die "app did not stay running when opened with quarantine"
fi

step "Done"
ls -lh "$dmg"
echo "Notarization submission IDs:"; cat "$out/submission-ids.txt"
