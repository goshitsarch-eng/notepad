# Migration decision log

Every disagreement, ambiguity, or judgment call made during the libcosmic
migration verification is recorded here: the question, the options considered,
the choice made, and why. Lead-maintained; append-only.

Priority order used for tie-breaks (from the project charter):

1. Feature parity with the original app
2. Working correctly in the Flatpak sandbox
3. Accessibility
4. Simplicity and maintainability
5. Following COSMIC conventions

---

## D1 — What "the migration" means for this repository

**Question.** The work order described migrating "a desktop app currently built
with GTK4" to libcosmic, with unfilled `[APP NAME]`/`[LANGUAGE]` placeholders.
The repository contains NotePad (`com.goshapps.Notepad`) whose working tree is
**already a completed libcosmic rewrite (v3.0.0)** of the previous
**Python/PySide6 (Qt6) v2.0.4** app. App lineage per
`data/com.goshapps.Notepad.metainfo.xml`: 1.0.0 was GTK4, 2.0.0–2.0.4 were
PySide6/Qt6, 3.0.0 is libcosmic.

**Options.**
- A: Treat the order as stale and stop for clarification.
- B: Treat the goal state as authoritative: a finished, working libcosmic app
  with verified feature parity against the pre-libcosmic release, fully tested
  (unit + integration + Flatpak smoke test + `scripts/verify.sh`), shipping as a
  Flatpak, with `docs/migration/*` documentation — i.e. verify, complete, and
  harden the existing 3.0.0 rewrite rather than re-doing it.

**Choice.** B. The order explicitly says to work autonomously and not stop for
approval; the goal state, team structure, testing requirements, and definition
of done apply verbatim to this repository. The parity reference is **v2.0.4**
(the immediate predecessor, tagged in git). **Correction (2026-09-11, review
RV-11):** this entry originally described 2.0.4 as "still installed as a user
Flatpak" — falsified by the exhaustive search recorded in the **D3 addendum**,
which is authoritative on availability and the resulting parity mechanism.
Evidence: `plans/libcosmic-rewrite.md` and `plans/bugfix-pass.md`
(completed checklists), README, metainfo release history, git tags v2.0.2–v2.0.4.

---

## D2 — Host toolchain provisioning

**Question.** The host lacked every tool the definition of done requires (no
git, no cargo/rustc, no flatpak-builder, no headless display server), and the
Flatpak manifest's `com.system76.Cosmic.BaseApp//stable` and
`org.freedesktop.Sdk.Extension.llvm21//25.08` were not installed. No flatpak
remotes were configured at all.

**Options.** A: work inside the Freedesktop SDK Flatpak only. B: provision the
host (passwordless sudo is available; network works).

**Choice.** B, minimally: apt-installed `git`, `flatpak-builder`, `xvfb`,
`weston`, `desktop-file-utils`, `appstream`/`appstream-util`, build headers
(expat/fontconfig/freetype/xkbcommon/wayland), `mesa-vulkan-drivers`,
`vulkan-tools`, `x11-utils`, `jq`; rustup stable (1.98.1, clippy + rustfmt)
user-local with proxies symlinked into `~/.local/bin` (already on PATH);
added the Flathub remote and installed Cosmic BaseApp + llvm21. Nothing was
removed or upgraded beyond package installation. `just` intentionally not
installed — project scripts must rely only on cargo/git/flatpak tooling (see D6).

---

## D3 — Protect the installed v2.0.4 Flatpak *(heading historical: the addendum below establishes that no installed copy exists; the protection posture generalizes to every real installation — see review RV-11)*

**Question.** Flatpak smoke tests must build, install, and run
`com.goshapps.Notepad` — the same app ID as the user's installed v2.0.4.

**Options.** A: install over it. B: isolated installation.

**Choice.** B. The installed 2.0.4 is both the user's app and the live parity
reference. All test installs go to a dedicated throwaway flatpak installation
directory (`flatpak --installation=…`), never the user installation, and are
removed after the run. Recorded here so no teammate "fixes" this later.

**Addendum (2026-09-11, fact correction).** Exhaustive checks (sandbox-HOME
user installation, `/home/gosh/.local/share/flatpak/app/` — 13 apps, no
Notepad, `/var/lib/flatpak` empty, `find … -iname "*notepad*"`) show **no 2.0.4
Flatpak is installed anywhere visible**. The posture is unchanged and
generalized: never write to `/home/gosh`'s real user installation (it holds 13
of the user's apps); all test installs use throwaway `--installation` dirs.
Consequence for verification: **live A/B runtime comparison against 2.0.4 is
not available.** The parity mechanism is instead (a) the 2.0.4 test suite's
behavioral contracts ported into Rust unit/integration tests driven through
messages/state, and (b) Phase 3 checklist verification of the 3.0.0 Flatpak
against `docs/migration/ux.md`. Building 2.0.4 from the source cache
(`io.qt.PySide.BaseApp//6.10`, ~1–2 GB) remains a fallback only if the reviewer
shows a parity dispute that the ported contracts cannot settle.

---

## D4 — Branch, identity, and commit discipline

**Question.** How to keep the requested "small reviewable commits" history with
four agents sharing one working tree.

**Choice.** Work happens on branch `cosmic-migration` (from `main` @ 776b74d).
Commits are made by the lead only, after the devil's advocate signs off on the
diff, one commit per completed task, using the repository owner's existing git
identity. Teammates never run `git commit`/`checkout`/`branch` themselves —
this avoids index races between concurrent agents. Phase 2 editing is sequenced
so at most one teammate modifies the shared tree at a time (docs/tests in
disjoint directories may proceed in parallel).

---

## D5 — File ownership over the existing monolith

**Question.** The charter assigns "view/widget modules" to UX and "core, state,
config modules" to Architecture, but the rewrite is a monolith: `src/app.rs`
contains view **and** state/update code.

**Choice.** Ownership maps to regions until/unless Phase 2 splits the file:
- UX: view-building regions of `src/app.rs` (`header_start`, `header_end`,
  `view`, `find_bar`, `dialog`, `footer`, `context_drawer`, menu item builders,
  key-binding handler), `src/key_bind.rs`, `i18n/`, `data/` user-facing copy.
- Architecture: state/update regions of `src/app.rs` (`App` struct, `Message`,
  `update`, lifecycle hooks, document/save/load logic), `src/commands.rs`,
  `src/config.rs`, `src/single_instance.rs`, `src/main.rs`.
- Packaging/QA: `com.goshapps.Notepad.json`, `tests/`, `scripts/`, `justfile`,
  packaging metadata in `data/`, `.gitignore` build entries.
- Reviewer: `docs/migration/review-*.md` only (read-only elsewhere).

Cross-boundary tasks (e.g. a testability refactor of `app.rs`) are sequenced by
the lead: one owner edits, the other reviews. Any structural split of `app.rs`
is itself a task with a single owner (Architecture), after which the region map
updates to a file map.

---

## D6 — Verification bar

**Question.** The charter requires `cargo clippy -- -D warnings`; the repo's
`just check` recipe uses the stricter `-W clippy::pedantic` (warnings only).

**Choice.** `scripts/verify.sh` enforces the charter bar: `cargo build --locked`,
`cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`,
plus packaging validation and the Flatpak smoke test. Pedantic lints stay
available via `just check` for development but are not a gate (keeping the gate
at the charter's bar avoids churning the codebase with pedantic-only rewrites).
Scripts use only cargo/git/flatpak tools — no `just` dependency — so
`verify.sh` runs on any provisioned machine or CI runner.

**Addendum (2026-09-11).** `cargo fmt --check` is adopted as verify.sh step 1:
the tree is already rustfmt-clean (lead-measured), so the gate costs nothing
and keeps review diffs clean. Full gate list (10 steps) per
`docs/migration/packaging.md` §4: fmt, build --locked, clippy --all-targets
-D warnings, test --locked, desktop-file-validate, appstreamcli validate
--no-net, jq manifest sanity, scripts/vendor.sh, flatpak-builder --force-clean,
scripts/smoke-test.sh.

---

## D7 — Known baseline defect at Phase 1 start

`cargo clippy --all-targets -- -D warnings` fails on `src/config.rs:43`
(`#[must_use]` on `theme_for`, which returns already-`#[must_use]`
`cosmic::Theme`; clippy::double_must_use). Fix (remove the redundant attribute)
is the first Phase 2 task, owned by Architecture. Recorded so the reviewer can
verify it was not silently `#[allow]`-ed.

---

## D8 — Invalid UTF-8 on Open: reject (restore 2.0.4 behavior)

**Question.** (Raised as UX gap "D-5"/T-6 in `docs/migration/ux.md` §7/§8 —
ux.md deviation IDs D-1…D-8 are local to that document and distinct from this
log's D1…Dn.) 2.0.4 opened files with `encoding="utf-8"` **strictly**: a
`UnicodeDecodeError` produced a "Could not open file: {err}" dialog and the
document was untouched (`window.py:618-628`). 3.0.0 currently uses
`String::from_utf8_lossy` (`src/app.rs` `load_path`), so a CP1252/Latin-1 file
opens with U+FFFD replacements and a subsequent Save **silently rewrites the
file with corrupted bytes**.

**Options.**
- A: Strict reject — `String::from_utf8` (or validate bytes) on load; on
  failure show the existing `PendingDialog::Error` with the `could-not-open`
  copy plus the decode error detail; document and title unchanged.
- B: Keep lossy open, add a one-time warning dialog.
- C: Keep lossy open, mark the buffer read-only until Save As.

**Choice.** A. Priority 1 is feature parity: strict reject is exactly the 2.0.4
contract, and it is also the only option with zero data-loss risk (B still
permits save-over-corruption after the user dismisses the warning; C invents a
read-only mode 2.0.4 never had, adding state and edge cases). The convenience
argument for lossy open (legacy encodings "still open") is outweighed: 2.0.4
users never had that behavior, and silent corruption on re-save is worse than a
clear error. Implementation notes: reuse `PendingDialog::Error`; the message
should name the file and the decode problem, mirroring 2.0.4's
`f"Could not open file:\n{err}"`; a unit test feeds invalid bytes (e.g.
`[0x66, 0x6f, 0x6f, 0xff, 0xfe]`) and asserts the error path and that
`content`/`saved_text`/title are unchanged. Owner: Architecture (state/load
region). Verify: U + M.

---

## D9 — Vendoring: vendor-on-demand, offline Flatpak build

**Question.** The charter requires "vendored cargo sources including git
dependencies" and minimal sandbox permissions, but the current manifest builds
with `--share=network` + plain `cargo build`, and libcosmic is a git dep.
Empirical spike (`docs/migration/packaging.md` §2): `cargo vendor` captures all
10 git deps at locked revs incl. libcosmic d4d71fd5 — 636 crates, 973 MB dir,
943 MB tar, 149 MB gz; full `cargo build --release --frozen --offline` against
vendored sources: exit 0 in 1m09s.

**Options.**
- A: Commit `vendor.tar` (System76 template pattern).
- B: Vendor on demand — `scripts/vendor.sh` materializes `vendor/` +
  `.cargo/config.toml` (gitignored, `vendor.tar` kept as a local/CI cache);
  manifest switches to `cargo build --release --frozen --offline` and drops
  `--share=network`; `sources: [{type: dir, path: .}]` carries the materialized
  vendor dir into the sandbox.
- C: `flatpak-cargo-generator` per-crate archive sources (Flathub-standard
  hermetic).
- D: Keep `--share=network` status quo.

**Choice.** B. A is impossible: 943 MB exceeds GitHub's 100 MB file limit
(gz still 149 MB), and LFS would centralize a ~1 GB blob that churns on every
dep bump. C is technically excellent but is not literally "vendored cargo
sources" as the charter requires, and adds a Python tool + ~600-crate generated
file to maintain. D violates the requirement. B builds **strictly offline**
(`--frozen --offline`, no `--share=network`) from lockfile-pinned vendored
sources with per-crate checksum verification; the only network window on a
clean checkout is provisioning (vendor fetch + first-time flatpak deps), which
is reproducible from `Cargo.lock`. `vendor.tar` stays gitignored as a cache; CI
caches it keyed on `sha256(Cargo.lock)`. Also in the same change: add
`"branch": "stable"` to the manifest (2.0.4 had it; Flathub convention;
`build-export` otherwise defaults to `master`).

---

## D10 — Pin libcosmic by explicit rev in Cargo.toml

**Question.** libcosmic is a git dep on a live `master` branch, pinned only by
`Cargo.lock` (d4d71fd5). All build paths use `--locked`/`--frozen`, so
day-to-day builds can't drift — but any lockfile regeneration would silently
float to whatever `master` is that day. libcosmic has no meaningful release
tags (`version = "1.0.0"` permanently on master).

**Choice.** Add `rev = "d4d71fd53e5ed6bd3a430089114dffa2da3cd498"` to the
`[dependencies.libcosmic]` table. Declarative, survives lockfile regen, no
resolution change (lock already at that rev). Edit lands with the vendoring
task: `Cargo.toml` is Architecture-owned (D5), packager supplies the exact rev
string, reviewer verifies `Cargo.toml` ↔ `Cargo.lock` agreement. A
`tests/packaging.rs` assertion pins the match.

**Addendum (2026-09-11, T05 execution — nuance to "no resolution change").**
The rev pin does not change *which* commit resolves (d4d71fd5 either way), but
it changes cargo's *source-ID text*: `git+https://github.com/pop-os/libcosmic.git`
→ `git+https://github.com/pop-os/libcosmic.git?rev=d4d71fd5…`. That forces a
one-time mechanical `Cargo.lock` rewrite: every bare-form libcosmic `source =`
line is replaced by its `?rev=` twin — identical `#d4d71fd5…` fragment, zero
version/checksum/dependency movement (18 pairs on the lock at execution time;
the gate is the shape, not the count — census recorded in the T05 evidence).
`cargo metadata --locked --offline` exits 101 until a one-time
`cargo metadata --offline` regen; post-regen it and `cargo build --locked` are
both green. Downstream consequence (the second, independent T06 breakage
mode): vendor source-replacement stanzas are keyed on source ID, so `vendor/`
must be materialized *after* the pin + regen (A-before-B ordering) — a vendor
tree generated from the bare lock carries keys the pinned source ID will not
match, even though crate contents are identical. Evidence: reviewer objection
spike + packager independent reproduction; amended Step A adopted in PLAN.md
rev 9 (`0297eb7`) and executed in the T05 single commit (branch
`cosmic-migration`).

---

## D11 — Smoke-test environment and pass/fail protocol

**Question.** How to prove "launches, stays running, exits cleanly" headlessly
without touching the live session or any real installation.

**Choice.** Per `docs/migration/packaging.md` §3 (both legs empirically proven
in spike):
- **Primary leg:** weston 13 `--backend=headless` with the **default desktop
  shell** — never `fullscreen-shell.so` (no `xdg_shell` global → winit panics
  at `state.rs:182`). Socket-readiness via `[ -S … ]` poll + settle, dedicated
  `XDG_RUNTIME_DIR` (mktemp, 0700) and unique socket name so the app's own
  single-instance socket can't produce false results and the live `wayland-1`
  session is never attached.
- **Secondary leg:** `xvfb-run -a` with COSMIC/desktop env vars scrubbed — the
  designated proof of non-COSMIC, non-Wayland operation (manifest still ships
  `fallback-x11`).
- Everything inside one `dbus-run-session`; app installed via the D13
  mechanism (isolated/throwaway installation; never the user's real
  installation), uninstalled in the cleanup trap.
- **Pass criteria:** alive after 10 s (`kill -0`); terminates on SIGTERM within
  5 s; exit code ∈ {0, 143}; stderr free of
  `panicked at|thread '.*' panicked|Fatal|wgpu error|Device lost|CreateEventLoop|OsError`.
  Benign noise (portal/dbus activation, xdg-desktop-portal-gtk fallback
  warnings, this host's nix-gvfs undefined-symbol spam) goes to a documented
  allowlist — exit status + narrow panic regex decide, not raw stderr.
- Rendering needs no GPU: lavapipe confirmed inside
  `org.freedesktop.Platform//25.08`; host llvmpipe and iced tiny-skia as
  further fallbacks.

---

## D12 — Desktop file `Categories`: drop bare `COSMIC`

**Question.** `desktop-file-validate` fails today:
`Categories=COSMIC;Utility;TextEditor;` — `COSMIC` is an unregistered value
(spec requires `X-` prefix for extensions). Shipped Flathub COSMIC apps on
this machine use `X-Cosmic`/`X-COSMIC`.

**Choice.** `Categories=Utility;TextEditor;X-COSMIC;`. Validator-clean,
matches the observed Flathub COSMIC convention, preserves COSMIC DE menu
grouping (COSMIC recognizes the `X-COSMIC`/`X-Cosmic` extension).
**UX sign-off GRANTED (2026-09-11)** with parity evidence: 2.0.4 shipped
`Categories=Qt;Utility;TextEditor;` — the new value mirrors that exact pattern
(toolkit marker + the same two substantive categories), all other desktop-entry
keys unchanged. `tests/packaging.rs` does not pin Categories, so no test churn. Metainfo fix rides along: unwrap the
non-spec `<provides><binaries>` wrapper to `<provides><binary>` (appstreamcli
info `unknown-provides-item-type binaries`; convention of installed COSMIC
apps).

**Deferred until evidence exists** (tracked, not decided): dropping
`--talk-name=org.freedesktop.portal.Desktop` from finish-args (likely redundant
— flatpak's bus proxy auto-allows `org.freedesktop.portal.*` — but only removed
after the smoke test proves file-chooser/portal function without it; minimality
is priority-2, breakage is not acceptable); adding
`--talk-name=com.system76.CosmicSettingsDaemon` (only if Phase 3 on a real
COSMIC desktop shows live theme sync lagging via the file-watch fallback).

**Amendment (2026-09-11, review RV-2).** The smoke test (D11/T07) never opens
a file dialog — its criteria are launch/liveness/termination/panic-regex — so
the condition above is unsatisfiable by smoke evidence. The portal talk-name
removal is rewired: it happens **only after the Phase-3 portal FileChooser
check** (packaging.md §7: dbus-level `OpenFile` call with the talk-name removed
+ manual dialog round-trip) **passes**; otherwise the talk-name stays
permanently. The minimality gain is one finish-args line; sandbox correctness
is priority 2. PLAN.md T26(a) carries the rewired condition.

---

## D13 — Smoke-test installation mechanism (supersedes the `--installation` detail in D3/D11)

**Question.** D3/D11 originally specified a throwaway `flatpak
--installation=$DIR` for smoke-test installs. Packager spike **disproved** it:
`flatpak --installation=/tmp/… install` → `error: Could not find installation`
(flatpak 1.14.6) — `--installation` requires a *registered* installation
(`/etc/flatpak/installations.d`, i.e. root). A working mechanism is needed
before the smoke script can be built.

**Options** (all spike-tested by packager, 2026-09-11):
- **A — active-HOME `--user` install + trap-uninstall**: `build-export` →
  `flatpak install --user -y --no-deps <repo>` → run → `flatpak uninstall
  --user -y`. **Proven end-to-end through the real flatpak sandbox** with the
  full D11 protocol (weston headless + `dbus-run-session`, ALIVE 10 s, clean
  SIGTERM rc=143, zero panic matches, zero residue). Gotchas: must always pass
  `--user` (bare `flatpak install` hits SystemHelper and times out, ~25 s);
  only safe where the active installation is known-throwaway (agent sandbox
  HOME, ephemeral CI runner) — on a developer's real HOME it would transiently
  pollute their installation and could collide with a real
  `com.goshapps.Notepad` install.
- **B — `XDG_DATA_HOME=<persisted-throwaway-dir>` isolated user installation**:
  bootstraps from scratch (creates `$XDG_DATA_HOME/flatpak/repo`); D3-safe on
  ANY machine. Cost: empty installation needs the runtime stack pulled in once
  (~1.2 GB: Platform + GL.default + BaseApp; flathub remote added inside it
  first); persist the dir between runs (`~/.cache/notepad-smoke-installation`
  or CI cache) so the cost is one-time.
- **C — `flatpak build` on the build dir (zero-install)**: **REJECTED** —
  proven NOT to apply finish-args (inherits build-time filesystem access;
  `ls /home/gosh` succeeded inside), so it does not test the shipped sandbox
  configuration. Debug-only.

**Choice.** `scripts/smoke-test.sh` defaults to **B** (isolated, persisted,
machine-agnostic — the protection posture of D3 holds even on the user's real
HOME), with `NOTEPAD_SMOKE_FAST=1` selecting **A** where the active
installation is known-throwaway. C rejected; `--installation=<tmpdir>` and
bare `flatpak install` documented as dead ends. Bonus spike verifications
adopted into the design: finish-args enforcement confirmed under `flatpak run`
(/home/gosh reduced to the xdg-config/cosmic bind skeleton; `/run/user/1000`
exposed for wayland + single-instance socket), and `@@ %F @@` file-forwarding
confirmed in the installed export (Open-With works via document-portal with no
filesystem finish-arg) — retiring two VERIFY-P2 items. The protection posture
itself is unchanged from D3: never write to `/home/gosh`'s real installation.

---

## D14 — CRLF preservation is a deliberate improvement over 2.0.4

**Question.** The Architecture headless spike (`docs/migration/architecture.md`
§3.3 / risk R10) empirically settled line-ending behavior: v3.0.0's `Content`
(cosmic-text) round-trips CRLF **byte-faithfully** via per-line `LineEnding`
(`libcosmic:iced/graphics/src/text/editor.rs:120–131`,
`iced/widget/src/text_editor.rs:468–485`). v2.0.4 opened files in Python text
mode (universal newlines), normalizing CRLF→LF at load and rewriting the file
with LF on every save (`v2.0.4:src/window.py`). v3 therefore deviates from v2 —
in the user's favor: Windows-line-ending files are no longer silently rewritten.

**Options.**
- A: Document as a deliberate deviation/improvement and lock it with a
  load→save byte-equality test.
- B: Reproduce v2's CRLF→LF normalization for strict byte-level parity.
- C: Leave the behavior undocumented and untested.

**Choice.** A. Priority 1 (feature parity) protects intended user-visible
behavior, not side effects: v2's normalization was an artifact of Python text
mode, never a designed feature, and B would corrupt line endings on every save
of a CRLF file — a data-mutation regression, not parity. C leaves a
load-bearing behavior one silent libcosmic/cosmic-text bump away from changing
unnoticed. Architecture task T3 adds the byte-equality round-trip test
(CRLF and mixed-ending documents: load → save → identical bytes). Evidence:
spike result recorded in architecture.md §3.3; v2 behavior in
`v2.0.4:src/window.py` (text-mode open).
