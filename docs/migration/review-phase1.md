# review-phase1.md — Devil's-advocate review of the Phase 1 documents

Reviewer: devil's-advocate teammate. Date: 2026-09-11. Branch `cosmic-migration`
@ 776b74d (source tree untouched at review time — `git status` shows only
untracked `docs/`; lead commits after sign-off per D4).

**Scope.** Adversarial review of `docs/migration/ux.md` (790 lines, rev 2),
`docs/migration/architecture.md` (872 lines, post-ruling revision),
`docs/migration/packaging.md` (437 lines, revised), their consistency with
`DECISIONS.md` (D1–D14; 381 lines at review time, amended to 393 during it),
and — per the lead's scope addition of 2026-09-11, received mid-review —
`PLAN.md` as a formal review input. Rev 1 (248 lines) is what the verdicts and
RV-1…RV-14 below were written against; the lead revised it to rev 2 (266
lines), folding in all 14 findings while this review was being amended —
every fold-in re-verified before delivery (see the rev-2 addendum under the
PLAN.md verdict and the status table in the closing section). Eight dimensions
per the reviewer brief:
parity-claim spot-checks, citation verification (v3 tree, v2.0.4 cache,
libcosmic d4d71fd checkout), a11y/i18n, sandbox, untested paths, dependency
pins, buildability sequencing, decision-log consistency.

**Method.** All Phase-1 docs read in full; ~50 v3-repo citations, ~35 v2.0.4
citations, and ~20 libcosmic-checkout citations re-checked at the cited
file:line; every quantitative claim (variant/field/test/key/bind counts, lock
pins, manifest lines) re-derived from source; the full verification gate
re-run live (results below). No source, git, or flatpak state was modified.

**Severity scale.** BLOCKER = must fix before Phase 2 starts / plan is wrong.
MAJOR = must fix within Phase 2, needs a task or scope edit. MINOR = should
fix (doc/scope corrections). NOTE = informational.

---

## Verdicts

### ux.md — ACCEPT WITH OBJECTIONS

The parity inventory is the strongest of the three documents: every v2.0.4
citation I re-checked (~30 across `window.py`, `commands.py`, `application.py`,
`theme.py`, `main.py`, and all five v2 test files) is accurate at the cited
lines, the G-/A-/D- inventories match the code as it stands today, and the
lead-ruling log (§6) is faithful to DECISIONS.md. Objections: the §4 summary
undercounts dead ftl keys (RV-8), one v2 behavior inside a cited line range —
editor refocus after successful Go To (`window.py:588`) — never becomes an
inventory item or task (RV-7), and two small v2 affordances appear in no
inventory at all (RV-13, RV-14). None of these undermine the checklist's role
as the Phase-3 verification source.

### architecture.md — ACCEPT WITH OBJECTIONS

The load-bearing thesis (headless Message-level testability) is not merely
plausible but empirically demonstrated (8/8 spike, R10 settled byte-faithful
CRLF), and the evidence chain in §3.2 checks out citation-by-citation against
the d4d71fd checkout — including the subtle ones (const `THEME` defaulting
Dark, `Content<R>` inference bound, lazy-task opacity, `main_window_id()`
short-circuit). The §2.3 matrix is complete against the actual `Message` enum
(48/48 verified by count), and the T-partition covers 47 of 48 variants with
#40 excluded by an explicit, justified hard rule. Objections: Appendix A
falsely marks the MenuAction map as test-locked today and no task owns a test
for it (RV-1, the review's only MAJOR); flow-assignment bookkeeping drops F1
and F20 between tasks (RV-4); the invalid-config-fallback contract PLAN.md
attributes to T12 is in no task text (RV-5); "all 48 variants" phrasing in
PLAN.md contradicts the #40 exclusion (RV-3); Appendix B overstates what the
smoke test can verify (RV-10).

### packaging.md — ACCEPT WITH OBJECTIONS

The §1 audit is reproducible: I re-ran its failing checks and got the cited
outputs verbatim (`desktop-file-validate` error text, `appstreamcli`
`unknown-provides-item-type binaries` info), and its pin citations are exact
(`Cargo.lock:2738-2740` libcosmic rev, manifest L27-29/L44-50, justfile vendor
recipe, `rust-toolchain.toml` exists as claimed). The vendoring plan (D9) is
internally consistent with the justfile recipe and honestly rejects the
committed-tarball option on measured size grounds (943 MB > GitHub's 100 MB).
The smoke design's self-corrections (path C rejected, `--installation` disproved
→ D13) are documented with evidence. Objections: the portal talk-name removal
is conditioned on evidence the smoke test cannot produce (RV-2), and the
license-installation test pins the justfile while the Flatpak's actual install
path is the manifest, which nothing pins (RV-6).

### DECISIONS.md consistency — ACCEPT WITH OBJECTIONS

D1–D14 are mutually consistent and faithfully reflected in the three docs and
PLAN.md task wiring (I traced every D# to its implementing tasks: D6→verify.sh
/T08, D7→T01, D8→T03, D9/D10→T05, D11/D13→T07, D12→T04, D14→T03). The
architecture §5.5 citation of "D12" for the settings-daemon talk-name deferral
is correct — the deferral is recorded in D12's "Deferred until evidence
exists" block, which I initially suspected as a mis-citation and verified is
not. Objections — both fixed in DECISIONS.md during the review pass and
re-verified (D1 now carries an RV-11 correction note and D3's heading is
marked historical; D12 carries an RV-2 amendment rewiring the talk-name
condition to the Phase-3 portal check, DECISIONS.md:312-319): D1's
parenthetical asserted v2.0.4 is "still installed as a user Flatpak",
contradicted by the D3 addendum with no cross-reference (RV-11), and D12's
smoke-evidence condition for the portal talk-name was unsatisfiable as
written (RV-2).

### PLAN.md — ACCEPT WITH OBJECTIONS

*(Added per the lead's scope addition, 2026-09-11.)* The consolidation is
faithful: I traced every architecture T1–T10, ux T-1–T-10, and packaging
P2-T1–T8 to PLAN rows with no loss, duplication, or contradiction
(T1→T01, T2→T02, T3→T03, T4→T09, T5→T10, T6→T11, T7→T12, T8→T13, T9→T14,
T10→T24; T-1→T21, T-2→T15, T-3→T18, T-4→T19, T-5→T20, T-6→T03, T-7→T17,
T-8→T23, T-9→T16, T-10→T22; P2-T1→T01, P2-T2→T04, P2-T3→T05, P2-T4→T06,
P2-T5→T07, P2-T6→T08, P2-T7→T25, P2-T8→T26). The ID-disambiguation
convention (UX-D# vs DECISIONS D#) is good hygiene, §2.5 restates the binding
safety constraints correctly, and §6's Phase-3 protocol contains the portal
FileChooser check that RV-2 asks to rewire T26(a) onto. Objections (stated
against rev 1; see the rev-2 addendum after point 4 for what the in-review
revision closed): D5 ownership under-marked on four Stage-E tasks (RV-9,
amended — rev 2 marks T18/T19/T22, T17 remains), the gate ramp has three
seams needing codification (RV-15), risk 9's CI mitigation is overclaimed
(RV-16), §3.1 has two silent omissions (RV-17), and rev 1 inherited the
RV-2/3/4/5 defects noted under the source docs (all closed in rev 2 except
one residual RV-3 sentence).

**Lead's four priority scrutiny points:**

1. **§5 ordering.** Sound. No task leaves the tree unbuildable or gate-red:
   every change is additive (new test files, new scripts) or API-preserving
   (T01 deletes only verified-dead code plus its sole-caller test; T13 keeps
   `subscription()` delegating; T05's rev pin matches the existing lock
   resolution, so `Cargo.lock` and `--locked` are untouched). Dependency
   edges verified correct, including the subtle ones: T03 before T11 (D8
   behavior exists when the file-lifecycle suite runs), T21 after
   T18/T19/T10 (the subscription cannot fight the focus work; find-bar
   message behavior locked first), T04→T05 serializing the two
   `tests/packaging.rs` edits, T13 parallel-safe (different file, no T02
   reliance), T23 after T12 (config changes guarded by persistence tests).
   **Stage-D-before-E is structurally sound for a specific reason worth
   recording:** Stage-D tests assert state/flags, and iced `Task`s are opaque
   (R2), so Stage E's task-level and subscription changes (T18/T19/T21)
   cannot break them — the tests lock behavior without freezing the
   view/focus layers. D5 conflicts the consolidation missed: RV-9
   (T17/T18/T19/T22), including that T18 may add an `Id` field to the `App`
   struct — Architecture region.
2. **§2.3 gate ramp.** A faithful adaptation, not a shortcut: the cargo gates
   (fmt/build/clippy/test) are never relaxed for any task; T04's done-when
   runs the exact validators flatpak-builder would run on the files it edits;
   the scripts genuinely do not exist before T07/T08, so earlier "gates"
   would be manual re-enactments; and T06/T07 re-run everything on a tree
   containing all Stage A/B changes. Three seams need codifying — see RV-15
   (retroactive-gate language; in-task flatpak-builder for pre-T06
   manifest/dependency edits; post-T08 skip criteria). With those, the ramp
   satisfies the charter's intent.
3. **§3.1 coverage map.** Cracks found: the invalid-config-fallback contract
   is claimed for T12 but scoped in no task text (RV-5); the
   paragraph-separator test and the casefold nuance are silently absent
   rather than marked N/A (RV-17, RV-12). Everything else across all five v2
   files maps correctly (accessible name → T15; focus/select-all → T18/T19
   with the honest manual-verify caveat; second-instance → T11/T14;
   persistence → T12; packaging → locked + T04/T05 extensions).
4. **T20/T21/T23 splits.** Workable as written. T20: the D5 sequencing (one
   owner edits, the other reviews, single combined diff) is exactly right;
   suggest naming where the predicates *and their tests* land — T09 is their
   natural home — so the scope isn't orphaned. T21: the cleanest of the
   three — architect owns subscription/routing (state region), ux owns
   binding-table parity and focus verification; the two design constraints
   (`Status::Ignored` filtering, `pending.is_some()` suppression) are
   empirically checkable at task time and the done-when says so; note the
   suppression deliberately does not cover the About drawer (no v2 modal
   analog) — acceptable, worth one line in the task record. T23: joint
   ownership fine; add one sentence that when enumeration replaces the
   static 14-family list, T23 must update T12's locked settings tests
   (`FONT_FAMILIES`/`FontFamily(index)`/seeding assertions —
   Architecture-owned file) in the same commit.

**Rev-2 addendum (fold-in verification).** PLAN.md was revised to rev 2
(266 lines) mid-review, accepting all 14 original findings. I re-read every
fold-in at its target and all are faithful: T09 MenuAction scope + done-when
marker (RV-1); T26(a) Phase-3 condition matching the D12 amendment text
(RV-2); Stage-D preamble "47 of the 48 … #40 excluded by design … reviewer
sign-off granted" (RV-3); T11 "F1–F13, F22 (F1 new-clean added per RV-4)" and
T12 "+ F20" (RV-4); T12 invalid-config-fallback test with the v2 citation
(RV-5); T05 license-build-command pin with rationale (RV-6); T22 refocus +
cross-boundary mark (RV-7); T17 consume-`app-comment` / delete-`app-keywords`
+ zero-unused-keys criterion — arithmetic closes: 4 unused − 2 named by
T15/T16 − 1 consumed − 1 deleted = 0 (RV-8); T18/T19/T22 cross-boundary marks
(RV-9, partial); PLAN §3 UX-D9/D10/D11 + T10 code comment (RV-12/13/14);
DECISIONS D1/D3/D12 amendments (RV-11, RV-2). Two residuals: **T17 is still
not marked cross-boundary** although its `About` data lives in `init`
(Architecture region — amended RV-9), and **§3.1's closing sentence (line
~121) still says "all 48 Message variants"** although the Stage-D preamble
was fixed (RV-3 residual). **Verdict for rev 2: ACCEPT WITH OBJECTIONS** —
open items are RV-9(T17), RV-3(§3.1 sentence), RV-15, RV-16, RV-17; none
blocks T01, and the fold-in quality (14/14 faithful, 2 textual residuals) is
itself evidence the consolidation process works.

---

## Findings

*Status note: RV-1…RV-14 were written against PLAN.md rev 1 and the pre-fold
state of the other docs; all 14 were accepted and folded in during the review
pass (PLAN rev 2, DECISIONS amendments, doc-owner corrections requested).
Findings are kept as written for the record — per-finding fold-in status and
residuals are tabulated in the closing section. RV-15…RV-17 arise from the
PLAN.md scope addition and are open against rev 2.*

### RV-1 — MAJOR — architecture.md Appendix A ("Menus" row) + PLAN.md T09
**Claim is false today, and the gap is unowned.** Appendix A marks Menus
"structure 🔒 via MenuAction map (198–227)"; the legend (architecture.md:797)
defines 🔒 as "implemented + test-locked today". No test of the
`MenuAction`→`Message` map exists: `src/app.rs`'s only tests are
`intern_family`, `offset_to_position_snaps_mid_utf8`, and `cursor_end`
(app.rs:1495-1527), `src/commands.rs` has 22 search-function tests,
`single_instance.rs` has 3 — none touch `MenuAction`. No Phase-2 task covers
it either: PLAN T09's "key-binding map unit test" is the `key_bind`/
`editor_key_binding` map (the "Keyboard shortcut set" row, correctly marked
🧪 T4), not the menu-action map. Contrast the sibling rows, which are honest
(🔒 only where tests exist: commands, single_instance client, caret corpus,
packaging).
**Action:** demote the Menus row to 🧪 and fold a pure-fn test of
`MenuAction::message()` (all 22 variants → expected `Message`, and the
`aligned_disabled_item` Go-To case) into T09's scope. Cheap; closes the last
unowned coverage claim in the normative docs.

### RV-2 — MINOR — PLAN.md T26(a), packaging.md P2-T8(a), DECISIONS.md D12
**Evidence condition for a sandbox-permission change is unsatisfiable as
written.** All three wire "drop `--talk-name=org.freedesktop.portal.Desktop`"
to what the *smoke test* proves ("after T07 evidence"; D12: "only removed
after the smoke test proves file-chooser/portal function without it"). The
smoke test (D11/T07) exercises launch → 10 s liveness → SIGTERM → clean exit
with a panic-regex on stderr; it never opens a file dialog, so it cannot
prove portal function either way. Acting on the condition literally would
change a priority-2 property (works in the Flatpak sandbox) on zero evidence.
Mitigations exist: flatpak's bus proxy auto-allows `org.freedesktop.portal.*`
(D12 itself says "likely redundant"), and PLAN §6.3 already schedules a
"portal FileChooser dbus-proxy check" in Phase 3 — which *does* exercise the
portal.
**Action:** rewire T26(a)/P2-T8(a)/D12's condition from "after T07/smoke" to
"after the Phase-3 portal FileChooser check passes with the talk-name
removed", or keep the talk-name permanently (minimality gain is one line).

### RV-3 — MINOR — PLAN.md §5 Stage D preamble (line ~175) vs architecture.md R3/§2.3 #40
**"T09–T14 cover all 48 Message variants" overstates by one.** #40
`LaunchUrl` is deliberately never driven in tests (immediate
`open::that_detached` side effect; hard rule in §3.4/§3.6, risk R3). The
exclusion is correct and well-argued — but the PLAN sentence, read alone
against the charter's "every Message variant" mandate, promises something the
plan doesn't do.
**Action:** reword to "47 of 48 variants driven; #40 `LaunchUrl` excluded by
design (R3), manual/smoke coverage only". As reviewer I hereby sign off on the
#40 exclusion as charter-compliant (documented, justified, externally covered).
*Status (rev 2): Stage-D preamble fixed as asked; §3.1's closing sentence
("T09–T14: all 48 Message variants", line ~121) still needs the same reword.*

### RV-4 — MINOR — architecture.md §7 T7 & Appendix A row 814; PLAN.md T12/T14
**F1 and F20 fall between task texts.** Appendix A assigns the Ln/Col app-side
flow "🧪 T7 (F20)", but §7 T7's text and PLAN T12 list only F17–F19. F1
(new-clean) appears in no task's flow list (T6/T11 start at F2); both survive
only via PLAN T14's done-when catch-all ("All F1–F22 have at least one
test"), which invites late rework in the last coverage task.
**Action:** add F20 to T12's flow list and F1 to T11's (F1 is nearly free —
it is #2's clean branch plus a title assert).

### RV-5 — MINOR — PLAN.md §3.1 (`test_theme.py` row) vs T12 text / architecture.md §5.6
**Invalid-config fallback contract is claimed but not scoped.** PLAN §3.1 says
the v2 contract "color-scheme default/roundtrip/**invalid-fallback**" maps to
T12; v2 pins it at `test_theme.py:311-313` (bogus value → SYSTEM). Neither
T12's task text nor architecture §5.6/T7 lists such a test. The v3 behavior
exists (per-field `get_entry` defaults, `unwrap_or_else(|(_, c)| c)` at
app.rs:302-309) but is untested.
**Action:** add to T12 scope: write a malformed RON value under a
`with_custom_path` tempdir, construct via the seam, assert field default +
app functionality (the direct descendant of v2's `test_invalid_value_falls_back_to_system`).

### RV-6 — MINOR — tests/packaging.rs:24-30 + packaging.md audit row 16
**The license-install test pins the file the Flatpak build does not use.**
`license_material_is_installed_with_the_application` asserts on `justfile`,
but flatpak-builder runs the manifest's `build-commands` (L44-50) — the
justfile `install` recipe is host-only. v2's equivalent test pinned
`meson.build`, which *was* its real build system. Today, deleting manifest
L49-50 (the actual `/app/share/licenses/...` installation) keeps all 34 tests
green. Audit row 16 cites both locations but overstates enforcement
("content enforced by tests/packaging.rs:11-30").
**Action:** in T04 or T05, extend `tests/packaging.rs` to assert the manifest
build-commands contain the `LICENSE`/`COPYRIGHT` install lines (keeps the
justfile assertion for host installs). GPL-compliance relevant, ~6 lines.

### RV-7 — MINOR — ux.md §3.7/§1.4 + PLAN.md T22 (parity gap; see also "Gaps" §)
**v2 returns keyboard focus to the editor after a successful Go To
(`window.py:588`, `self.edit.setFocus()`); nothing in v3 does or is asked to
verify it.** ux.md §3.7 cites the very range (`window.py:579-588`) but
describes only seeding and select-all; the v3 column records the inline-error
delta and the missing entry select-all (→ T22), not post-confirm focus.
`confirm_goto` (app.rs:1207-1240) closes the dialog and moves the cursor with
no focus task; whether COSMIC returns focus to the editor when a dialog
unmounts is unproven. If it doesn't, a keyboard user who presses Ctrl+G,
types "300", Enter, lands the cursor but cannot type — exactly the regression
class T-3/T-4 fix for the find bar.
**Action:** add "focus returns to editor on GoToConfirm success" to the ux.md
§3.7 delta and to T22's scope (same `Id`+focus-task mechanism as T19);
runtime-verify (M/R) in Phase 3.

### RV-8 — MINOR — ux.md §4 summary point 2 (line ~539)
**"Two defined-but-unused strings" undercounts: four ftl keys are never
referenced in `src/`.** Re-derived mechanically (every key in
`i18n/en/notepad.ftl` grepped as a string literal across `src/`): unused =
`app-comment` (ftl:2), `app-keywords` (ftl:3), `close-find` (ftl:41),
`color-scheme-button` (ftl:57). ux.md's own table maps app-comment/app-keywords
to *static desktop-file text* — a correspondence, not a use; the ftl entries
are dead code. PLAN T17 "may consume" `app-comment`; nothing consumes
`app-keywords`.
**Action:** correct the count; give `app-keywords` a consumer (About drawer or
metainfo `<keywords>` generated path) or record deliberate duplication with a
cleanup decision, so T15/T16's "no unused-key regression" done-criterion has
an accurate baseline.

### RV-9 — MINOR — PLAN.md T17/T18/T19/T22 vs DECISIONS.md D5
*(Amended in the PLAN.md scope-addition pass: two further tasks of the same
class.)*
**Four Stage-E tasks edit Architecture-owned regions under UX-only owner
lines.** T18 changes what `update()` returns for `Find`/`Replace` (focus task
instead of `Task::none` — the update arm is Architecture's region per D5; a
stable `Id` may also add an `App` struct field — also Architecture's). T19
edits `on_escape` (app.rs:869-884 — a lifecycle hook, explicitly
Architecture's). T17 populates the `About` data built in `init`
(app.rs:311-316 — `init` is Architecture's region; only the `context_drawer`
rendering is UX's). T22 needs the `GoToConfirm` success arm (update() region —
entry select-all task, plus editor refocus per RV-7) and possibly the
`OpenExternal` raise path (app.rs:642-648). T20/T21/T23 correctly name their
splits; these four don't, and PLAN §2.2's "at most one teammate modifies the
shared tree" plus D5's "one owner edits, the other reviews" then apply by
accident rather than by plan.
**Action:** mark T17/T18/T19/T22 cross-boundary in PLAN.md (architect edits
the state-region lines or co-signs a single combined diff; ux owns the
focus/copy semantics and verification).
*Status (rev 2): T18/T19/T22 now carry cross-boundary marks with the
edit/co-sign protocol — fold-in faithful; T17's mark is still missing.*

### RV-10 — NOTE — architecture.md Appendix B (`test_window.py` row)
"widget *focus* not unit-testable → smoke" over-promises: the smoke test's
pass criteria (liveness/termination/panic-regex) contain no focus assertion
and cannot. The real vehicle is Phase-3 manual verification — PLAN §3.1
already says "smoke/manual verify". Align the Appendix B wording so nobody
believes focus regressions are machine-caught.

### RV-11 — NOTE — DECISIONS.md D1 (line 38)
D1 still describes v2.0.4 as "tagged in git and still installed as a user
Flatpak" — falsified by the D3 addendum (exhaustive search: no 2.0.4 Flatpak
anywhere). The decision itself (Option B, verify-and-harden) is unaffected.
Add a one-line cross-reference to the D3 addendum so D1 read in isolation
doesn't misinform. (Same for D3's header "Protect the installed v2.0.4
Flatpak", which the addendum directly beneath already corrects.)

### RV-12 — NOTE — src/commands.rs:81 vs v2.0.4 src/commands.py (`selection_matches`)
v2 compares with Python `casefold()` (full Unicode case folding: `"ß" →
"ss"`); v3 uses `to_lowercase()` (per-char simple mapping: `"ß"` unchanged).
Observable only for exotic Unicode (Replace treating a selected "ß" as
matching needle "ss", etc.). Std has no casefold; adding a crate conflicts
with D9's vendoring-cost discipline and priority 4.
**Action:** record as an accepted micro-deviation (ux.md §7) and a code
comment in `commands.rs`; no behavior change.

### RV-13 — NOTE — parity gap: find-entry clear button
v2's find entry enables the QLineEdit clear button (`window.py:72`,
`setClearButtonEnabled(True)`) — an ✕ affordance inside the field. Not in any
ux.md inventory; iced/cosmic `text_input` has no built-in equivalent.
Recommend an accepted-deviation line in ux.md §7 (workaround: select-all +
delete; T18's select-all-on-open covers the common case).

### RV-14 — NOTE — parity gap: `NOTEPAD_ICON` env override
v2 resolves the window icon via `_find_icon` with a `NOTEPAD_ICON` environment
override (`application.py:27-48`); v3 embeds the SVG (`app.rs:311-316`). A
dev/packaging affordance, not user-facing. Recommend one accepted-deviation
line in ux.md §7 so the omission is deliberate and visible.
*Status (rev 2): recorded as UX-D11 in PLAN §3; the ux.md §7 row rides the
doc-owner pass.*

### RV-15 — MINOR — PLAN.md §2.3 (gate ramp)
**The ramp is a faithful charter adaptation, but three seams are
under-specified.** The charter's per-task DoD names flatpak-builder + smoke
for every task; §2.3 defers them to T06/T07 and adopts full verify.sh from
T08 — defensible (verdict point 2: the cargo gates never relax, the scripts
genuinely do not exist earlier, T04 runs the file-level validators itself,
T06/T07 re-gate everything on a tree containing all Stage A/B work), but
three seams should be closed in the plan text: (a) T06 is never declared the
*retroactive* Flatpak gate for T01–T05; (b) a pre-T06 task editing the
manifest or dependency resolution (T05 does both) lands on host-cargo evidence
alone — T05's done-when omits flatpak-builder, so the malformed-manifest
class is caught only at T06 (tolerable: same owner, immediately after — but it
should be a stated choice, not an accident); (c) the post-T08 skip authority
("reviewer-signoff note") has no criteria, making it ad hoc per task.
**Action:** add three sentences to §2.3: T06 is the retroactive Flatpak gate
for Stages A/B; any pre-T06 manifest/dependency edit either runs
flatpak-builder in-task or records T06 as its coverage; skip criteria = diffs
touching only `src/` regions under Architecture/UX ownership may skip steps
5–10 with a signoff note (steps 1–4 always run), everything else runs all 10.
(Matches the standing commitment in the closing section — makes it plan text
rather than reviewer custom.)

### RV-16 — MINOR — PLAN.md §4 risk 9 vs T25 / packaging.md §5 (CI cache)
**"CI smoke catches [BaseApp] breakage" does not hold on the cached leg.**
Risk 9's mitigation leans on CI smoke to catch `com.system76.Cosmic.BaseApp//stable`
drift, but T25's caches are "keyed on Cargo.lock/runtime versions" and the
path-B smoke installation (~1.2 GB) is persisted precisely to avoid
re-pulling — and `BaseApp//stable` can move commits under an unchanged version
string (today's `b3f1b274d540` is recorded in risk 9 itself because it cannot
be pinned). A warm cache therefore never invalidates on drift, and the
claimed detection is inert exactly when it is needed. packaging.md §5 already
contains the fix as an alternative (ephemeral runners, `NOTEPAD_SMOKE_FAST=1`,
fresh install per run), but neither risk 9 nor T25 names a drift-catcher.
**Action:** in T25, key the smoke-installation cache on the BaseApp commit
(`flatpak info -c com.system76.Cosmic.BaseApp//stable`), or add a time-based
bust (week number in the key), or schedule a periodic fresh-install leg;
amend risk 9's mitigation to name the actual mechanism.

### RV-17 — NOTE — PLAN.md §3.1 (ported-test coverage map)
**Two v2 test contracts are silently absent from the map rather than marked
N/A.** (1) `test_commands.py:122-127` (`selected_text` normalizes Qt's U+2029
paragraph separators before comparison) — genuinely inapplicable to v3
(`Content`/cosmic-text has no U+2029 notion; documents carry `\n`/`\r\n`),
but the `test_commands.py` row omits it instead of saying so, and a Phase-3
auditor walking the v2 suite line-by-line will trip on it. (2) The
case-insensitivity *mechanism* of `selection_matches` — v2 `casefold()` vs v3
`to_lowercase()` — is now recorded project-wide as UX-D9 (rev 2, from RV-12),
but the §3.1 row's contract list carries no cross-reference to it.
**Action:** one N/A annotation and one UX-D9 cross-reference in the §3.1
`test_commands.py` row (or architecture Appendix B).

---

## Verifications performed

All commands run 2026-09-11 on branch `cosmic-migration` @ 776b74d, read-only
(no source/git/flatpak mutations; GIO noise filtered where noted).

**Gate re-run (live results):**

| Check | Result | Matches docs? |
|---|---|---|
| `cargo fmt --check` | exit 0 | ✅ (D6 addendum claim) |
| `cargo build --locked` | exit 0 | ✅ |
| `cargo clippy --locked --all-targets -- -D warnings` | exit 101, **exactly one** error: `double_must_use`, attribute at `src/config.rs:43`, fn at 44 | ✅ D7/R1 baseline, precise |
| `cargo test --locked` | 28 unit (22 commands + 3 single_instance + 3 app) + 6 packaging, all green | ✅ Appendix B totals |
| `desktop-file-validate data/...desktop` | exit 1: `unregistered value "COSMIC"` | ✅ verbatim = packaging.md:381-383, D12 |
| `appstreamcli validate --no-net data/...metainfo.xml` | exit 0, 1 info: `unknown-provides-item-type binaries` (:37) | ✅ D12/T04 premise exact |
| `jq` manifest sanity (`finish-args`, `runtime-version`) | OK | ✅ |
| ftl key usage sweep (`grep -F '"<key>"' src/` for all 69 keys) | unused: `app-comment`, `app-keywords`, `close-find`, `color-scheme-button` | ⚠ ux.md §4 says two → RV-8 |

**Counts re-derived from source:** 48 `Message` variants (app.rs:115-164); 22
`MenuAction` (173-196); 24 `App` fields (87-110); 17 key binds
(`key_bind.rs:10-96`); 69 ftl keys; 14 `FONT_FAMILIES` / 14 `FONT_SIZES`
(index 5 = 14pt); `MAX_UNDO_DEPTH = 100` (app.rs:1444). T09∪T10∪T11∪T12
variant union = {1,10-16,29,30} ∪ {17-28} ∪ {2-9,42-45,47-48} ∪
{31-39,41,46} = 47, + #40 excluded (R3) = 48 ✅ (→ RV-3 phrasing).

**libcosmic d4d71fd citation spot-checks (~20, all accurate):**
`src/app/mod.rs:18` (`Task<M>` alias), 323/348/465 (trait/init/update);
`src/core.rs:133` (`impl Default for Core`), 386 (`watch_config`), 453
(`main_window_id`); `src/theme/mod.rs:47-52` (const `THEME`,
`ThemeType::Dark` default), 182 (`#[must_use]`); `src/command.rs:36`
(`set_theme`); `iced/core/src/text/editor.rs:70` (`enum Action`), 105
(`enum Edit`, no Undo variant); `iced/widget/src/text_editor.rs:397-399`
(`Content<R = crate::Renderer>(RefCell<Internal<R>>)`), 468 (`text()`);
`iced/graphics/src/text/editor.rs:89` (`with_text`), 120-131 (per-line
`line()` range — boundary-consistent); `iced/runtime/src/clipboard.rs:64/84`
(read/write signatures exactly as §3.3 records); `iced/runtime/src/window.rs:291`
(`close_requests`); `src/dialog/file_chooser/mod.rs:123` (`enum Error`);
`src/task.rs:17`; `cosmic-config/src/lib.rs:215` (`new`), 253
(`with_custom_path`); `src/app/cosmic.rs:512/591/887/922/1081/1243-1252`
(dispatch, Escape→`on_escape`, theme, Close, `on_close_requested`+`iced::exit`
batch). `Cargo.lock:2738-2740` pins exactly
`d4d71fd53e5ed6bd3a430089114dffa2da3cd498` ✅; `Cargo.toml` has **no** rev ✅
(D10 premise true); `rust-toolchain.toml` exists (channel stable + clippy +
rustfmt) ✅ (packaging.md step-1 note accurate).

**v2.0.4 citation spot-checks (~35, all accurate):** every ux.md-cited range in
`window.py` re-read (68-72, 87-99, 207-210, 226, 265-361, 393-461, 484-509,
522-598, 600-711), `commands.py` (find/replace/goto/selection semantics incl.
`casefold`), `application.py` (socket protocol, forwarding, `_find_icon`),
`main.py:17-27`, `theme.py` (QSettings keys, palettes, load/save/effective),
and all five v2 test files read in full. Notable confirmations: v2 argv
filter (`abspath`, skip empty and `-`-prefixed) is **identical** to v3
`main.rs:33-37` — parity row holds; `test_window.py:43` pins
`accessibleName() == "Close Find"` (A-1 is a tested regression, correctly
prioritized); `test_theme.py:311-313` is the invalid-fallback contract (→
RV-5); `test_packaging.py` pinned *meson.build*, its true build system (→
RV-6 contrast).

**Cross-document wiring checks:** every DECISIONS D# traced to implementing
task(s) — no orphan decisions except the D1 stale phrase (RV-11); ux T-1…T-10
→ PLAN T15…T23/T03 mapping complete and order-preserving; arch T1…T10 → PLAN
T01/T02/T03/T09…T14/T24 mapping complete; T04 verified test-compatible
before the fact (the `<binaries>`→`<binary>` unwrap leaves both pinned
`<id>` strings intact; Categories is not pinned in `tests/packaging.rs`) ✅;
manifest L49-50 install LICENSE/COPYRIGHT ✅ (audit row 16 accurate, but see
RV-6).

**PLAN rev-2 / DECISIONS fold-in verification (post-amendment pass):** all 14
fold-ins re-read at their target locations (details in the rev-2 addendum
under the PLAN.md verdict) — 14/14 faithful. Residuals located: PLAN §3.1
line ~121 "all 48 Message variants" (RV-3); T17 owner line lacks the
cross-boundary mark (RV-9). Confirmed unchanged in rev 2 (findings open):
§2.3 ramp text (RV-15), risk 9 mitigation + T25 cache-key text (RV-16), §3.1
`test_commands.py` row contract list (RV-17). `git status`: only untracked
`docs/` — no tracked file modified on `cosmic-migration` @ 776b74d at any
point during the review.

---

## Parity gaps not in any inventory

Behaviors present in v2.0.4 source that no Phase-1 document lists as parity
item, deviation, or gap (searched: all four docs + PLAN.md, by symbol, line
number, and behavior description):

1. **Go To success refocuses the editor** — `window.py:588`
   (`self.edit.setFocus()` after a successful jump). Inside ux.md's cited
   range but never surfaced. → RV-7 (MINOR, task T22).
2. **Find-entry clear button** — `window.py:72`
   (`setClearButtonEnabled(True)`). → RV-13 (NOTE, accept as deviation).
3. **`NOTEPAD_ICON` environment icon override** — `application.py:27-48`
   (`_find_icon`). → RV-14 (NOTE, accept as deviation).
4. **`casefold()` full-folding in `selection_matches`** — v2 `commands.py` vs
   v3 `to_lowercase()`. → RV-12 (NOTE, accept + comment).

Checked and found **no** further gaps: argv filtering, single-instance wire
protocol and ack, stale-socket handling, present/raise on second instance
(inventoried — T22), datetime format, title/marker format, Ln/Col semantics,
wrap-disables-GoTo, replace-all single-undo-step, find wrap-around and
case defaults, strict-UTF-8 (inventoried — D8/T03), closeEvent guard chain,
theme persistence model, font free-text families, window default/min size.
Caveat: this is source-level verification only — live A/B runtime comparison
is unavailable (D3 addendum), so Phase-3 runtime checks remain the final
authority, exactly as the docs provide.

---

## Overall Phase-2 readiness

**READY — no BLOCKERs; 1 MAJOR, 10 MINOR, 6 NOTEs (17 findings, incl. the
PLAN.md scope addition).** The plan is unusually well-evidenced: the docs'
citations survived ~100 spot-checks across three codebases with a
near-perfect hit rate, the two riskiest premises (headless testability,
offline vendored build) are empirically settled rather than argued, and the
baseline state they describe reproduces exactly.

**Sequencing assessment (dimension 7).** The ordered task list keeps the tree
buildable and the gate meaningful at every step: T01 first (only gate-red
item, verified single-error); T02 lands the contested-file seam before any UX
view edit (R12 ruling honored by stage order B→E); T03 before T11 (D8 tests
need strict-UTF-8); T04→T05 serialize the two `tests/packaging.rs` edits; the
gate ramp (flatpak-builder from T06, smoke from T07, full verify.sh from T08)
matches D6/D9/D11; T13's parallelism note is dependency-correct (different
file, no T02 reliance); T21 correctly depends on T18/T19/T10 so the global
shortcut subscription cannot fight the focus work; T23 after T12 so config
changes are guarded by persistence tests. I found **no ordering that leaves
the tree unbuildable, gate-red, or edit-conflicted**; rev 2 closes the
original caveat (T18/T19/T22 now marked cross-boundary), leaving RV-9's T17
mark and RV-15's three §2.3 sentences as the only clarifications needed
before their stages start.

**Disposition status after PLAN rev 2 / DECISIONS amendments (2026-09-11).**
The lead accepted and folded in all 14 original findings during the review
pass; every fold-in was re-verified at its target (rev-2 addendum under the
PLAN.md verdict). Residual work, none of which reorders or restarts a task:

| Finding | Fold-in | Residual |
|---|---|---|
| RV-1 | ✅ T09 scope + done-when | architecture.md Appendix A Menus row 🔒→🧪 (doc owner) |
| RV-2 | ✅ T26(a) rewired; D12 amended (:312-319) | — |
| RV-3 | ✅ Stage-D preamble | §3.1 closing sentence still "all 48" (line ~121) |
| RV-4 | ✅ T11 (F1), T12 (F20) | architecture.md §7 T7 flow list (doc owner) |
| RV-5 | ✅ T12 invalid-config test | — |
| RV-6 | ✅ T05 license-pin scope | — |
| RV-7 | ✅ T22 refocus + cross-boundary mark | ux.md §3.7 delta row (doc owner) |
| RV-8 | ✅ T17 consume/delete + zero-unused criterion | ux.md §4 count fix (doc owner) |
| RV-9 | ⚠ T18/T19/T22 marked | **T17 cross-boundary mark missing** |
| RV-10 | — | architecture.md Appendix B focus wording (doc owner) |
| RV-11 | ✅ D1 correction note; D3 heading marked | — |
| RV-12 | ✅ T10 comment + UX-D9 in PLAN §3 | ux.md §7 row (doc owner) |
| RV-13 | ✅ UX-D10 in PLAN §3 | ux.md §7 row (doc owner) |
| RV-14 | ✅ UX-D11 in PLAN §3 | ux.md §7 row (doc owner) |
| RV-15 | new (scope addition) | open: three §2.3 sentences (lead) |
| RV-16 | new | open: risk 9 / T25 cache-key mechanism (lead; packager at T25) |
| RV-17 | new | open: two §3.1 annotations (lead) |

The lead-owned residuals (RV-3 sentence, RV-9/T17 mark, RV-15, RV-16, RV-17)
are five small PLAN.md text edits, all doable before T01 starts; the
doc-owner residuals ride the architecture/ux/packaging correction pass the
rev-2 log already requests.

**Reviewer standing commitments for Phase 2:** (a) I sign off on the #40
`LaunchUrl` unit-test exclusion (R3) as charter-compliant; (b) for Stage D/E
tasks whose diffs touch only Architecture/UX-owned `src/` files, I will grant
verify.sh step 5-10 skip notes on request (steps 1-4 always run), per PLAN
§2.3 — packaging-affecting diffs run all 10; (c) I will require the T02
`fl!`-without-`init` question (R5) and the `set_main_window_id` constant
(R15) to be settled *inside T02's record*, not deferred silently; (d) per D7,
T01's diff will be checked for absence of any `#[allow]`.

— reviewer, 2026-09-11
