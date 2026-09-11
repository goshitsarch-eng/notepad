# PLAN.md — NotePad libcosmic migration: consolidated Phase 2/3 plan

Lead-maintained consolidation of the three Phase-1 documents, per the project
charter. Rev 4 (2026-09-11).

**Inputs:** `docs/migration/ux.md` (rev 3), `docs/migration/architecture.md`
(rev 2), `docs/migration/packaging.md` (revised), `docs/migration/DECISIONS.md`
(D1–D14), and the devil's-advocate review `docs/migration/review-phase1.md`.

---

## 1. Summary

The repository is **already a completed libcosmic rewrite (v3.0.0)** of the
Python/PySide6 v2.0.4 app (DECISIONS **D1**). The project goal is therefore to
**verify, complete, and harden** it to the charter's definition of done:
verified feature parity against v2.0.4, full test coverage (state-model unit
tests for every Message variant, message-driven integration flows, Flatpak
smoke test, `scripts/verify.sh`), and a hardened Flatpak package — with every
decision logged and every task reviewed and committed small.

Phase 1 produced the three plan documents above plus 14 logged decisions.
Empirical spikes de-risked the load-bearing unknowns: headless Message-level
testing works (8/8 spike tests, 0.01 s, no GPU/display/dbus); `cargo vendor`
captures every git dependency and builds `--frozen --offline` (exit 0, 1m09s);
the smoke-test environment (weston headless + Xvfb, isolated installation)
passed end-to-end through the real sandbox.

Parity reference: **v2.0.4 source at `/home/gosh/.cache/notepad-v2.0.4/`**.
Live A/B runtime comparison is OFF (D3 addendum: no 2.0.4 Flatpak exists
anywhere); parity is verified via ported behavioral contracts (Rust tests) +
the ux.md §1 checklist against the running 3.0.0 Flatpak.

### Team and ownership (D5)

| Role | Agent | Owns |
|---|---|---|
| Lead | team-lead | Coordination, `DECISIONS.md`, `PLAN.md`, `REPORT.md`, all git commits |
| UX | ux | View regions of `src/app.rs`, `src/key_bind.rs`, `i18n/`, `data/` user-facing copy, `ux.md` |
| Architecture | architect | State/update regions of `src/app.rs`, `src/commands.rs`, `src/config.rs`, `src/single_instance.rs`, `src/main.rs`, `Cargo.toml`, `architecture.md` |
| Packaging & QA | packager | `com.goshapps.Notepad.json`, `tests/`, `scripts/`, `justfile`, packaging metadata in `data/`, `packaging.md` |
| Devil's advocate | reviewer | `docs/migration/review-*.md` only; sign-off authority on every task |

---

## 2. Process rules (binding)

1. **Phases.** Phase 1 (plan, no source changes) → Phase 2 (build the task
   list in order) → Phase 3 (harden: reviewer-led verification pass against
   the running Flatpak; failures become new tasks; repeat until clean).
2. **Per-task protocol.** Owner states a short plan before editing; reviewer
   may object before work begins — the plan note licenses editing to start,
   and the window is the reviewer's right to stop work in flight (owner
   pauses at the point of objection; rule 4 applies), not a clearance gate
   to await (lead interpretation, recorded at T02); teammates edit only
   files they own; at most
   one teammate modifies the shared tree at a time (docs in disjoint files may
   proceed in parallel); cross-boundary tasks are split/sequenced by the lead
   per D5 (one owner edits a region, the other reviews).
3. **Per-task definition of done** (charter, with a gate ramp):
   - Always: `cargo fmt --check`, `cargo build --locked`,
     `cargo clippy --all-targets --locked -- -D warnings`,
     `cargo test --locked` green; tree buildable; reviewer diff sign-off;
     affected ux.md §1 parity rows ticked with verification notes; lead
     commits with a descriptive message (D4).
   - From **T06** on: `flatpak-builder` succeeds (offline, vendored). **T06 is
     the retroactive Flatpak gate for T01–T05** (RV-15a): T05 edits the
     manifest and dependencies but deliberately does not itself run
     flatpak-builder — relying on T06, immediately after, is a stated choice,
     not an omission (RV-15b).
   - From **T07** on: `scripts/smoke-test.sh` passes.
   - From **T08** on: the per-task gate *is* `scripts/verify.sh` (all 10
     steps). **Skip authority (RV-15c = reviewer standing commitment (b)):**
     for tasks whose diffs touch only Architecture/UX-owned `src/` files, the
     reviewer may grant step 5–10 skip notes on request (steps 1–4 always
     run); packaging-affecting diffs run all 10. Every skip is recorded in the
     task's sign-off note.
4. **Disagreements** follow the charter protocol (objection with evidence →
   owner response → empirical spike/test where possible → lead decides by
   priority: parity > Flatpak sandbox correctness > accessibility >
   simplicity/maintainability > COSMIC conventions) and are recorded in
   `DECISIONS.md`. Never escalated to the user.
5. **Safety constraints** (binding on all agents): never write to `/home/gosh`'s
   real flatpak user installation; smoke installs use the D13 mechanisms only;
   no pushes to any remote; teammates run no sudo/apt/git; smoke tests never
   attach to the live wayland-1 session.

---

## 3. Feature parity checklist

**Canonical checklist: `docs/migration/ux.md` §1** (~90 rows, each with v2.0.4
and v3.0.0 file:line evidence, status Implemented/Partial/Gap/Deviation, and a
verification method U/M/S/R). This PLAN does not duplicate it; it fixes the
conventions and the test-coverage map. Phase 3 walks every row against the
running Flatpak and records verification notes.

**ID conventions.** ux.md-local deviation IDs `D-1…D-8` are cited project-wide
as **UX-D1…UX-D8** (distinct from `DECISIONS.md` D1–D14). Gaps are **G-1…G-6**,
accessibility findings **A-1…A-6** (ux.md §5, Appendix B). Architecture risks
are **R1…R15** (architecture.md §6); packaging risks are numbered in
packaging.md §8.

**Accepted deviations** (deliberate, documented, reviewer-visible): UX-D1
portals, UX-D2 inline replace bar, UX-D3 About drawer, UX-D4 COSMIC theme
tokens (contrast tests out of scope), UX-D6 mnemonics dropped, UX-D7 Delete
deletes next char (bugfix-pass item 10), UX-D8 font persisted / undo capped at
100 / Ctrl+Shift+Z added / min window 360×180, DECISIONS **D14** CRLF
byte-faithful (improvement; T03 locks it). UX-D5 (lossy UTF-8) was **retired**
by DECISIONS D8 → fixed in T03. The font dialog's missing live preview will be
added to ux.md §7 when T23 scope locks. Review RV-12/13/14 add three further
accepted micro-deviations, recorded in ux.md §7 as **UX-D9** (`to_lowercase`
vs v2's full-Unicode `casefold` in case-insensitive matching — exotic-Unicode
only; code comment rides T10), **UX-D10** (no clear button inside the find
entry — no iced equivalent; T18's select-all-on-open covers the common case),
and **UX-D11** (`NOTEPAD_ICON` env override dropped — v3 embeds the SVG icon).

### 3.1 Ported-test coverage map (v2.0.4 suite → v3.0.0)

Which 2.0.4 behavioral contracts have Rust tests, which get them in Phase 2,
and which are checklist-only (source: architecture.md Appendix B, packaging.md
§6, ux.md §1/§5):

| v2.0.4 test | Contract | v3.0.0 coverage | Status |
|---|---|---|---|
| `test_commands.py` | find first/skip-selection/wrap/case defaults; replace one/all + single undo step; goto 1-based + range rejection; U+2029 paragraph-separator case (`test_commands.py:122–127`) — **N/A**: Qt `QTextDocument` artifact, no v3 analog (RV-17) | `src/commands.rs:272–472` — 22 tests, green today; case-insensitive mechanism differs (UX-D9: `to_lowercase` vs v2 `casefold`) | 🔒 locked; app-level chains → **T10** (F14–F16) |
| `test_window.py` | find-bar focus + select-all on open; close-button accessible name "Close Find" + Esc tooltip; Esc returns focus to editor | accessible name → **T15**; focus/select-all → **T18/T19** (widget focus is not headless-unit-testable → smoke/manual verify; visibility/Esc at message level → **T10** `on_escape`) | planned |
| `test_application.py` | second-instance open guarded (dirty → dialog; discard → loads) | → **T11/T14** (F21) | planned |
| `test_theme.py` | color-scheme default/roundtrip/invalid-fallback; WCAG contrast; QSettings persistence | persistence + scheme decisions → **T12** (`with_custom_path`); contrast/palette **out of scope** (UX-D4) | planned / deviation |
| `test_packaging.py` | license/version/runtime/identity asserts | `tests/packaging.rs` — 6 tests, green today; extended in **T04/T05** | 🔒 locked |

Everything else in ux.md §1 marked Implemented without a 2.0.4 test is covered
by the architecture.md §2.3 matrix tasks (**T09–T14**: 47 of 48 Message
variants — #40 `LaunchUrl` excluded by design with reviewer sign-off — plus
flows F1–F22) and verified manually in Phase 3.

---

## 4. Consolidated risk list (top items; full registers in source docs)

| # | Risk (source) | Mitigation / where handled |
|---|---|---|
| 1 | **G-1: shortcuts fire only with editor focus** — worst parity gap (ux.md) | **T21** (approved `listen_with` + `Status::Ignored` design, modal suppression) |
| 2 | **Clippy gate red at baseline**, `src/config.rs:43` (arch R1, pkg 2, D7) | **T01**, first task; no `#[allow]` |
| 3 | **Manifest violates vendoring requirement** (`--share=network`, non-frozen) (pkg 1, D9) | **T05** (spike-proven design) |
| 4 | **desktop-file-validate red** (bare `COSMIC` category) (pkg 3, D12) | **T04** (UX sign-off granted with parity evidence) |
| 5 | **`src/app.rs` contested** between UX and Architecture regions (arch R12, D5) | Lead ruling: **T02 lands before any UX view edit**; no file split now; arch test work adds only new files + one-line mod declarations |
| 6 | **Task opacity** — iced Tasks unassertable (arch R2) | Assert state + inspectable enums; behavior-bearing tasks → smoke (**T07**); optional clipboard seam **T24** reviewer-gated |
| 7 | **`fl!` in test binaries unproven** (arch R5) | Settled empirically in **T02** (fallback: `i18n::init(&[en])` in harness) |
| 8 | **libcosmic master drift** on lockfile regen (pkg 7, D10) | Explicit `rev` pin in **T05** + `--locked`/`--frozen` everywhere + packaging.rs match assertion |
| 9 | **BaseApp//stable drift** (pkg 6, RV-16) | Cannot pin; record BaseApp commit per release (today `b3f1b274d540`); CI smoke catches breakage **only on cache-miss/fresh legs** — T25 must key caches on the actual BaseApp commit (`flatpak info -c`), time-bust them, or run a periodic fresh-install leg |
| 10 | **Undo capped at 100, whole-document snapshots** (arch R7, UX-D8) | Accepted deviation, memory-safety rationale; documented for reviewer |
| 11 | **Single-instance bind race** (arch R9) | Parity-accepted (v2 same class); optional logging in **T13** |
| 12 | **Smoke stderr classification** too strict/loose (pkg 9, D11) | Exit-code-first criteria + narrow panic regex + reviewed allowlist in **T07** |
| 13 | **Vendor size** 973 MB slows builds/caches (pkg 8) | Measured acceptable; timings recorded in **T06** |
| 14 | **Font-dialog scope open** (ux G-4) | **T23** locks scope after architect spike + reviewer input; preview is an accepted deviation |

---

## 5. Phase 2 — ordered task list

Every task leaves the tree buildable and gate-green (§2.3). Source IDs in
parentheses map to the Phase-1 documents. "Owner (+collab)" uses the D5 map.

### Stage A — gate green

| ID | Task | Owner (+collab) | Depends | Done when (beyond standard gate) |
|---|---|---|---|---|
| **T01** | Clippy gate fix: remove redundant `#[must_use]` from `theme_for` (`src/config.rs:43`, D7 — `cosmic::Theme` is already `#[must_use]`); also delete dead `line_count` (`src/commands.rs:177–181`). No `#[allow]` anywhere. (arch T1 = P2-T1) | architect | — | `cargo clippy --all-targets --locked -- -D warnings` exits 0 |

### Stage B — test seam + data safety (Architecture)

| ID | Task | Owner (+collab) | Depends | Done when |
|---|---|---|---|---|
| **T02** | Test seam: split `App::init` → thin `init` + `with_config(core, flags, config, handler)` (architecture.md §3.5); add `src/app_test_harness.rs` (`test_app()`, text/tempdir helpers); `#[cfg(test)] #[path]` mod plumbing; settle `fl!`-without-init (R5) and the `set_main_window_id` constant (R15). Zero behavior change. **Must land before any UX view-region edit (R12 ruling).** (arch T2) | architect | T01 | Harness spike tests green; `App::init` behavior unchanged; no real `~/.config` touched by tests |
| **T03** | D8 strict-UTF-8 load: `String::from_utf8` in `load_path`; on `Err` → `PendingDialog::Error` with could-not-open copy + decode detail naming the file (UX reviews copy); document/`saved_text`/title untouched. D14 CRLF lock: load→save byte-equality tests (CRLF + mixed endings). (arch T3 = ux T-6) | architect (+ux copy review) | T02 | D8 spec test (`[0x66,0x6f,0x6f,0xff,0xfe]` → error dialog, state unchanged) + CRLF round-trip tests green |

### Stage C — packaging infrastructure (Packaging & QA)

Landed early so every later task can run the full charter DoD gate.

| ID | Task | Owner (+collab) | Depends | Done when |
|---|---|---|---|---|
| **T04** | Desktop/metainfo fixes (D12): `Categories=Utility;TextEditor;X-COSMIC;`; unwrap metainfo `<provides><binaries>` → `<binary>`; pinned-string rule applies (any intentionally changed pinned string updated in `tests/packaging.rs` in the same commit). (P2-T2) | packager (+ux sign-off: granted, D12) | — | `desktop-file-validate` exit 0; `appstreamcli validate --no-net` exit 0, 0 infos; tests green |
| **T05** | Vendoring switch (D9/D10): `scripts/vendor.sh` (vendor/ + `.cargo/config.toml` + gitignored `vendor.tar` cache); manifest → `cargo build --release --frozen --offline`, drop `--share=network`, add `"branch": "stable"`; `rev = "d4d71fd5…"` pin in `Cargo.toml` (**architect edits, packager supplies the exact string**); extend `tests/packaging.rs` per packaging.md §6, **including an assertion that the manifest build-commands contain the LICENSE/COPYRIGHT install lines (RV-6 — today only the justfile is pinned, which the Flatpak build does not use; GPL-compliance relevant)**. (P2-T3) | packager (+architect for the Cargo.toml line) | T04 | vendor.sh from clean state; `cargo build --release --frozen --offline` green; tests green |
| **T06** | Vendored offline Flatpak rebuild: `flatpak-builder --user --install-deps-from=flathub --force-clean --ccache`; measure vendor dir-copy / build / ccache timings; append findings to packaging.md. (P2-T4) | packager | T05 | flatpak-builder exit 0 fully offline |
| **T07** | `scripts/smoke-test.sh` per packaging.md §3 + D11/D13: path-B default (persisted isolated installation), `NOTEPAD_SMOKE_FAST=1` path A; weston-headless wayland leg + Xvfb leg; liveness/termination/panic criteria + stderr allowlist; PID-based cleanup traps; checksum-tamper check. (P2-T5) | packager | T06 | Passes twice consecutively against the T06 build; no leftover processes; path-A residue-free; tampered vendor correctly fails |
| **T08** | `scripts/verify.sh` per packaging.md §4 (10 steps, env overrides, logging, exit 0/1/2); dry run on current tree; then full run from a **fresh clone in /tmp**. (P2-T6) | packager | T07 | Fresh-clone run exits 0 unattended (single network window per D9). **From here, verify.sh is the per-task gate.** |

### Stage D — Message-level coverage (Architecture)

Each task adds one new Architecture-owned test file + a one-line mod
declaration; together T09–T14 drive **47 of the 48 Message variants**
(architecture.md §2.3) — #40 `LaunchUrl` is excluded by design (risk R3:
immediate process-spawn side effect; reviewer sign-off granted in
review-phase1.md, manual/smoke coverage only) — and flows **F1–F22** (§4.3):
the charter's unit + integration mandate. Sequenced before Stage E so the
coverage locks current behavior before UX changes touch the view/focus layers.

| ID | Task | Owner | Depends | Done when |
|---|---|---|---|---|
| **T09** | Editing coverage (arch T4): Editor edit/non-edit + undo snapshotting, Undo/Redo (cap-100 eviction, edit-clears-redo), Cut/Copy state effects, ClipboardPaste, Delete, SelectAll, InsertDateTime format, key-binding map unit test, **plus a pure-fn test of `MenuAction::message()`** — all 22 variants → expected `Message`, and the `aligned_disabled_item` Go-To case (review RV-1). `src/app_edit_tests.rs`. | architect | T02 | §2.3 rows #1, 10–16, 29, 30 covered; MenuAction map test-locked (architecture.md Appendix A Menus row → 🧪 T09); green |
| **T10** | Find/replace/goto coverage (arch T5): prefill rules, wrap-around, match-case, not-found dialogs, replace-one chain, replace-all single-undo-step, goto prefill/validation/wrap-disabled no-op, `on_escape` find-bar branch. Also adds the `to_lowercase`-vs-v2-`casefold` accepted-micro-deviation comment to `src/commands.rs` (RV-12; ux.md §7 UX-D9). Flows F14–F16. `src/app_search_tests.rs`. | architect | T02 | §2.3 #17–28 covered; 2.0.4 `test_commands.py`/`test_window.py` message-level contracts locked |
| **T11** | File-lifecycle coverage (arch T6 — the big one): guard matrix (4 × AfterSave × dirty/clean), DialogSave continuation with/without path, stale-prompt clearing, CloseError re-raise, Cancelled semantics, save/load error dialogs (incl. D8 path from T03), Exit retarget, `on_escape`/`on_app_exit`/`on_close_requested`, OpenExternal, argv-init load — all on tempdirs. Flows **F1**–F13, F22 (F1 new-clean added per RV-4). `src/app_file_tests.rs`. | architect | T02, T03 | §2.3 #2–9, 42–45, 47–48 + hooks covered; `test_application.py` contract (F21) locked |
| **T12** | Settings/theme/font + persistence coverage (arch T7): toggles with on-disk RON assertions via `with_custom_path` tempdir handler, ApplyFont state machine, `theme_for`/`pin_independent` pure tests, `UpdateConfig` (font re-derive; set_theme only on scheme change), ToggleContextPage, header_title matrix. Flows F17–F19 **+ F20** (Ln/Col app-side, per RV-4). **Plus the invalid-config-fallback test (RV-5; v2 `test_theme.py:311–313` contract): malformed RON value under a `with_custom_path` tempdir → field default applied + app functional.** `src/app_settings_tests.rs`. | architect | T02 | §2.3 #31–39, 41, 46 covered; `test_theme.py` persistence + invalid-fallback contracts locked |
| **T13** | single_instance server testability (arch T8): extract `subscription_at(path)`; test bind-temp-socket + `forward_to` + ack on a tokio current-thread runtime; stale-socket unlink. Optional R9 bind-failure logging. Independent of T02 (different file, same owner) — **may run immediately after T01, in parallel with the T02 edit→review cycle**; separate commit. | architect | — | Server loop tested; existing client test untouched |
| **T14** | Cross-flow integration scripts (arch T9): multi-hop chains not already inside T09–T12 — F5+F6 continuation/abort interplay, F7+F8 failure-retry-stale-prompt, F10 two-hop open, F21+F22 exit/second-instance combos. `src/app_flow_tests.rs`. | architect | T09–T12 | All F1–F22 flows have at least one test; charter integration mandate satisfied |

### Stage E — UX parity & accessibility fixes

UX edits the view regions of `src/app.rs` + `key_bind.rs`/`i18n/`/`data/`;
cross-boundary items are sequenced per D5 (one owner edits, the other reviews;
single combined diff, reviewer sign-off, one commit).

| ID | Task | Owner (+collab) | Depends | Done when |
|---|---|---|---|---|
| **T15** | A11y one-liner (ux T-2, A-1): `.name(fl!("close-find"))` on the find-bar close button (ftl key exists, currently unused). | ux | T02 | Key used; AT name present (accesskit/smoke check as feasible) |
| **T16** | A11y labels (ux T-9, A-2/A-3): `.name(fl!("color-scheme-button"))` on the header scheme button (ftl:57 unused); Go To / Font inputs labeled or placeholders carrying the label. | ux | T15 | All three controls announced; no unused-key regression |
| **T17** | About attribution (ux T-7, G-6): populate `About` `author`/`comments`/`copyright` ("Made by Gosh", tagline, "© 2026 Gosh — GPL-3.0-or-later") matching `window.py:452–461`; add ftl keys as needed; **consume `app-comment` and delete the dead `app-keywords` key** (RV-8 ruling: metainfo `<keywords>` is static XML, so the ftl duplicate is removed rather than wired; disposition recorded in ux.md §4). **Cross-boundary (RV-9 as amended, D5): the About data lives in `App::init` (Architecture region) — architect edits or co-signs one combined diff; ux owns content/semantics.** | ux (+architect edit/co-sign) | T16 | About drawer matches 2.0.4 content; **zero unused ftl keys remain after T15/T16/T17** (corrected baseline per RV-8: four unused today); ux.md §1.9 row ticked |
| **T18** | Find focus-in (ux T-3, G-2): auto-focus + select-all the find input on `Find`/`Replace` open (stable `Id` + `text_input::focus` task), matching `window.py:93–95` / `test_window.py:31–35`. **Cross-boundary (RV-9, D5):** the focus task is emitted from the `Find`/`Replace` `update()` arms (Architecture region) — architect edits those lines or co-signs one combined diff; ux owns semantics + verification. | ux (+architect edit/co-sign) | T02 | Manual/Phase-3 verify per ux.md; T10 visibility tests still green |
| **T19** | Find focus-out (ux T-4, G-3): return focus to the editor on `CloseFind`/Esc, matching `window.py:97–99` / `test_window.py:46–62`. **Cross-boundary (RV-9, D5):** `on_escape` is an Architecture-region lifecycle hook — architect edits or co-signs; ux owns semantics + verification. | ux (+architect edit/co-sign) | T18 | Manual/Phase-3 verify; Esc-precedence tests (T10/T11) green |
| **T20** | Menu enable-state (ux T-5, G-5/A-4): grey Cut/Copy/Delete with no selection, Undo/Redo with empty stacks, via the existing `aligned_disabled_item` pattern. Split: architect adds `has_selection`/undo-depth predicates (state region), ux wires the menu items (view region); the predicates' tests live in T09's suite (their named test home). | ux (+architect predicates) | T09 | No-selection → greyed; empty doc → Undo/Redo greyed; alignment intact |
| **T21** | **Global shortcuts (ux T-1, G-1 — highest-impact fix)**: `iced::event::listen_with` filtered to `(Event::Keyboard(_), Status::Ignored)` → `key_binds` → `MenuAction::message()`; suppressed while `pending.is_some()` (modal parity); editor binding closure unchanged → no double-fire by construction. The `pending.is_some()` suppression deliberately does **not** extend to the About drawer (no v2 modal analog — recorded in the task record per reviewer). Split: architect implements subscription + routing (state region); ux owns the 17-binding table parity + focus-interaction verification (must not fight T18/T19). | architect (+ux verification) | T18, T19, T10 | Ctrl+S/Ctrl+F/F3/Ctrl+H etc. fire with find-bar focus; suppressed under modal dialogs; message-level tests + manual verify |
| **T22** | Polish (ux T-10 + RV-7): select-all the Go To entry on open; **return focus to the editor on `GoToConfirm` success** (v2 `window.py:588` `setFocus()` — parity gap found by review; same `Id`+focus-task mechanism as T19; cross-boundary: `confirm_goto` is Architecture region — architect edits/co-signs); verify no-arg second instance raises the window (may need more than `gain_focus`). | ux (+architect edit/co-sign) | T21 | ux.md §1.4/§3.7/§3.9 rows ticked; GoTo refocus runtime-verified in Phase 3 |
| **T23** | Font dialog improvements (ux T-8, G-4): architect spike — enumerate system families through the cosmic-text stack (no new crate if avoidable); weight/style **only if** `Font{weight,style}` plumbing + config fields prove straightforward (config-version handling = architect's call, defaults preserved); ux — dialog UI (keep free-text family + size list); **no live preview** (accepted deviation; ux adds it to ux.md §7 when scope locks). Family enumeration (and any weight/style config fields) must update T12's locked FONT_FAMILIES/settings tests — Architecture-owned file — **in the same commit** (reviewer requirement). Final scope locks after reviewer input. | ux (+architect spike/config) | T12 (settings tests guard config changes) | Families enumerated from system; scope deviations documented; persistence tests green |

### Stage F — deferred / conditional / CI

| ID | Task | Owner | Depends | Done when |
|---|---|---|---|---|
| **T24** | *(Conditional — reviewer-gated)* Clipboard payload seam (arch T10): extract pure `selection_text()` used by Cut/Copy so the payload itself is assertable. Runs **only if** the reviewer requires payload-level proof. | architect | T09 | Reviewer requirement satisfied or task formally skipped |
| **T25** | CI (P2-T7): `scripts/ci.sh` + `.github/workflows/verify.yml` per packaging.md §5 (timeouts, bundle artifact; caches keyed on Cargo.lock and runtime versions — **plus the RV-16 fix: version-keyed caches must not mask BaseApp//stable commit drift, so key on the `flatpak info -c` commit, time-bust, or add a periodic fresh-install leg**). Local-only — no push (lead constraint). | packager | T08 (ideally after Stage E so the gate set is final) | ci.sh green locally; workflow validated; BaseApp-drift detection mechanism named in the workflow |
| **T26** | Deferred DECISIONS entries (P2-T8 residue — items c/d/e already recorded as D12/D6/D9): (a) portal talk-name removal **only after the Phase-3 portal FileChooser check passes with the talk-name removed** (RV-2: the smoke test never opens a dialog and cannot produce this evidence; D12 amended accordingly) — otherwise it stays permanently; (b) settings-daemon talk-name add-or-not after Phase 3 desktop evidence. | lead | Phase 3 | DECISIONS.md updated |

---

## 6. Phase 3 — harden (reviewer-led)

Entry: all Stage A–F tasks complete, each committed with sign-off.

1. Reviewer leads a **full verification pass against the running Flatpak**
   (built by verify.sh step 9, smoke-installed per D13).
2. Walk the **entire ux.md §1 parity checklist**, ticking every row with a
   verification note (method U/M/S/R recorded per row).
3. **Try to break every flow**: F1–F22 at runtime where automatable; the nine
   ux.md §3 user flows manually; the packaging.md §7 non-COSMIC matrix (GNOME/
   KDE/unset `XDG_CURRENT_DESKTOP` legs, config hot-reload via file-watch
   fallback, portal FileChooser dbus-proxy check, Open-With from a host file
   manager, icon/theme lookup, single-instance step S2, X11-only leg).
4. Re-run `scripts/verify.sh` from a **fresh clone** (project DoD).
5. Every failure is filed as a new task (same DoD + sign-off discipline);
   repeat until a full pass is clean.
6. Lead writes `docs/migration/REPORT.md`: what was built, deviations + why
   (UX-D*, DECISIONS D*), known limitations (task opacity R2, undo cap R7,
   single-instance race R9, BaseApp drift), and build/run/install instructions.

**Project definition of done** (charter): every parity item ticked and verified
in the running Flatpak; `scripts/verify.sh` passes from a clean checkout; the
Phase-3 pass found no failures; REPORT.md written. The lead does not declare
finished until all four hold.

---

## 7. Revision log

- Rev 1 (2026-09-11): initial consolidation of ux.md rev 2, architecture.md,
  packaging.md (revised), DECISIONS.md D1–D14.
- Rev 2 (2026-09-11): all 14 findings of `review-phase1.md` (0 BLOCKER /
  1 MAJOR / 8 MINOR / 5 NOTE) accepted and folded in per lead rulings:
  RV-1 → T09 scope (MenuAction map test); RV-2 → T26(a) rewired to Phase-3
  evidence + D12 amended; RV-3 → Stage D preamble (47+1 variants); RV-4 →
  T11 (F1) / T12 (F20); RV-5 → T12 invalid-config-fallback test; RV-6 →
  T05 license build-command pin; RV-7 → T22 GoTo refocus; RV-8 → T17
  (consume `app-comment`, delete `app-keywords`, zero-unused-keys criterion);
  RV-9 → T18/T19/T22 marked cross-boundary; RV-10 → doc-owner wording;
  RV-11 → D1/D3 corrections; RV-12/13/14 → UX-D9/D10/D11 deviations (ux.md
  §7) + T10 code comment. Doc-owner fixes (architecture.md rev 2, ux.md rev 3,
  packaging.md revised) confirmed by all three owners in the same pass;
  Phase-2 readiness declared READY by the reviewer.
- Rev 3 (2026-09-11): reviewer's PLAN.md-scope addendum folded — RV-15
  (gate-ramp seams codified in §2.3: T06 as retroactive Flatpak gate for
  T01–T05, T05's reliance on T06 stated, post-T08 skip-authority criteria),
  RV-16 (BaseApp//stable drift: cache-key fix → T25, risk 9 reworded), RV-17
  (§3.1 U+2029 N/A annotation + UX-D9 cross-ref). Residuals closed: §3.1
  closing sentence 47-of-48 (RV-3), T17 cross-boundary mark (RV-9 as
  amended), T20 predicate test home, T21 About-drawer suppression note, T23
  same-commit test-update requirement. All 17 findings (0 BLOCKER / 1 MAJOR /
  10 MINOR / 6 NOTE) dispositioned; reviewer's verdict upgraded to ACCEPT
  against rev 3 (review-phase1.md, final: all findings closed with disk refs).
- Rev 4 (2026-09-11): §2 rule 2 clarified on a lead ruling first applied at
  T02 — the plan note licenses editing to start; the reviewer's objection
  window is the right to stop work in flight (owner pauses at the point of
  objection; disagreement protocol applies), not a clearance gate to await.
