# Packaging & QA — Phase 1 plan (audit, vendoring, smoke test, verify/CI design)

Owner: packager. Status: Phase 1 (plan; no source changes made). Date: 2026-09-10,
**updated 2026-09-11** (lead acceptance; D9–D13 recorded in DECISIONS.md; §3.1
install mechanism rewritten after the `--installation` disproof; §0 row 3 and the §9
Phase-3 preview reconciled to the D3 addendum; two VERIFY-P2 items retired; RV-2
and RV-6 doc fixes applied after the reviewer's Phase-1 pass —
`docs/migration/review-phase1.md`).

Method: read-only repo audit + read-only environment probes + throwaway spikes in
`/tmp` (allowed; nothing written inside the repo except this file, no git commits,
no packages installed, no flatpak-builder runs in the repo). Spike locations:
`/tmp/vendor-spike` (vendoring + offline build + liveness runs; **kept warm for
P2-T3**), `/tmp/np-smoke-repo` (build-export of the lead's baseline build dir;
**kept for P2-T5**), `/tmp/np-flatpak-baseline{,.log}` (lead's). Consumed spikes
(`/tmp/smoke-rt*`, `/tmp/np-xdg`, `/tmp/np-tmp-inst`, `/tmp/xvfb-app.log`) were
removed. All spike processes were terminated and all spike flatpak installs
uninstalled (`pgrep weston|notepad` → clean; installation verified residue-free).

---

## 0. Environment ground truth (updated after lead's baseline build)

**Update 2026-09-10 (lead):** the lead ran a baseline `flatpak-builder` of the CURRENT
`com.goshapps.Notepad.json` into `/tmp/np-flatpak-baseline` (log:
`/tmp/np-flatpak-baseline.log`): **exit 0**, `files/bin/notepad` exported,
`share/metainfo/com.goshapps.Notepad.metainfo.xml` exported. The log shows
flatpak-builder **auto-installed** `org.freedesktop.Sdk/x86_64/25.08` +
`rust-stable 1.98.1` + Locale from flathub as dependency resolution; `flatpak list
--runtime` now confirms Sdk 25.08 (freedesktop-sdk-25.08.16), rust-stable 1.98.1,
llvm21 21.1.8, BaseApp all present in the active (sandbox-HOME) user installation.
Consequences: **the existing manifest is a WORKING starting point** — runtime/SDK/base/
extensions/lld-RUSTFLAGS all resolve and the git libcosmic dep compiles in-sandbox
(with `--share=network`). The remaining design deltas are exactly: (1) vendored
offline sources, (2) dropping `--share=network`, (3) finish-args minimality,
(4) smoke test via **isolated installation — never the user installation**,
(5) non-COSMIC proof via headless display. Bonus observations from the baseline
build dir: `files/bin/` also contains `just` (Cosmic BaseApp prepopulates `/app`
and ships `just` — so in-sandbox builds *could* use `just`, but per lead decision
host scripts stay plain cargo/flatpak-builder); the log's "Not exporting
share/icons/Cosmic/…, non-allowed export filename" lines are BaseApp icon-theme
assets that flatpak deliberately doesn't export — benign, expected.

**Update 2026-09-11 (lead acceptance + reconciliation):** this plan was ACCEPTED;
decisions D9 (vendor-on-demand), D10 (libcosmic rev pin), D11 (smoke protocol per
§3), D12 (desktop Categories + metainfo provides fixes; UX sign-off granted) and
D13 (smoke-test installation mechanism, superseding the `--installation` detail of
D3/D11) are recorded in `docs/migration/DECISIONS.md`. The 2.0.4 question is
settled: **2.0.4 is definitively NOT installed anywhere** (D3 addendum) — live A/B
runtime comparison is OFF; parity is verified via 2.0.4 behavioral contracts ported
into Rust tests plus the Phase-3 `docs/migration/ux.md` checklist. `cargo fmt
--check` is adopted as verify.sh step 1 (D6 addendum). The packager's D13 spike
proved the full smoke pipeline end-to-end through the real flatpak sandbox (§3.1).

Earlier probes from this shell (note: `HOME=/home/gosh/ubuntuccqwen`, i.e. the agent
sandbox has its **own** flatpak user installation, distinct from `/home/gosh`):

| Claim (lead brief) | Measured reality | Evidence |
|---|---|---|
| `org.freedesktop.Sdk//25.08` + `rust-stable//25.08` installed | Initially **NOT installed in the active (sandbox HOME) user installation** (`flatpak info org.freedesktop.Sdk//25.08` → `error: ... not installed`) — **RESOLVED**: the lead's baseline flatpak-builder run auto-installed both from flathub (log head: `Installing org.freedesktop.Sdk/x86_64/25.08 from flathub`; `flatpak list --runtime` now shows Sdk 25.08 + rust-stable 1.98.1). They also exist in `/home/gosh/.local/share/flatpak/runtime/` (the real user's installation), which our shells do not use. | `/tmp/np-flatpak-baseline.log`; `flatpak list --runtime`; `ls /home/gosh/.local/share/flatpak/runtime` |
| `com.system76.Cosmic.BaseApp//stable` + `llvm21` being installed | **Done, in the sandbox-HOME installation**: BaseApp commit `b3f1b274d540` (75.1 MB), `org.freedesktop.Sdk.Extension.llvm21//25.08` 21.1.8. ✅ | `flatpak list --show-details` |
| Original 2.0.4 "still installed as a user Flatpak" | **RESOLVED (lead, 2026-09-11): 2.0.4 is definitively NOT installed anywhere** — DECISIONS.md D3 addendum. Our exhaustive checks (evidence column) found no `com.goshapps.Notepad` in any visible installation, and the lead confirmed no invisible-to-agents HOME hosts one either. Only the source cache `/home/gosh/.cache/notepad-v2.0.4/` exists. **Consequence: live A/B runtime parity checks are OFF.** Parity mechanism instead: (a) 2.0.4's behavioral test contracts ported into Rust unit/integration tests driven through messages/state, (b) Phase-3 checklist verification of the 3.0.0 Flatpak against `docs/migration/ux.md`; building 2.0.4 from the source cache (`io.qt.PySide.BaseApp//6.10`, ~1–2 GB) is a fallback only for a reviewer-adjudicated parity dispute. Safety posture generalized (D3 addendum): never write to `/home/gosh`'s real user installation (it holds 13 of the user's apps); all test installs use throwaway isolated installations (§3.1, D13). | `flatpak list`, `ls /home/gosh/.local/share/flatpak/{app,runtime}`, `ls /var/lib/flatpak`, `find /home/gosh/.local/share/flatpak -iname "*notepad*"` (no hits); lead reconciliation 2026-09-11 |
| "Host is Ubuntu 24.04 GNOME-ish, no COSMIC DE" | Ubuntu 24.04.4 confirmed. **RESOLVED by lead: the live session IS COSMIC/wayland** (`XDG_CURRENT_DESKTOP=COSMIC`, `WAYLAND_DISPLAY=wayland-1` were accurate; `/usr/share/wayland-sessions/` showing only `weston.desktop` and the 30-proc PID namespace were sandbox-view artifacts). Implication per lead: **prove non-COSMIC operation via Xvfb** (and via weston-headless with a controlled `XDG_CURRENT_DESKTOP`), and never attach smoke tests to the live `wayland-1` session. | `/etc/os-release`; lead message 2026-09-10; `ls /usr/share/wayland-sessions` |

Consequences:

1. All flatpak build dependencies are now present in the active installation
   (baseline build proven, exit 0). Keep `--user --install-deps-from=flathub` in
   verify.sh/ci.sh anyway so a cold machine self-provisions (flags verified present
   in `flatpak-builder --help`; flathub remote configured: `flatpak remotes` → `flathub user`).
2. Smoke tests must never write to `/home/gosh`'s real user installation (D3-addendum
   posture — it holds 13 of the user's apps); the isolated-installation design of
   §3.1/D13 is mandatory on every machine (default path B is D3-safe even in a
   developer's real HOME).
3. Tooling confirmed present: `xvfb-run`, `Xvfb`, `weston 13.0.0` (headless backend
   available: `weston --help` lists `headless`), `dbus-run-session`,
   `desktop-file-validate`, `appstreamcli` **and** `appstream-util`, `vulkaninfo`, `jq`,
   `flatpak-builder 1.4.2`, `flatpak 1.14.6`, `rustc/cargo 1.98.1`. `just` is **NOT
   installed** → scripts must not call `just` (agreed with lead; justfile stays for
   developer convenience only).

---

## 1. Packaging requirements audit

Legend: verdict **OK** / **GAP** (must fix) / **RISK** (track) / **VERIFY-P2** (needs Phase 2 empirical check).

| # | Requirement | Current state (evidence) | Verdict | Fix task |
|---|---|---|---|---|
| 1 | App ID `com.goshapps.Notepad` consistent everywhere | `com.goshapps.Notepad.json:2`, `data/com.goshapps.Notepad.metainfo.xml:3`, `data/com.goshapps.Notepad.desktop:7` (Icon=), `src/single_instance.rs:21` (`APP_ID`), test `tests/packaging.rs:52-72` | OK | — |
| 2 | Binary/command `notepad` | manifest `command` L12; desktop `Exec=notepad %F` L6; metainfo `<binary>` L38; binary produced by spike build (`/tmp/vendor-spike/target/release/notepad`, 45.7 MB) | OK | — |
| 3 | Runtime/SDK pins: `org.freedesktop.Platform//25.08`, `org.freedesktop.Sdk//25.08` | manifest L3-5. Platform + Sdk 25.08 (freedesktop-sdk-25.08.16) installed ✅; **baseline flatpak-builder of the current manifest succeeded end-to-end** (lead, `/tmp/np-flatpak-baseline.log`, EXIT=0) | OK (working baseline) | P2-T4 becomes: re-run with vendored offline sources + measure |
| 4 | Base app `com.system76.Cosmic.BaseApp//stable` | manifest L6-7; installed, commit `b3f1b274d540`, 75.1 MB | OK / RISK (moving target — `stable` branch drifts with COSMIC releases; record commit per release in release checklist) | note in release docs |
| 5 | SDK extensions `rust-stable` + `llvm21` | manifest L8-11; llvm21 21.1.8 ✅; rust-stable 1.98.1 ✅ (auto-installed by baseline run); lld RUSTFLAGS path compiled + linked fine in-sandbox (baseline EXIT=0) | OK | — |
| 6 | RUSTFLAGS/lld link path | manifest L22 (`append-path` incl. `/usr/lib/sdk/llvm21/bin`), L25 (`-C link-arg=-fuse-ld=lld`) | OK — **proven**: lead's baseline build linked the 45 MB binary in-sandbox with these settings (EXIT=0) | — |
| 7 | **Vendored cargo sources incl. git deps; offline build** | manifest L27-29 has `build-args: --share=network`; L44 `cargo build --release` (no `--frozen --offline`); `Cargo.toml:26-36` libcosmic = git dep with **no rev/tag**; `Cargo.lock:2738-2740` pins `git+https://github.com/pop-os/libcosmic.git#d4d71fd53e5ed6bd3a430089114dffa2da3cd498`; `justfile:82-88` has vendor recipe but `just` not installed; `.gitignore` ignores `.cargo/`, `vendor/`, `vendor.tar` | **GAP** (violates user's hard requirement) | P2-T3 (manifest + `scripts/vendor.sh`), §2 for the full empirically-proven plan |
| 8 | Offline reproducibility | Cargo.lock committed ✅; vendored checksums per crate (`vendor/libcosmic/.cargo-checksum.json` exists — spike); vendor pins all 10 git deps at locked revs (§2.1) | OK once #7 fixed | §2 |
| 9 | finish-args minimality | manifest L13-20, see per-permission table below | OK w/ 1 VERIFY-P2 + 1 optional | below |
| 10 | Portals actually used | `src/app.rs:12` (`cosmic::dialog::file_chooser`), `src/app.rs:1333` (`file_chooser::open::Dialog`), `src/app.rs:822` (`open::that_detached` → xdg-open → portal OpenURI); libcosmic reads color-scheme from Settings portal (`vendor/libcosmic/src/core.rs` fields `portal_is_dark`, `portal_accent`, `portal_is_high_contrast`); **empirical**: spike app.log shows dbus activation of `org.freedesktop.portal.Desktop`, `…Documents`, `…PermissionStore` at startup | OK | — |
| 11 | dbus-config live theme sync | `Cargo.toml:31` feature `dbus-config`; proxy targets `com.system76.CosmicSettingsDaemon{,.Config}` (`vendor/cosmic-settings-daemon/src/lib.rs:25-27,68-69`); **no `--talk-name=com.system76.CosmicSettingsDaemon` in manifest**. Graceful fallback verified by code read: `vendor/libcosmic/src/core.rs` `watch_config`/`watch_state` fall back to file-based `config_subscription` when `settings_daemon` is `None`, and daemon connection failure leaves it `None`. File watching works because `--filesystem=xdg-config/cosmic:rw` is granted. | RISK (live accent/theme change sync on a real COSMIC desktop may lag or rely on inotify path) | P3: empirical test on COSMIC desktop; if broken, add `--talk-name=com.system76.CosmicSettingsDaemon` (harmless elsewhere) |
| 12 | Desktop file validity | `desktop-file-validate data/com.goshapps.Notepad.desktop` → **error**: `Categories=COSMIC;Utility;TextEditor;` (L9) contains unregistered value `COSMIC` (extensions must be `X-`-prefixed). Flathub-shipped COSMIC apps on this machine use `X-Cosmic` / `X-COSMIC` (grep over `/home/gosh/.local/share/flatpak/exports/share/applications/*.desktop`: `Categories=Utility;X-Cosmic;`, `Categories=System;Monitor;X-COSMIC;`) | **GAP** | P2-T2: `Categories=Utility;TextEditor;X-COSMIC;` (+ confirm with ux that COSMIC DE menu grouping still works; COSMIC recognizes X-COSMIC convention per shipped apps) |
| 13 | Metainfo/AppStream validity | `appstreamcli validate --no-net --explain data/com.goshapps.Notepad.metainfo.xml` → **exit 0**, "✔ Validation was successful: infos: 1, pedantic: 1". The info: `com.goshapps.Notepad:37: unknown-provides-item-type binaries`. Spec-correct form (and convention of installed Flathub COSMIC apps, e.g. YapCap/clippy-land metainfo: `<provides><id>com.system76.CosmicApplet</id><binary>…</binary></provides>`) puts `<binary>` **directly** under `<provides>`, no `<binaries>` wrapper. Ours: metainfo L35-40 wraps it. | GAP (minor) | P2-T2: unwrap `<binaries>`; update `tests/packaging.rs:88-93` expectation if needed (it only asserts the `<id>` lines, which stay) |
| 14 | Release history correctness | metainfo L42-110: 3.0.0 (2026-09-06), 2.0.4 (2026-09-01), 2.0.3, 2.0.2, 2.0.1, 2.0.0, 1.0.0 — all dated, all described, newest-first; matches `tests/packaging.rs:33-49` assertions incl. README | OK | — |
| 15 | Icons | Only `data/icons/hicolor/scalable/apps/com.goshapps.Notepad.svg`; installed by manifest L48 to `/app/share/icons/hicolor/scalable/apps/`. SVG-only is fine for COSMIC (libcosmic rasterizes SVG in-process — `resvg`/`usvg` are in the dependency set, see vendor listing) and for GTK/librsvg launchers; very old or minimal launchers without an SVG loader would show a fallback. | OK / RISK (minor) | P3: visual check of launcher icon under GNOME/KDE; optional PNG 128/256 render if reviewer insists |
| 16 | LICENSE/COPYRIGHT installation | manifest L49-50 → `/app/share/licenses/com.goshapps.Notepad/{LICENSE,COPYRIGHT}` (baseline build exports both). **Enforcement caveat (RV-6, reviewer-verified)**: `license_material_is_installed_with_the_application` (`tests/packaging.rs:24-30`) pins the **justfile** `install` recipe — host-only, never executed by flatpak-builder; the Flatpak's real install path is the manifest build-commands, and deleting L49-50 keeps all 34 tests green. GPL-text/attribution content assertions elsewhere in the suite still bind, but the Flatpak license-install wiring itself is **unpinned today** (v2's equivalent test pinned `meson.build` — its real build system) | OK (requirement met — licenses ARE installed) / **GAP (test coverage)** | P2-T3 (= PLAN T05) extends `tests/packaging.rs`: assert the manifest build-commands contain the LICENSE/COPYRIGHT install lines (~6 lines, GPL-compliance relevant); the justfile assertion stays for host installs |
| 17 | Version consistency | `Cargo.toml:3` `version = "3.0.0"`; metainfo L43 `3.0.0`; `README.md:7` "Current release: **3.0.0**"; enforced by `tests/packaging.rs:33-49`. Flatpak manifest carries no version field (normal); but no `branch` either — 2.0.4 manifest had `"branch": "stable"` (`/home/gosh/.cache/notepad-v2.0.4/com.goshapps.Notepad.json:8`), ours defaults to `master` on `build-export` | GAP (minor) | P2-T3: add `"branch": "stable"` (parity with 2.0.4 + Flathub convention) |
| 18 | cleanup section | manifest L31-38 (`/include`, `/lib/pkgconfig`, `/man`, `/share/doc`, `*.la`, `*.a`) — standard | OK | — |
| 19 | Sources layout | manifest L52-57 `type: dir, path: .` copies whole worktree (incl. `vendor/` + `.cargo/config.toml` when materialized by vendor script; `.gitignore`d so never in a clean clone) | OK (design in §2) | — |

### finish-args, permission by permission (manifest L13-20)

| Permission | Justification | Verdict |
|---|---|---|
| `--share=ipc` | SHM for X11 path (`fallback-x11`); parity with 2.0.4 (old manifest L11) | keep |
| `--socket=fallback-x11` | X11-only hosts; parity with 2.0.4 (L12); winit X11 path **empirically works** (§3.4 Xvfb spike: alive 8 s, clean SIGTERM) | keep |
| `--socket=wayland` | primary display path; parity (L13) | keep |
| `--device=dri` | GPU rendering for wgpu; parity (L14); harmless where absent (software fallback, §3.2) | keep |
| `--talk-name=org.freedesktop.portal.Desktop` | Portals are on flatpak's default session-bus allowlist (`org.freedesktop.portal.*` is auto-permitted by the sandbox bus proxy), so this line is **likely redundant** | **DEFERRED to Phase 3 (RV-2 rewire; D12 amendment 2026-09-11)**: the smoke test never opens a file dialog (launch → liveness → SIGTERM → panic-regex only), so it cannot prove portal function either way — the earlier "drop after smoke evidence" condition was unsatisfiable as written. Removal is now conditioned **solely** on the Phase-3 portal FileChooser check (§7: dbus-level `OpenFile` probe run **with the talk-name removed** + manual dialog round trip) passing; otherwise the talk-name stays **permanently** (minimality gain is one line; PLAN T26(a) carries this rewired condition) |
| `--filesystem=xdg-config/cosmic:rw` | cosmic-config persistence (metainfo release notes promise it: "Word wrap, font, status bar, and color scheme persist in Flatpak"); also enables the inotify config-watch fallback for dbus-config (row 11). 2.0.4 had no equivalent need (Qt/KSettings) | keep |
| (missing) `--talk-name=com.system76.CosmicSettingsDaemon` | only useful on a real COSMIC desktop for live theme sync; code-level fallback exists (row 11) | optional, decide after P3 test |
| (deliberately absent) filesystem access for opened files | parity with 2.0.4 (old manifest has **no** filesystem args, L10-15): file dialogs go through xdg-desktop-portal FileChooser → document-portal per-file grants; "Open With"/`%F` launches reach the sandbox via flatpak's file-forwarding rewrite of the desktop file at export/install time | OK — **CONFIRMED in D13 spike (2026-09-11)**: the *installed* export shows `Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=notepad --file-forwarding com.goshapps.Notepad @@ %F @@` (the repo/build-export file keeps plain `Exec=notepad %F`; the rewrite happens at install time). P3: real open-with + portal-save round trip |

---

## 2. Vendoring plan (empirically proven in `/tmp/vendor-spike`)

### 2.1 Spike results — `cargo vendor` handles the git deps

Copy of the repo (minus `.git`/`target`) in `/tmp/vendor-spike`, host cargo 1.98.1:

- `cargo vendor vendor` → **exit 0**, 636 crates vendored (`grep -c Vendoring vendor-output.txt` = 636), 4 s wall with warm `~/.cargo` cache (it downloads missing crates.io files; git deps come from `~/.cargo/git` checkouts or are fetched — network needed once on a truly cold machine).
- **All git dependencies captured at their locked revs**, including libcosmic itself:
  - `libcosmic v1.0.0 (https://github.com/pop-os/libcosmic.git#d4d71fd5)` → `vendor/libcosmic` (plus its workspace crates: `iced*`, `cosmic-config`, `cosmic-theme`, `build_helpers`, …)
  - `accesskit*` (`wash2/accesskit?tag=cosmic-0.14#f0599eed`), `winit`/`dpi` (`pop-os/winit?tag=cosmic-0.14#71ce08c0`), `softbuffer` (`pop-os/softbuffer?tag=cosmic-4.0#c2b2c19d`), `smithay-clipboard` (`#859b02c8`), `window_clipboard`/`clipboard_*`/`dnd`/`mime` (`pop-os/window_clipboard?tag=sctk-0.20#f68595ee`), `cosmic-protocols`/`cosmic-client-toolkit` (`?rev=32283d7`), `freedesktop-icons` (`#ab4c57b8`), `cosmic-settings-daemon` (`dbus-settings-bindings#eed01dd3`), `cryoglyph` (`iced-rs/cryoglyph?rev=e429a025…`), `atomicwrites` (`jackpot51/rust-atomicwrites#043ab485`).
  - `cargo vendor` emits per-git-source `[source."<url>"]` replacement stanzas (tail of its stdout, captured in `.cargo/config.toml` by the justfile recipe) — this is what makes `--offline` resolution work for git URLs.
- Offline resolution proof: with `.cargo/config.toml` written exactly as `justfile:82-88` does (`cargo vendor | head -n -1` + `directory = "vendor"`), `cargo metadata --locked --offline` → **exit 0 in 1.2 s**.
- **Full offline release build proof**: `cargo build --release --frozen --offline` from the spike dir (cold target dir) → **exit 0 in 1 m 09 s** (`Finished 'release' profile … in 1m 09s`, user time 20 m 23 s across cores). Binary runs (§3).
- Per-crate integrity: every vendored crate ships `.cargo-checksum.json` (checked `vendor/libcosmic/.cargo-checksum.json`); cargo verifies these when building from vendored sources. (VERIFY-P2: corrupt one vendored file, confirm build fails — one-liner in P2.)

### 2.2 Sizes → what may/may not be committed

Measured in the spike: `vendor/` = **973 MB**; `vendor.tar` (uncompressed, as `justfile vendor` produces) = **943 MB** (`943063040` bytes); `vendor.tar.gz` (gzip -1, 6 s) = **149 MB**.

GitHub rejects files > 100 MB without LFS → **committing `vendor.tar` is off the table** (LFS adds cost, quota risk, and still centralizes a near-1 GB binary blob per dependency bump). `.gitignore` already excludes `.cargo/`, `vendor/`, `vendor.tar` — keep it that way.

### 2.3 Recommended approach

**Vendor on demand; never commit; flatpak build is strictly offline.**

1. New `scripts/vendor.sh` (plain sh/cargo — **not** `just`, which is not installed):
   - if `vendor.tar` exists and is newer than `Cargo.lock` → `tar pxf vendor.tar` (recreates `vendor/`);
   - else → `cargo vendor vendor > /tmp/vendor-config.toml`, assemble `.cargo/config.toml` (same recipe as `justfile:82-88`, keeping the per-git-source stanzas), then `tar pcf vendor.tar vendor` as a **local cache artifact** (gitignored).
   - Idempotent, safe to call from verify.sh/ci.sh.
2. Manifest changes (P2-T3):
   - build command → `cargo build --release --frozen --offline` (frozen: lockfile immutable; offline: no network even by accident);
   - **delete** `build-args: ["--share=network"]`;
   - keep `sources: [{type: dir, path: .}]` — flatpak-builder then copies the materialized `vendor/` + `.cargo/config.toml` along with the tree (no archive-source/strip-components juggling, no second 1 GB tarball inside the build; the dir copy costs seconds and is measured in P2-T4).
   - keep `CARGO_HOME=/run/build/notepad/cargo` (harmless offline; isolates in-build cache) and RUSTFLAGS/lld.
3. **"Clean checkout" contract for verify.sh**: `git clone` → `scripts/verify.sh` must pass **unattended with exactly one network window**: `cargo vendor` fetch (~1-2 min warm cache / longer cold) + `flatpak-builder --install-deps-from=flathub` runtime/SDK pulls (first time only, ~2-3 GB in this sandbox installation; cached afterwards). Everything after the first run is fully offline-capable. This is the pragmatic reading of the user's vendoring requirement: *builds* never touch the network; *provisioning* the vendor set does, once, reproducibly pinned by `Cargo.lock`.
4. CI: cache `vendor.tar` (or `~/.cargo` + `vendor/`) keyed on `sha256(Cargo.lock)`; with the cache, CI runs vendor-extract and never refetches (§5).
5. **Pin hardening (reviewer-proofing)**: add `rev = "d4d71fd53e5ed6bd3a430089114dffa2da3cd498"` to the `[dependencies.libcosmic]` table in `Cargo.toml`. Today the commit is pinned only by `Cargo.lock:2740`; every build path uses `--locked`/`--frozen`, so day-to-day builds cannot drift — but a lockfile regeneration (`cargo update`, adding a dep on a cold cache) would silently float to libcosmic `master`, which is a live branch. An explicit `rev` makes the audited pin declarative, survives lockfile regen, and costs nothing. libcosmic has no meaningful release tags to pin instead (`version = "1.0.0"` permanently on master), so rev-pin is the right tool. (Cargo.toml edit = architect-owned file; packager proposes, P2-T3.)
   - Same reasoning already applies transitively: libcosmic's own git deps are rev/tag-pinned inside *its* Cargo.toml (visible in the vendor stanzas), and `Cargo.lock` pins the full graph.

Rejected alternatives:

- **Commit `vendor.tar`**: size (above). Rejected.
- **`type: archive` source for `vendor.tar` in the manifest**: works, but requires the tar to exist before build anyway, and unpacking a 943 MB tar ≈ copying the dir; extra moving part, no win. If P2-T4 measurement shows the dir-copy is slow (> 60 s), revisit.
- **flatpak-cargo-generator (`generated-sources.json`)**: the Flathub-standard hermetic approach (per-crate sha256 archive sources, git sources with commit pins, no vendor dir). Technically excellent, but it (a) isn't literally "vendored cargo sources" as the user asked, (b) adds a Python tool dependency and a ~600-crate generated file to maintain on every dep bump. Rejected per user requirement; noted here so the reviewer sees it was considered.
- **Keep `--share=network` + plain `cargo build`** (status quo): violates the hard requirement. Rejected.

---

## 3. Smoke test design (`scripts/smoke-test.sh`, Phase 2)

### 3.1 Pipeline (install mechanism per DECISIONS.md **D13** — spike-proven 2026-09-11)

```
scripts/vendor.sh (if vendor missing)
flatpak-builder --user --install-deps-from=flathub --force-clean --ccache "$BUILD_DIR" com.goshapps.Notepad.json
flatpak build-export "$BUILD_DIR" "$REPO" stable        # spike: exit 0, 72.2 MB repo

# --- install, path B (DEFAULT; isolated installation, D3-safe on ANY machine) ---
export XDG_DATA_HOME="$SMOKE_HOME"                      # persisted throwaway dir; bootstraps from scratch (proven)
flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak --user install -y "$REPO" com.goshapps.Notepad stable
    # first run pulls the runtime stack into $SMOKE_HOME (~1.2 GB, one-time; persisted thereafter)
# --- or path A (NOTEPAD_SMOKE_FAST=1; ONLY where the active HOME installation is known-throwaway) ---
#     flatpak install --user -y --no-deps "$REPO" com.goshapps.Notepad stable   # zero downloads (runtimes cached)

dbus-run-session sh -c '<start weston headless, DEFAULT shell; wait for socket; flatpak run com.goshapps.Notepad; liveness; SIGTERM>'
cleanup trap: kill app/weston/dbus pids; path A: flatpak uninstall --user -y com.goshapps.Notepad
              (spike-verified residue-free); path B: $SMOKE_HOME persists for reuse (rm -rf only when
              ephemeral); rm -rf $TMP_RT $REPO
```

`$SMOKE_HOME` default: `~/.cache/notepad-smoke-installation` (persist between runs; CI caches it — §5). `$TMP_RT` = fresh `mktemp -d`, `chmod 0700`. The build leg (`flatpak-builder … --user`) writes only to the active HOME's installation, which in the agent sandbox contains nothing of the user's.

**Mechanism history — the original design is DISPROVEN.** The first draft of this section isolated via `flatpak --installation="$TMP_INST" install -y --nondefault …`. Spike result (2026-09-11): `error: Could not find installation /tmp/np-tmp-inst` — flatpak 1.14.6 requires `--installation` to name a *registered* installation (`/etc/flatpak/installations.d`, i.e. root-provisioned); it does **not** bootstrap empty dirs (`--nondefault` is also not a valid `install` option). D13 supersedes it. **Dead ends — do not retry:** (1) `--installation=<tmpdir>`; (2) bare `flatpak install` without `--user` — activates `org.freedesktop.Flatpak.SystemHelper` and **times out after ~25 s** in unprivileged sandboxes: *always* pass `--user`; (3) `flatpak build` / `flatpak-builder --run` on the build dir as smoke runner — proven to **not apply finish-args** (build-time filesystem access is inherited; `ls /home/gosh` succeeded inside), so it cannot test the shipped sandbox configuration (debug-only; this is D13 path C, rejected).

**Path B (default) — `XDG_DATA_HOME` throwaway user installation.** Proven: `XDG_DATA_HOME=/tmp/np-xdg flatpak --user list` bootstraps a from-scratch installation (creates `$XDG_DATA_HOME/flatpak/repo`). Cost sizing: the fresh installation is empty, so the first install pulls the runtime stack into it — **~1.2 GB one-time** (Platform 25.08 ≈ 660 MB + GL.default ≈ 457 MB + Cosmic BaseApp ≈ 75 MB; flathub remote added inside it first, as in the pipeline above). Persisting `$SMOKE_HOME` amortizes this to zero on later runs. D3-safe on ANY machine including a developer's real HOME: nothing ever touches the real installation.

**Path A (`NOTEPAD_SMOKE_FAST=1`) — active-HOME `--user` install + trap-uninstall.** **FULLY PROVEN end-to-end through the real flatpak sandbox (2026-09-11 spike; basis of D13):** `flatpak build-export` of the lead's baseline build dir → exit 0, 72.2 MB repo; `flatpak install --user -y --no-deps /tmp/np-smoke-repo com.goshapps.Notepad stable` → installed ("NotePad 3.0.0 stable"); weston headless (default shell) + `dbus-run-session` + `flatpak run com.goshapps.Notepad` → **ALIVE after 10 s → clean SIGTERM exit rc=143 → 0 panic-regex matches** (the §3.3 protocol verbatim, through the sandbox); `flatpak uninstall --user -y` → installation verified clean, zero residue. Zero extra downloads (runtimes already cached). Constraint: only where the active installation is known-throwaway (agent-sandbox HOME, ephemeral CI runner HOME) — on a real HOME it would transiently pollute the user's installation and could collide with a real `com.goshapps.Notepad` install.

**Bonus verifications from the same spike (two VERIFY-P2 items retired):**

- **finish-args enforcement under `flatpak run` CONFIRMED**: inside the sandbox, `/home/gosh` exists only as the fabricated mount skeleton (single entry leading to the `xdg-config/cosmic` bind); `~/.config/cosmic` is mounted rw (app config visible); `/run/user/1000` is exposed (wayland + single-instance socket work); `/app/bin` = `notepad` + `just` (BaseApp ships `just` — benign, §0).
- **`@@ %F @@` file-forwarding CONFIRMED** in the installed export (verbatim `Exec` line in the §1 finish-args table, last row): Open-With works via document-portal with no filesystem finish-arg.

**Kept spike artifacts for Phase 2 reuse:** `/tmp/np-smoke-repo` (72 MB build-export of the baseline — P2-T5 can rehearse against it without a rebuild) and `/tmp/vendor-spike` (`vendor/` 973 MB — P2-T3 reuse; regenerable in ~4 s from the warm cargo cache regardless).

### 3.2 Headless display choice: **weston headless (primary), Xvfb (secondary)** — both empirically proven

Lead guidance folded in: the live session is COSMIC/wayland (`wayland-1`), so (a) the
smoke test must **never attach to the live session** — dedicated `XDG_RUNTIME_DIR`
and unique socket name (§3.2 detail 3) guarantee this; and (b) the **Xvfb leg is the
designated proof of non-COSMIC operation** (it carries no COSMIC env at all; we
additionally scrub `XDG_CURRENT_DESKTOP`/`XDG_SESSION_DESKTOP` and set
`WAYLAND_DISPLAY` only for the weston leg). The weston leg proves the shipping
Wayland path works with a non-COSMIC compositor; both legs run in every smoke pass.

Spike evidence (host-built binary from the offline vendored build, wrapped in `dbus-run-session`, 8 s alive-interval, `kill -0` liveness, SIGTERM):

- **weston 13 `--backend=headless`, default desktop shell**: `ALIVE after 8s`, `clean SIGTERM exit` (exit 143 = 128+SIGTERM; app does not trap TERM — that is acceptable and expected for an iced app; "clean" = terminates promptly on TERM without needing SIGKILL and without crash codes).
- **Xvfb via `xvfb-run -a`** (X11 path, exercises the `fallback-x11`+winit-X11 code path): `X11: ALIVE after 8s`, `X11: clean SIGTERM exit`.
- GPU/rendering: app rendered under weston's no-op renderer while wgpu used host Vulkan; **inside the flatpak runtime, lavapipe is present** — verified: `flatpak run --command=sh org.freedesktop.Platform//25.08` finds `/usr/lib/x86_64-linux-gnu/GL/vulkan/icd.d/lvp_icd.x86_64.json` and `libvulkan_lvp.so`, and `/usr/share/vulkan/icd.d/lvp_icd.x86_64.json`. Host also has llvmpipe (`vulkaninfo --summary` → `deviceName = llvmpipe (LLVM 20.1.2, 256 bits)`) as last resort; iced additionally has the tiny-skia CPU fallback. No GPU is required for the smoke test.

**Why weston headless as primary**: the app is Wayland-native (winit); smoke-testing on Wayland tests the shipping path, and weston exercises the same protocol family COSMIC uses. Xvfb stays as a scripted secondary leg (cheap, ~10 s) because the manifest still promises `fallback-x11`.

**Critical weston details learned empirically (must be in the script):**

1. **Do NOT use `--shell=fullscreen-shell.so`**: fullscreen-shell does not expose the `xdg_shell` global; winit hard-requires it and the app **panics at startup**: `Create event loop: Os(OsError { … winit-wayland/src/state.rs, error: NotPresent })` at `vendor/winit-wayland/src/state.rs:182` (`XdgShell::bind`). With the default desktop shell the same binary runs fine. (First two spike runs died this way; third run with default shell passed.)
2. **Wait for the socket properly**: `[ -S "$XDG_RUNTIME_DIR/$SOCKET" ]` poll loop + 1 s settle, not a fixed sleep — the first spike raced weston startup (`NotPresent` vs later `NoCompositor` errors distinguish "socket absent" from "compositor gone").
3. Dedicated `XDG_RUNTIME_DIR=$(mktemp -d)`, `chmod 0700`, unique `--socket=notepad-smoke-0`, `WAYLAND_DISPLAY=notepad-smoke-0` for the app — guarantees no interference with the live session (`wayland-1`) and no stale-socket single-instance confusion (see 3.5).
4. Everything (weston + flatpak run) inside **one `dbus-run-session`**: spike showed the app activates `org.freedesktop.portal.Desktop` at startup (color-scheme probe) and the host's xdg-desktop-portal(-gtk) chain starts fine inside a private session bus. **Largely RESOLVED by the D13 spike (2026-09-11)**: the full `flatpak run` pipeline (weston + `dbus-run-session` + real sandbox) passed the complete §3.3 protocol — ALIVE 10 s, clean SIGTERM rc=143, zero panic matches — so flatpak's bus proxy does not break startup portal probing. Remaining P2-T5 scope: classify the in-sandbox stderr noise into the §3.3 allowlist. Knobs if portal activation ever misbehaves: `--env=NO_AT_BRIDGE=1`, disabling the a11y probe; the app tolerating a *missing* portal is itself a P3 test case.

### 3.3 Liveness + termination protocol (script spec)

```sh
ALIVE_SECS=10          # fixed alive interval
TERM_GRACE=5           # SIGTERM → wait → SIGKILL
flatpak run com.goshapps.Notepad >"$LOG" 2>&1 &   # (inside dbus-run-session + weston env)
APP=$!
sleep "$ALIVE_SECS"
kill -0 $APP || fail "app died within ${ALIVE_SECS}s (exit=$(wait $APP; echo $?))"
kill -TERM $APP
for i in $(seq $TERM_GRACE); do kill -0 $APP || break; sleep 1; done
kill -0 $APP && { kill -KILL $APP; fail "app ignored SIGTERM for ${TERM_GRACE}s"; }
wait $APP; rc=$?
[ "$rc" = 143 ] || [ "$rc" = 0 ] || fail "unexpected exit code $rc"
```

Failure criteria (what counts as failure — cosmic apps log benign warnings, so **exit status + panic patterns decide, not raw stderr noise**):

- app exited on its own during the alive interval (any reason) → FAIL;
- exit code not in {0, 143} → FAIL (101 = Rust panic, 134 = SIGABRT, 139 = SIGSEGV, 1 = generic error);
- app's own stderr matches `panicked at|thread '.*' panicked|Fatal|wgpu error|Device lost|CreateEventLoop|OsError` → FAIL (the spike's genuine failure mode produced exactly `panicked at … Create event loop: Os(…)` — this regex set catches it);
- ignored SIGTERM → FAIL;
- everything else in stderr (dbus activation lines, portal fallback warnings like `Choosing gtk.portal … as a last-resort fallback`, `Gdk-CRITICAL` from xdg-desktop-portal-gtk, `Ignoring invalid max threads value …`, and this host's nix-gvfs `undefined symbol` noise — all observed in spike logs and all benign) → **WARN, not FAIL**. The allowlist lives in the script as a grep -vE pattern list, documented next to it. Weston/dbus logs go to separate files, only the app's own stream is scanned.

### 3.4 Cleanup & process hygiene

`trap 'kill …; rm -rf …' EXIT` covering: app pid, weston pid, dbus-daemon pid (killing the `dbus-run-session` wrapper suffices), `$TMP_RT`, `$REPO`, and the D13 install leg (path A: `flatpak uninstall --user -y` — spike-verified residue-free; path B: `$SMOKE_HOME` persists for reuse, `rm -rf` only when ephemeral). Final assertions: `pgrep -f "$SOCKET"` empty; after path-A runs, `flatpak list --user` shows no `com.goshapps.Notepad`. **Process-kill footgun learned empirically:** `pkill -f "weston --backend=headless --socket=np-smoke-0"` **killed the cleanup shell itself** (the pattern matched the invoking `bash -c` command line; exit 144) — the script must kill recorded PIDs or use `pkill -x weston`, never `pkill -f` with a pattern that appears in its own command line. Spike compliance: `pgrep -a weston || echo "weston cleaned up"` → `weston cleaned up`; `pgrep -a notepad` → none.

### 3.5 Single-instance interaction (read `src/main.rs:39-41`, `src/single_instance.rs`)

A second launch forwards its args over `$XDG_RUNTIME_DIR/com.goshapps.Notepad.sock` and exits **0** immediately. Consequences: (a) smoke test must use a fresh XDG_RUNTIME_DIR so no stale/host socket exists (a forwarded launch would look like "started and exited 0" — instant-death false negative *and* a false-positive shape); (b) optional smoke step S2 (P3): launch instance A, wait alive, launch instance B with a file arg, assert B exits 0 quickly and A is still alive — cheap end-to-end proof of the 2.0.4 "second launch focuses existing window" parity feature.

### 3.6 Runtime expectations

weston leg ≈ 20 s wall; Xvfb leg ≈ 15 s; build-export/install ≈ 10 s; flatpak-builder build: host-native offline build was **1 m 09 s** (16-thread machine, warm page cache) — inside the sandbox with ccache cold expect 3-10 min first time, ~2 min warm (`--ccache` + persisted ccache dir; the lead's baseline network build already warmed the flatpak dep cache and the build-dir cache at `/tmp/np-flatpak-baseline`). verify.sh total on THIS host: first run ≈ 10-20 min (SDK downloads no longer apply — installed), steady state ≈ 5-10 min; on a cold machine add the one-time ~2-3 GB Flathub provisioning (30-60 min worst case).

---

## 4. `scripts/verify.sh` design

Single entry point, run before closing any task. Plain bash, `set -euo pipefail`, no `just`. Fail-fast with per-step banner and timing; steps addressable for debugging via `NOTEPAD_VERIFY_ONLY=<step,…>` / `NOTEPAD_VERIFY_SKIP=<step,…>` env (CI sets neither).

| # | Step | Command | Notes |
|---|---|---|---|
| 1 | fmt | `cargo fmt --check` | **ADOPTED (D6 addendum, lead 2026-09-11)** — tree already rustfmt-clean (lead-measured), so the gate costs nothing and keeps review diffs clean; rustfmt component pinned by `rust-toolchain.toml` |
| 2 | build | `cargo build --locked` | debug profile; baseline ✅ per lead |
| 3 | clippy | `cargo clippy --all-targets --locked -- -D warnings` | baseline ❌ known `src/config.rs` double_must_use → architect fixes first (P2-T1); verify.sh lands **with** `-D warnings` enforced from day one, per requirement |
| 4 | test | `cargo test --locked` | 28 unit + 6 packaging tests today; suites grow (§6) |
| 5 | desktop-file | `desktop-file-validate data/com.goshapps.Notepad.desktop` | currently FAILS (audit row 12) → P2-T2 fixes before verify.sh adoption |
| 6 | appstream | `appstreamcli validate --no-net --explain data/com.goshapps.Notepad.metainfo.xml` | currently passes (exit 0, 1 info); after P2-T2 the `binaries` info disappears; decide then whether to add `--pedantic` (recommend: no — pedantic flags stylistic trivia) |
| 7 | manifest sanity | `jq -e` assertions on `com.goshapps.Notepad.json`: no `--share=network` in build-args; build command contains `--frozen --offline`; finish-args ⊆ allowlist; `branch == "stable"`; app-id/command | cheap guard rails; overlaps with extended `tests/packaging.rs` (§6) — keep both (jq = pre-flight before expensive steps, cargo test = durable) |
| 8 | vendor | `scripts/vendor.sh` | no-op when cache is fresh |
| 9 | flatpak build | `flatpak-builder --user --install-deps-from=flathub --force-clean --ccache .flatpak-builder/build com.goshapps.Notepad.json` | `--force-clean` per requirement; build dir under `.flatpak-builder/` (already gitignored) |
| 10 | smoke | `scripts/smoke-test.sh` | reuses step 9's build dir (skips rebuild if present and manifest unchanged — or simply re-runs the export/install/run legs, which are cheap) |

Exit codes: 0 = all pass; 1 = a check failed (step name printed); 2 = environment precondition missing (e.g. flatpak-builder absent) with an actionable message. Output format: `[ 3/10] clippy … PASS (42s)` / `FAIL` + last ~20 log lines and full log path (`/tmp/notepad-verify-<ts>/`). "Clean checkout" contract = §2.3 item 3.

## 5. `scripts/ci.sh` + GitHub Actions spec

`scripts/ci.sh` = `verify.sh` with CI dress code: `export CI=1`; per-step `timeout` wrappers (build 20 min, flatpak 45 min, smoke 5 min); tees full logs to `$ARTIFACT_DIR/`; on success produces a shippable artifact: `flatpak build-bundle repo notepad-3.0.0.flatpak com.goshapps.Notepad stable` + its sha256; never prompts, never assumes a TTY; exits with verify.sh semantics.

Workflow file spec (`.github/workflows/verify.yml`, P2-T7 — spec only, this machine runs `ci.sh` manually meanwhile):

- `runs-on: ubuntu-24.04` (ships flatpak + flatpak-builder; **VERIFY-P2/P7**: runner has no GPU → lavapipe path, which §3.2 shows the runtime supports; weston install via `apt-get install -y weston xvfb dbus-x11 desktop-file-utils appstream`).
- Steps: checkout → `flatpak remote-add --user flathub …` → install `org.freedesktop.Sdk//25.08`, `…rust-stable//25.08`, `…llvm21//25.08`, `com.system76.Cosmic.BaseApp//stable` (explicit preinstall so the flathub remote and its EULA acceptance are handled once, non-interactively: `--assumeyes`) → `actions/cache` for `~/.cargo` + `vendor.tar` keyed `hashFiles('Cargo.lock')`, a second cache for the flatpak ccache dir keyed on the same, and a third for the path-B smoke installation `~/.cache/notepad-smoke-installation` keyed on the runtime versions (avoids the ~1.2 GB one-time pull on fresh runners; alternatively ephemeral runners set `NOTEPAD_SMOKE_FAST=1` — runner HOME is known-throwaway — and skip this cache) → `./scripts/ci.sh` → upload `notepad-*.flatpak` + logs as artifacts. `timeout-minutes: 60`. Note in the file: first-ever run on cold caches ≈ 45-55 min, warm ≈ 15 min.
- Known runner caveat: nested `dbus-run-session` + weston headless works on GH runners (no seatd/logind needed for headless backend); if the runner's kernel denies something, Xvfb leg is the fallback — smoke script tries wayland first, X11 second, FAILs only if both die.

## 6. Test-suite ownership map

| Suite | Owner | Contents today | Planned |
|---|---|---|---|
| `src/**` unit tests (28) | architect | editor commands/logic (`commands.rs` etc.) | architect extends per rewrite plan |
| `tests/packaging.rs` (6) | packager | license text/attribution, install wiring (**justfile only — RV-6 gap: the manifest's LICENSE/COPYRIGHT build-command lines are unpinned; see audit row 16**), version consistency, BaseApp manifest asserts, identity, metainfo ids. **Constraint (lead): the suite pins exact strings** — versions `3.0.0`/`2.0.x`, `--filesystem=xdg-config/cosmic:rw` in finish-args, `"leading check column"` in both README and metainfo, runtime/base/extension values, attribution text. Any manifest/metadata edit must keep these passing **or update the test in the same change** (P2-T2/T3 do exactly that where intended). | P2-T2/T3 extend: manifest has **no** `--share=network`; build command contains `--frozen --offline`; `branch == "stable"`; finish-args exactly the allowlist (§1); `Cargo.toml` libcosmic `rev` matches `Cargo.lock` pin; desktop Categories is validator-clean; metainfo `<provides><binary>` direct-child shape; version 3.0.0 consistency (existing); **P2-T3 (= PLAN T05) per RV-6: manifest build-commands contain the LICENSE/COPYRIGHT install lines (pins the Flatpak's real license-install path; ~6 lines; justfile assertion stays for host installs)** |
| GUI/parity behavior tests | ux | — | ux-owned (menu structure, labels, keybinds vs 2.0.4 mapping from `plans/libcosmic-rewrite.md`); packager runs them via `cargo test` in verify.sh |
| `scripts/smoke-test.sh` | packager | — | P2-T5: §3 spec (wayland + X11 legs, liveness, termination, cleanup, optional single-instance step S2) |
| `scripts/verify.sh`, `scripts/ci.sh`, `scripts/vendor.sh` | packager | — | P2-T3/T6 |

Aggregation: `cargo test --locked` (step 4) picks up **every** Rust suite automatically as ux/architect add files under `tests/` or `#[cfg(test)]` modules — verify.sh needs no edits when suites are added. Non-cargo checks are enumerated steps in verify.sh only.

## 7. "Works outside COSMIC desktop" plan

Environment reality (§0): we cannot even see the host DE from these shells, so **every** verification runs under self-spawned sessions — which is exactly the point: the app must behave on whatever Linux desktop.

| Behavior | Mechanism (evidence) | Phase 3 verification |
|---|---|---|
| Theme when COSMIC config absent | `src/config.rs:44-49`: `System` → `cosmic::theme::system_preference()`; libcosmic falls back to portal color-scheme (`portal_is_dark` via org.freedesktop.portal.Settings — `vendor/libcosmic/src/core.rs`) then to light default; `pin_independent` keeps explicit Light/Dark immune to desktop overrides | launch under weston with `XDG_CURRENT_DESKTOP=GNOME` / `=KDE` / unset inside `dbus-run-session`; assert no panic + window renders (screenshot via `weston-screenshooter` or grim-free: `flatpak run --command=sh` + `weston-screenshooter` in the RT dir); assert `~/.config/cosmic/com.goshapps.Notepad` defaults created |
| dbus-config absent | `settings_daemon: None` → file-watch `config_subscription` fallback (`vendor/libcosmic/src/core.rs:392-405`) — startup already proven OK on this host where no settings daemon runs (spike §3.2) | covered by every smoke run (this machine has no cosmic-settings-daemon); assert config edits still hot-reload: flip `word_wrap` in the config file mid-run in an extended smoke step |
| File dialogs on GNOME/KDE | portal FileChooser via ashpd inside libcosmic; spike showed the full portal chain activating with **xdg-desktop-portal-gtk** (GNOME-ish path) as last-resort fallback — i.e. it degrades to whatever portal impl the desktop ships | manual checklist (cannot headlessly click a portal dialog): Open + Save As round trip under GNOME Wayland and KDE Wayland sessions; automated proxy: dbus-level check that `org.freedesktop.portal.Desktop` FileChooser is callable (`gdbus call … org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.FileChooser.OpenFile` returns a handle, then close). **This check doubles as the RV-2/D12 evidence gate**: run the `OpenFile` probe once **with `--talk-name=org.freedesktop.portal.Desktop` removed** — pass ⇒ the talk-name may be dropped (PLAN T26(a)); fail ⇒ it stays permanently |
| Open-With / `%F` from host file managers | flatpak rewrites `Exec` with `--file-forwarding … @@ %F @@` at install time; document-portal FUSE grants per-file access — **CONFIRMED (D13 spike)**: installed desktop file shows `Exec=/usr/bin/flatpak run … --file-forwarding com.goshapps.Notepad @@ %F @@` | ~~VERIFY-P2~~ retired 2026-09-11; P3: real "Open With" from GNOME Files + Kate/Dolphin on KDE |
| Icon/theme lookup on non-COSMIC | hicolor SVG installed (§1 row 15); app icon rendered by libcosmic via resvg regardless of DE; launcher icon via desktop-file + hicolor inheritance | P3 visual check under GNOME/KDE; `gtk-update-icon-cache` not needed in sandbox (flatpak export runs it) |
| Single instance across launches | unix socket in XDG_RUNTIME_DIR — inside the flatpak sandbox this is the forwarded host runtime dir, shared between instances of the same app | smoke step S2 (§3.5) |
| X11-only hosts | winit X11 path proven under Xvfb (§3.2) | smoke X11 leg runs every verify |

## 8. Risks (ordered by threat to the plan)

1. **Manifest violates the vendoring requirement today** (`--share=network`, non-frozen build): user's hard requirement; fix is proven trivial (§2) but touches architect-owned files → coordinate P2-T3 early.
2. **Clippy `-D warnings` red at baseline** (`src/config.rs` double_must_use, lead-measured): blocks verify.sh adoption; architect P2-T1. (`cargo fmt --check` resolved: tree is rustfmt-clean, lead-measured; fmt gate adopted as step 1 per D6 addendum.)
3. **desktop-file-validate red** (`Categories=COSMIC`): blocks verify.sh step 5; trivial fix, but needs ux sign-off that COSMIC DE grouping/menu behavior is preserved with `X-COSMIC` (installed Flathub COSMIC apps ship `X-Cosmic`/`X-COSMIC`, so the convention exists in the wild).
4. ~~Sdk/rust-stable absent~~ **RESOLVED**: lead's baseline build auto-installed Sdk 25.08 + rust-stable 1.98.1 from Flathub; all deps now cached on this host. Residual: a cold machine (fresh CI runner) still pays the ~2-3 GB download once — handled by `--install-deps-from=flathub` + workflow preinstall (§5).
5. ~~2.0.4 parity reference not launchable from agent shells~~ **RESOLVED (lead, 2026-09-11 — D3 addendum)**: 2.0.4 is definitively NOT installed anywhere; **live A/B runtime parity is OFF by decision**. Parity mechanism: (a) 2.0.4 behavioral contracts ported into Rust tests (§6 ownership), (b) Phase-3 `docs/migration/ux.md` checklist against the 3.0.0 Flatpak. Residual: a reviewer-adjudicated parity dispute the ported contracts cannot settle would escalate to building 2.0.4 from `/home/gosh/.cache/notepad-v2.0.4/` (`io.qt.PySide.BaseApp//6.10`, ~1–2 GB). DE ambiguity resolved earlier: live session is COSMIC/wayland.
6. **`com.system76.Cosmic.BaseApp//stable` drift**: base app updates can change runtime libs under us without any repo change. Cannot pin (branch-distributed). Mitigation: record the BaseApp commit in release notes per release (today: `b3f1b274d540`); smoke test in CI catches breakage on bumps.
7. **libcosmic master drift on lockfile regeneration**: mitigated by proposed `rev` pin (§2.3.5) + `--locked`/`--frozen` everywhere + vendored checksums.
8. **Vendor size** (973 MB dir): slows flatpak-builder dir-copy and CI caches; measured cost acceptable (spike tar took 1.4 s to page cache; dir copy measured in P2-T4). If it hurts, `cargo vendor` per-platform trimming is *not* supported — would need the archive-source variant (§2.3 rejected list) — revisit with data.
9. **Benign-stderr classification** (§3.3): too-strict grep = flaky FAILs (this host's nix-gvfs noise proves it); too-loose = missed crashes. Mitigated by exit-code-first criteria + narrow panic regex + reviewed allowlist.
10. ~~Isolated `--installation` bootstrap unproven~~ **RESOLVED → DISPROVEN → replaced (D13)**: `flatpak --installation=<tmpdir>` does NOT bootstrap an empty dir (spike: `Could not find installation`); replacements proven — path A end-to-end through the real sandbox (ALIVE 10 s, rc=143, 0 panics, residue-free uninstall), path B bootstrap + cost sizing (~1.2 GB one-time, persisted). **No unproven install mechanism remains for P2-T5.**
11. **Portal availability inside sandbox under a bare `dbus-run-session`** (§3.2.4 — *narrowed* by the D13 spike: the full `flatpak run` pipeline passed liveness + clean-exit + zero-panic criteria, so startup portal probing works through flatpak's bus proxy): remaining scope is stderr-allowlist classification of in-sandbox portal/dbus noise (P2-T5); app *tolerates* absent portal by design (fallbacks in §7) — P3 asserts full function on real desktops.
12. ~~llvm21 `lld` inside build sandbox~~ **RESOLVED**: baseline build linked successfully with the manifest's `append-path` + RUSTFLAGS (EXIT=0, `/tmp/np-flatpak-baseline.log`).
13. **45.7 MB release binary** — normal for libcosmic static-ish linking; no action; noted for bundle size expectations (~20 MB flatpak app dir delta after BaseApp).

## 9. Proposed Phase 2 tasks (ordered; each leaves the tree buildable & verify-able)

| ID | Owner | Task | Done when |
|---|---|---|---|
| P2-T1 | architect | Fix `src/config.rs` double_must_use clippy error | `cargo clippy --all-targets --locked -- -D warnings` exits 0 |
| P2-T2 | packager (+ux sign-off) | `data/com.goshapps.Notepad.desktop` Categories → `Utility;TextEditor;X-COSMIC;`; metainfo `<provides>` unwrap `<binaries>`→`<binary>`; adjust `tests/packaging.rs` if assertions touch either — **pinned-string rule**: version pins, `--filesystem=xdg-config/cosmic:rw`, and `"leading check column"` (README+metainfo) must keep passing untouched; any intentionally changed pinned string is updated in the test in the same commit | `desktop-file-validate` exit 0; `appstreamcli validate --no-net` exit 0 with 0 infos; `cargo test --locked` green |
| P2-T3 | packager (+architect for Cargo.toml) | Vendoring switch: add `rev = "d4d71fd5…"` to Cargo.toml libcosmic dep; manifest: `--frozen --offline` build command, remove `--share=network`, add `"branch": "stable"`; write `scripts/vendor.sh`; extend `tests/packaging.rs` per §6 | `cargo build --locked` + tests green; `scripts/vendor.sh` produces vendor/ + .cargo/config.toml + vendor.tar from clean state; `cargo build --release --frozen --offline` green |
| P2-T4 | packager | Vendored offline rebuild: after T3, in-repo `flatpak-builder --user --install-deps-from=flathub --force-clean --ccache` with `--frozen --offline` and **no** `--share=network` (baseline network build already proven by lead, EXIT=0 — `/tmp/np-flatpak-baseline.log`); measure times (vendor dir-copy, build, ccache warm/cold). (The `@@ %F @@` export-rewrite check and the §3.1 install-mechanism question were retired by the D13 spike — no re-check needed.) | flatpak-builder exit 0 fully offline; timings + findings appended to this doc |
| P2-T5 | packager | `scripts/smoke-test.sh` per §3 + **D13**: path B default (`XDG_DATA_HOME=$SMOKE_HOME` isolated installation, persisted at `~/.cache/notepad-smoke-installation`), `NOTEPAD_SMOKE_FAST=1` → path A; wayland leg + X11 leg, failure criteria, cleanup trap (PID-based kills — `pkill -f` self-match footgun, §3.4); remaining VERIFY-P2 items: §3.2.4 in-sandbox stderr-allowlist classification, checksum-tamper one-liner (§2.1). Rehearsal shortcut: `/tmp/np-smoke-repo` export already exists (§3.1) | smoke passes against P2-T4 build twice in a row; no leftover processes (`pgrep` assert); path-A runs leave the installation residue-free; tampered-vendor build correctly fails |
| P2-T6 | packager | `scripts/verify.sh` per §4 (all 10 steps, env overrides, logging); dry run on current tree; then full run from a **fresh clone in /tmp** | fresh-clone run exits 0 unattended (single network window as per §2.3.3) |
| P2-T7 | packager | `scripts/ci.sh` + `.github/workflows/verify.yml` per §5 | ci.sh green locally; workflow file validated (`actionlint` if available, else careful review) — actual GH run when pushed |
| P2-T8 | team → **lead (residue = PLAN T26)** | DECISIONS.md entries: (a) portal talk-name removal — **rewired per RV-2 (D12 amendment 2026-09-11): only after the Phase-3 portal FileChooser check (§7) passes with the talk-name removed**; the smoke test cannot supply this evidence (it never opens a file dialog); else the talk-name stays permanently; (b) settings-daemon talk-name add-or-not (after the P3 real-COSMIC test); (c)–(e) already recorded: `X-COSMIC` convention = D12, fmt gate = D6 addendum, vendor-on-demand = D9 | lead records decisions |

Phase 3 (preview, owned jointly): §7 verification matrix on real GNOME/KDE sessions, manual portal-dialog checklist, **parity verification via the D3-addendum mechanism** — 2.0.4 behavioral contracts ported into Rust unit/integration tests (driven through messages/state) + checklist verification of the 3.0.0 Flatpak against `docs/migration/ux.md` (live A/B runtime comparison is OFF: 2.0.4 is definitively not installed anywhere; source-cache rebuild is the escalation path only for a reviewer-adjudicated parity dispute — risk 5), icon/theme visual checks, config hot-reload smoke extension.

---

## Appendix A — raw evidence snippets (recorded 2026-09-10/11)

```text
Lead baseline build of CURRENT manifest (network mode), /tmp/np-flatpak-baseline.log:
  head: "Dependency Sdk: org.freedesktop.Sdk 25.08 / Installing org.freedesktop.Sdk/x86_64/25.08
         from flathub / Installing runtime/org.freedesktop.Sdk/x86_64/25.08"
  tail: "Exporting share/metainfo/com.goshapps.Notepad.metainfo.xml / Committing stage finish
         to cache / Pruning cache / EXIT=0"
  ls /tmp/np-flatpak-baseline/files/bin/ → just  notepad   (just comes from Cosmic BaseApp
         prepopulating /app — benign; scripts still avoid `just`, not installed on host)
  post-check: flatpak list --runtime → Sdk 25.08 (freedesktop-sdk-25.08.16), rust-stable
         1.98.1, llvm21 21.1.8 all present in active user installation

$ cargo vendor (spike, warm cache)            → EXIT=0, 636 crates, 4.0s wall
$ du -sh vendor                               → 973M
$ tar pcf vendor.tar vendor                   → 943063040 bytes (1.4s)
$ gzip -1 vendor.tar                          → 149447294 bytes (5.9s)
$ cargo metadata --locked --offline (vendored)→ EXIT=0, 1.2s
$ cargo build --release --frozen --offline    → EXIT=0, "Finished `release` profile … in 1m 09s"
                                                 (user 20m23s; binary 45740176 bytes)

$ desktop-file-validate data/com.goshapps.Notepad.desktop
  error: value "COSMIC;Utility;TextEditor;" for key "Categories" … contains an
  unregistered value "COSMIC"; values extending the format should start with "X-"   → exit 1

$ appstreamcli validate --no-net --explain data/com.goshapps.Notepad.metainfo.xml
  I: com.goshapps.Notepad:37: unknown-provides-item-type binaries
  ✔ Validation was successful: infos: 1, pedantic: 1                                  → exit 0

weston headless + fullscreen-shell  → app PANIC: "Create event loop: Os(OsError { …
                                       winit-wayland/src/state.rs, error: NotPresent })"
                                       (state.rs:182 = XdgShell::bind — no xdg_shell global)
weston headless + default desktop shell + dbus-run-session, host-built vendored binary:
  ALIVE after 8s → SIGTERM → "clean SIGTERM exit", final exit=143
  app.log: dbus activation of org.freedesktop.portal.Desktop / .Documents /
           impl.portal.PermissionStore; xdg-desktop-portal-gtk last-resort fallback
           warnings (benign); host nix-gvfs "undefined symbol" noise (benign, host-specific)
xvfb-run -a + dbus-run-session, same binary:
  X11: ALIVE after 8s; X11: clean SIGTERM exit

$ flatpak run --command=sh org.freedesktop.Platform//25.08 …
  /usr/lib/x86_64-linux-gnu/GL/vulkan/icd.d/lvp_icd.x86_64.json
  /usr/lib/x86_64-linux-gnu/GL/default/lib/libvulkan_lvp.so   (lavapipe present in runtime)
$ vulkaninfo --summary (host)  → Intel(R) Graphics (ARL) + llvmpipe (LLVM 20.1.2)
$ weston --help                → backend "headless" available; weston 13.0.0
$ flatpak-builder --help       → --install-deps-from=REMOTE, --user, --installation=NAME,
                                 --force-clean, --ccache, --repo=DIR all present (1.4.2)
$ flatpak remotes              → flathub (user)
$ rustc/cargo --version        → 1.98.1; flatpak 1.14.6; just → NOT installed
Cargo.lock:2738-2740 → libcosmic 1.0.0, source git+https://github.com/pop-os/libcosmic.git
                       #d4d71fd53e5ed6bd3a430089114dffa2da3cd498

D13 smoke-mechanism spike (2026-09-11, packager; agent-sandbox HOME only — /home/gosh never written):
$ flatpak build-export /tmp/np-smoke-repo /tmp/np-flatpak-baseline stable
  → EXIT=0; repo 72.2 MB; exported desktop file keeps plain "Exec=notepad %F"
$ flatpak --installation=/tmp/np-tmp-inst install -y --nondefault /tmp/np-smoke-repo com.goshapps.Notepad stable
  → "error: Could not find installation /tmp/np-tmp-inst"   (--installation needs a REGISTERED dir;
    "--nondefault" additionally rejected as unknown option for install)                  → DISPROVEN
$ XDG_DATA_HOME=/tmp/np-xdg flatpak --user list
  → bootstraps from scratch: creates /tmp/np-xdg/flatpak/repo                (path B mechanism proven)
$ flatpak install -y /tmp/np-smoke-repo com.goshapps.Notepad stable          (no --user)
  → "Failed to activate service 'org.freedesktop.Flatpak.SystemHelper': timed out" (~25 s)
$ flatpak install --user -y --no-deps /tmp/np-smoke-repo com.goshapps.Notepad stable
  → OK: "NotePad 3.0.0 stable"                                               (path A install proven)
$ installed desktop file (path-A installation):
  Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=notepad
       --file-forwarding com.goshapps.Notepad @@ %F @@        (@@ file-forwarding CONFIRMED)
$ flatpak run --command=sh com.goshapps.Notepad …  (finish-args enforcement under flatpak run):
  /home/gosh → fabricated mount skeleton only (xdg-config/cosmic bind); ~/.config/cosmic rw;
  /run/user/1000 visible; /app/bin → just notepad
  contrast: `flatpak build /tmp/np-flatpak-baseline` → ls /home/gosh SUCCEEDS
  (finish-args NOT applied → path C rejected, debug-only)
$ weston 13 headless (DEFAULT shell) + dbus-run-session + flatpak run com.goshapps.Notepad:
  "FLATPAK RUN: ALIVE after 10s" → SIGTERM → "clean SIGTERM exit rc=143"; panic-regex matches: 0
$ flatpak uninstall --user -y com.goshapps.Notepad → clean; pgrep weston|notepad → empty
  footgun: first cleanup attempt `pkill -f "weston --backend=headless --socket=np-smoke-0"`
  killed the invoking shell itself (pattern self-match, exit 144) → use recorded PIDs / pkill -x
```
