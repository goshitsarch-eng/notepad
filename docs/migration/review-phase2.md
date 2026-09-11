# review-phase2.md — Reviewer log: Phase-2 per-task verification

Role: reviewer / devil's advocate (fourth teammate, lead-coordinated). Premise
(D1): the repo is a completed libcosmic rewrite (v3.0.0) of the Python/PySide6
v2.0.4 app; Phase 2 = verify / complete / harden via per-task plan-note windows,
diff sign-offs, and lead commits. Parity reference: `/home/gosh/.cache/notepad-v2.0.4/`
(read-only; no 2.0.4 Flatpak exists — live A/B off per the D3 addendum).

Phase-1 findings live in `review-phase1.md` (17 findings, RV-1…RV-17 numbering).
This log is the durable Phase-2 record: rulings, sign-offs, banks, and a
verified-anchor base that survives context compaction. **Citation convention
(PLAN §2 rule 6): symbol-first; line ranges are supporting anchors, valid
as-of-writing against the baseline below; re-verify against the live tree
before trusting any number here.**

**Anchor baseline:** branch `cosmic-migration`, HEAD `8e5b01a` (ux sync rev
3.1), 2026-09-11 — HEAD moves on lead commits; re-run `git log` before citing.
History (live-enumerated at 8e5b01a: 40 commits total, 22 atop baseline
776b74d): base 776b74d ← c885ca2 (DECISIONS D1–D14) ← 0386632 (ux inventory) ←
14f7760 (architecture) ← 3b41f57 (packaging audit) ← 9fcaf6a (Phase-1 review) ←
3e98f92 (PLAN rev 3) ← 37e6ec0 (ux sync) ← de2a1e5 (review-phase1) ← 8fb2e18
(PLAN front matter) ← 5ae4e6d (T01) ← 58fbb8a (rev 4) ← 419a140 (rev 5) ←
78b9e1f (T13) ← e1a61c3 (T02) ← 4bbf4f3 (rev 6) ← cea3201 (rev 7) ← 31c856d
(rev 8) ← b963dce (T03) ← a2dc94a (T04) ← 0297eb7 (rev 9) ← 48d603d (this log,
first rev) ← 8e5b01a (ux sync). NOTE: T05 execution is in flight in the working
tree (Cargo.toml/lock, manifest, packaging.md, tests/packaging.rs, scripts/) —
working-tree state below reflects HEAD 8e5b01a, not the churn.

---

## 1. Standing commitments and protocol toolkit

**Commitments (mine):**
- (a) architecture.md §2.3 row #40 LaunchUrl exclusion — signed off (Phase 1).
- (b) verify.sh steps 5–10 skip authority for src-only diffs from T08 (RV-15c).
- (c) R5/R15 (headless fl! + Flatpak-runtime pairing) — DISCHARGED at T02.
- (d) No-new-`#[allow]` check in every package census. Sole allow today:
  `clippy::too_many_lines` on the Editor arm (src/app.rs :563).

**Toolkit (hardened by incident):**
- Rev-5 quiescence: gates run only inside the owner's quiescent ping; proven by
  mtime-bracketing (`stat -c '%Y'` pre/post over the protected set).
- Pipeline exit codes via `${PIPESTATUS[0]}` / log redirects, never `$?` post-pipe.
- GIO/Gvfs host noise filtered with `GIO_MODULE_DIR=""` or `grep -v -E "gvfs|gio/modules"`
  (documented benign: packaging.md :258/:339/:398).
- Extraction-diff for byte-identical-move proofs:
  `diff <(git show <sha>:file | sed -n 'A,Bp') <(sed -n 'C,Dp' file)`.
- Shape censuses over fixed counts (T05 lock-rewrite lesson: the shape is the
  gate; counts are recorded actuals).
- Non-vacuity pins for opaque structures (T09 Go-To: concrete per-mode tree
  counts, not cross-mode equality alone).
- Every count/anchor re-verified against the live tree at write time — binds
  all wires, lead included (codified PLAN §2 rule 6, :92).

## 2. Closed windows and sign-offs (chronological)

- **T13** (78b9e1f, retro): `subscription_at(path)` seam; `run_with` citation
  comment verified in single_instance.rs; timeout-free `rx.next` hang-class
  deferred to the T25 bank.
- **T02** (e1a61c3): test harness (app_test_harness.rs, 199 lines: `test_app()`
  Light-pinned, pid+tid TempDir, unwind-safe Drop; `with_config` seam). Commit
  census: exactly 2 files. Commitment (c) discharged here.
- **T03** (b963dce, 242+/5−): D8 strict UTF-8 load + file-naming load-error
  dialogs. Window closed on six conditions; let-match shape accepted with an
  extraction-diff pin (success statements raw-identical to the pre-edit arm);
  package gates 0/0/0/0 at 39+6; `:1348` write_to observation routed
  out-of-band → lead ruled into T22 (rev 7). Cond-2 symmetry patch delta-verified
  (+4/−0 inside `load_path_io_error_names_file`: captures :102–103, asserts
  :129/:131 mirroring the D8 test's :49–50/:80/:82); amended sign-off; commit
  disk-verified.
- **T04** (a2dc94a, 1+/1− + 0+/2−): desktop `Categories=Utility;TextEditor;X-COSMIC;`
  (D12) + metainfo `<binaries>` unwrap. Package approved: `desktop-file-validate`
  exit 0 silent; `appstreamcli` exit 0, infos gone, pedantic 1 steady; zero-diff
  set mtime-proven; pinned strings live. **Indent ruling: `<binary>` keeps its
  6-space indent** — footprint discipline over cosmetic normalization. Commit
  disk-verified (staging exact, ux.md excluded).
- **T05 window — OBJECTION, then ADOPTED (PLAN rev 9, 0297eb7).** Spike-proven
  (exact repo copies in /tmp, offline): inserting `rev = "d4d71fd5…"` changes
  libcosmic's cargo source-ID, so `cargo metadata --locked --offline` exits 101
  and an unlocked regen rewrites every libcosmic `source` line to the
  `git+…?rev=d4d71fd…#d4d71fd…` form — the packager's independent repro: **18
  confined line pairs, zero collateral**. The pre-amendment Step-A pair
  ("lock byte-identical + `--locked` green") was unsatisfiable, and T06's
  `--frozen --offline` would fail identically (load-bearing, not cosmetic).
  **Amended Step A (rev 9 text):** pin → one-time `cargo metadata --offline`
  regen → confined-diff verification (shape census) → `cargo build --locked`
  green → handoff; Cargo.toml + regenerated lock ride the single T05 commit;
  byte-identical done-when re-baselines to post-pin. Accepted refinements:
  shape-census-not-count; post-regen `--locked` close gate; **A-before-B
  ordering** (`cargo vendor` stanzas key on source-ID — a vendor/ materialized
  against the bare lock won't match the pinned lock; the kept-warm
  /tmp/vendor-spike is reference-only, quarantined). Release token: architect's
  explicit ack (issued — their endorsement wire). Rev-match test design survives
  (`#`-fragment parse works on `?rev=X#X`).
- **T09 window: NO OBJECTION** (folded into PLAN at rev 8). Go-To ruling:
  structural invariance satisfies RV-1 (`menu::Tree` opaque; MenuTree fields all
  `pub(crate)`) with three conditions: (i) non-vacuity — CONCRETE expected
  top-level tree count per wrap mode (my read: 14 = 11 base incl. 2 dividers +
  1 Go-To + 2 trailing; pin the execution-verified actual); (ii) cross-reference
  comment to §2.3 row #26 / T10; (iii) direct `config.word_wrap` mutation, no
  config handler. `text_editor::Cursor: PartialEq` CONFIRMED
  (iced/core/src/text/editor.rs:202–203) — undo-stack asserts go full-fidelity,
  text-only fallback moot. Advisory (a) accepted by owner: non-edit test uses
  `Action::Move(Motion::End)`; row #29 keeps SelectAll. Advisory (b): local seed
  helper duplication OK for T09; a third copy by T11/T20 consolidates into the
  harness. MenuAction map: 22 variants, all name-identical except About; no
  LaunchUrl (R3 holds).
- **T10 window: NO OBJECTION.** Test 22 (`goto_confirm_without_dialog…`) KEEP —
  defensive-path lock beyond row #28's letter (label convention adopted).
  on_escape boundary correct as drawn (find-bar branch only; pending/context →
  T11, per PLAN's T11 row and PLAN :144). Match-case-via-FindNext routing
  sufficient (shared field, identical pass-through; pure-fn coverage exists).
  commands.rs comment-only edit (UX-D9 micro-deviation note on `to_lowercase`
  in `selection_matches`) is PLAN-mandated — v2 `casefold` at commands.py:35
  verified. Row #26 behavioral twin `goto_noop_when_word_wrap_enabled` banked
  in T10's done-when (rev 8) with the T09 cross-reference.
- **T11 window: NO OBJECTION** (the big one: +31 tests in app_file_tests.rs,
  5→36; PLAN-order totals 115 unit + 6 = 121). All mechanics cites verified
  live; PLAN rows :221/:224 verbatim; arch rows #2–9/:200–207, #42–45/:240–243,
  #47–48/:245–246 (#46 correctly T12's); flows §4.3 :551–631; guard-matrix 8/8
  cells mapped. Advisories issued: (1) escape-precedence test should also assert
  `pending_after` cleared (on_escape's pending branch clears BOTH fields — the
  ping-pong defusal); (2) unwritable-path recipe (dir-in-place-of-file,
  fs-setup not field-pokes) declared in the package. Approved: T22-forward
  prefix-lock for the could-not-save test (survives T22's composition, tightened
  there per rev 7); full lock on SaveSelected's url-naming :613 (T22-invariant);
  advisory-(b) trigger NOT tripped (declared; check at package). **Anchor
  normalization: `write_to` Err arm brace-inclusive :1346–1351; the format line
  :1348 is T22's single anchor.**
- **T11 advisories ADOPTED by owner** (§A wire): test 28 gains the pending_after
  assert via the failed-save chain — chain live-verified end to end
  (`PendingDialog::SaveChanges{after}` :72, guard sets :1257; DialogSave
  take→pending_after :784; write_to Err → pending=Error; escape clears BOTH
  :824–825; CloseError re-raises iff pending_after :796–802). Unwritable-path
  recipe declared up front (load → remove_file → create_dir; tests 11/18/24/27/28;
  local FS-ops-only helper). Canonical anchors adopted (:1346–1351/:1348;
  :921–923).
- **T05 cycle CLOSED (post-adoption).** Lead ruling: ADOPTED AS AMENDED, owners
  released. Operative composite Step A = PLAN rev 9's T05 row + my three
  accepted refinements (shape census not fixed count — 18 pairs recorded as
  today's actual; Step A closes with post-regen `cargo metadata --locked
  --offline` AND `cargo build --locked` both exit 0; A-before-B ordering
  load-bearing). No rev 10 — refinements ride the T05 commit body permanently;
  my judgment on record: PLAN-text folding NOT load-bearing. packaging.md
  §2.3-item-5 correction wording FROZEN (packager's final = my pre-approved text
  + the T06-consequence clause; NO OBJECTION — both breakage modes and the
  contents-identical point match the spike record). D10 addendum: DECISIONS.md
  lead-filed; I verify the packager's exact nuance wording at package; staged
  alongside the T05 commit (declared in package and sign-off; cross-refs rev 9
  + T05 hash). Lead's token adjudication: **SATISFIED, no re-ack** — the
  architect's §B endorsement post-dates my spike wire, names the amended Step A,
  and supersedes their stale wording; hazard closed three ways; Step 1 opens on
  the packager's sequencing ping. **Execution observed in flight** (working tree
  at 8e5b01a+; observation only — NO gates, tree not quiescent): Cargo.toml 1+
  (rev pin), Cargo.lock 36 ± lines = exactly the 18 source-line pairs the spike
  predicted, manifest 8 ±, packaging.md 1+/1− (net-zero shift → §4 line cites
  stable), tests/packaging.rs 88+, scripts/vendor.sh present; zero src/ touched;
  footprint matches the declared surface. Awaiting the quiescent ping + package.
- **ux sync package (rev 3.1): APPROVED.** Lead's verbatim gate reproduced
  exactly: numstat 55/33; stale tokens `89-128`/`37-128` zero (exit 1);
  `:89-132` at :242/:675; `:37-132` at :724/:798; historical `1269-1290` at
  :724/:793, both marked "pre-T03 numbering". All nine declared areas present in
  the 161-line diff (header rev note; preamble citation-baseline convention;
  §1.7 cluster with three status changes; §3.1 rewrite; §3.2 delta; §6/§8
  LANDED-IN-T03 notes; §7 D-5 CLOSED with dual marked cites; priority note;
  App B). The one surviving "micro-task" string (:240) IS the correction
  ("folded there rather than a micro-task"). Cond-2: zero text change beyond the
  range tokens. New cites spot-verified live: guard_unsaved(Open) :585,
  open_dialog :1355, untitled-default :1377, save-dialog builder :1390, save
  :1320–1325. Ready for the lead's commit. **Committed: 8e5b01a** —
  record-check CLEAN (ux.md alone staged, 55/33, commit body cites this sign-off
  and the gate reproduction verbatim).
- **T12 window: NO OBJECTION** (last Stage-D front window; execution waits for
  the Stage-D release at T08's landing). 21 tests (19 settings + 2
  config.rs-inline). All arm cites verified live verbatim (ToggleWrap :727 …
  ToggleContextPage :766–773, UpdateConfig :803–810); FONT_FAMILIES :35–50 =
  14 entries / 3 generic aliases, index 3 = "Noto Sans Mono"; FONT_SIZES :52 =
  14 entries, idx 5 = 14, last = 36, 15 ∉ list; theme_for config.rs:43–49 /
  pin_independent :51–57 verbatim; **Config default color_scheme = System
  (config.rs :26–29) = v2's SYSTEM fallback (test_theme.py:311–313
  live-verified) — RV-5 parity pin**; ContextPage single-variant confirmed
  (:166–171, derives PartialEq — disclosure (vii) sound); update_title
  :1035–1051 (marker "•  " + em-dash format :1043–1044); system_theme_update
  :854–864; footer :504 (None iff !show_status_bar); intern_family :1441
  already headless-proven (app.rs inline test :1537). Arithmetic 115+21=136
  (21+5+3+5+36+21+24+19+2) + 6 = 142 verified. **Cite-label correction
  (condition 1):** "PLAN's arch-table T7 row :785" is **architecture.md**'s
  task-table T7 row :785 (PLAN.md is 376 lines; the quoted phrase is verbatim
  there, backticked — my first grep missed it on the backticks, a false negative
  logged in §5). Same table: T4 :782 carries RV-1 (matches my Phase-1 anchor);
  T10 :788 = deferred reviewer-gated clipboard row (T24 decision input).
  Conditions/advisories: (1) fix the cite label in the task record; (2) RV-5
  defaults assert pins `ColorScheme::System` explicitly (the v2 parity point);
  (3) RON contains-asserts pin exact serialized tokens at execution
  (non-vacuity); (4) roundtrip advisory — a `get_entry` read-back leg on one
  scheme-persist test mirrors v2 test_roundtrip :305–309 directly (contains is a
  proxy; owner may justify equivalence in the record instead); (5) hook-test
  System leg: no-panic + task-drop + config/scratch unchanged only — scope
  "state unchanged" to non-theme fields (set_theme legitimately mutates theme),
  no darkness pin; (6) cross-ref the harness's existing ToggleWrap→disk test
  (:151–156) to avoid divergent path-layout expectations; (7) header-matrix
  asserts pin resolved literal strings (fl!-mirrored expectations would be
  tautological); (8) boundary ruling on disclosure (ix): system_theme_update
  ACCEPTED under T12 — PLAN T11 row :221 names exactly three hooks
  (on_escape/on_app_exit/on_close_requested); task record cites that as the
  boundary evidence. Disclosure (x) endorsed (UpdateConfig scratch non-effect
  as explicit assert — the T11 pending_after analog). Disclosure (vi): Font
  PartialEq at execution, field-match fallback approved. Advisory-(b) trigger
  not tripped (declared; package check: no third seed-helper copy). Footprint:
  2 test-only additions + 1 mod line + provenance comment; zero production
  lines; no harness edits.
- **T12 addendum received (§1–§3); note text otherwise stands.** §1 T23
  coupling ENDORSED — PLAN T23 row :242 live-verified verbatim ("Family
  enumeration … must update T12's locked FONT_FAMILIES/settings tests —
  Architecture-owned file — **in the same commit** (reviewer requirement)";
  dependency "T12 (settings tests guard config changes)"). Pinning surface
  (a)–(e) adopted as the canonical T23-guard checklist (banked in §3); pin (c)
  independently confirmed: Config default `font_family = "monospace"`,
  `font_size = 14` = FONT_SIZES index 5 (config.rs Default :26–35) — hence the
  unknown-size test correctly uses 15. §2 rev-9 re-cites accepted (T12 row still
  :222, live-verified; rev-9 entry :352–358 confirmed). §3 verify.sh subsumption
  confirmed (steps 1–4 = the four-gate wording, zero continuity gap); the
  RV-15c interpretive question is RULED — disposition **RV-15c-1** in §3 below
  (ISSUED: full text wired to the architect, lead copied; addendum dispositions
  §1–§3 all delivered same wire).
  The architect's cite self-correction (PLAN → architecture.md :785, both
  occurrences) crossed my verdict wire carrying the identical fix — condition 1
  SATISFIED by their correction, no divergence (crossing #11). Record note:
  their packaging.md §4 cites (:280–283/:313) pre-date T05's in-flight append;
  the append is 1+/1− (net-zero shift) so the cites hold — re-verify at Stage-D
  packages regardless.
- **This log committed: 48d603d** (first rev, 262 lines; lead's custodial read
  matched the declaration; record-check CLEAN — exactly this file staged). The
  working rev (verdict-turn entries + this addendum round) is declared and rides
  the next natural commit per the lead's policy. Lead's receipt counts (38
  total / 20 atop) = their pre-commit staging snapshot; live at 8e5b01a = 40/22
  (crossing #14, benign).
- **T12 dispositions ACKED (architect wire): conditions 2/3/5/8 + advisories
  4/6/7 ALL ADOPTED with concrete specs.** Cond 2: invalid-RON test asserts
  `color_scheme == ColorScheme::System` explicitly (the v2 parity point,
  test_theme.py:311–313 quoted in the record). Cond 3: RON contains-asserts pin
  exact serialized tokens captured from a known-state dump; second-flip revert
  legs (#31/#32) are the counter-proof. Cond 5: System leg = no-panic +
  task-dropped (R2) + non-theme config/scratch unchanged, NO theme-state
  contract, no darkness pin (§3.4/OBJ-1); explicit leg = Task::none + full
  invariance. Cond 8: record cites PLAN :221's three-hook T11 boundary;
  disclosure (ix) resolved ACCEPTED. Adv 4: #38 gains the true roundtrip leg —
  Scheme(Dark) → persist → `Config::get_entry` read-back == Dark (v2
  test_roundtrip :305–309 mirror; done-when upgraded from contains-proxy).
  Adv 6: ToggleWrap-RON test cross-refs harness :151–156; both records quote
  the same spike-(d) path layout. Adv 7: header matrix pins resolved LITERAL
  strings (fl! resolved once at execution, recorded in the task record — no
  tautological reconstruction; T22 prefix-lock discipline). Disclosure (vi)
  sharpened: Name leg headless-proven via :1537; Font PartialEq is the sole
  execution-time open question, field-match fallback ready.
- **Pin-(c) refinement (architect, binding T12 execution design):** the seed
  test mutates `config.font_size = 20` → asserts `size_index == 8` — the FOUND
  leg pinned non-vacuously (default 14 = index 5 = the fallback, so a
  default-seeded assert cannot discriminate); the unknown-size test
  (15 ∉ FONT_SIZES → unwrap_or(5)) stays SEPARATE as the sole fallback pin.
  Arithmetic live-verified: FONT_SIZES[8] = 20 ✓, 15 ∉ list ✓, fallback 5 ✓.
  Adopted into the T23 bank + T12 package check. Non-binding observation
  returned: their parenthetical "deliberately NOT 12 (index 4)" conflicts with
  their own stated ≠5 rule (4 ≠ 5 discriminates fine) — the binding text is the
  rule + the 20→8 choice; no change owed. **Resolved by the owner's receipt:
  the parenthetical is WITHDRAWN as overstated — nothing prohibits 12; the
  governing spec is the RULE (seed index ≠ fallback index 5) + the 20→8 choice,
  with the separate unknown-size test (15 → unwrap_or(5)) as the sole fallback
  pin. Execution unchanged; this is the single governing text for T12's
  package check and T23's executor cross-check.**
- **Lead receipts: self-correction OWNED, RV-15c-1 ENDORSED (no override),
  pickups DECLARED.** The 38/20 pair owned as a lead-side rule-6 slip (verified
  pre-commit, quoted as-of a moved HEAD); live re-enumeration = my crossing-#14
  figures (40/22). PLAN **rev 10 scheduled**: the RV-15c-1 fold into :78–81,
  post-T05 docs window, ahead of T06 release — governance text in hand before
  Stage-D requests; until then, requests cite the disposition. **Log rev 2
  custodial pickup declared**: separate commit in the same window under the
  48d603d protocol (custodial read + live label verification before staging).
  Sequencing LOCKED: T05 package → my sign-off → lead's T05 commit (seven
  paths; DECISIONS.md applied BY THE LEAD at the commit turn — tripwire
  resolved-by-reconciliation) → docs window (log rev 2, then PLAN rev 10) →
  T06 release ping (clean tree, named HEAD). Crossing #15 dead-leg named by
  the lead themselves.
- **T05 PACKAGE: APPROVED — diff sign-off issued, commit cleared with two
  record corrections.** Independently reproduced under rev-5 quiescence
  (packager's declared window 06:05:53–06:08:13 matches live stat to the
  second; my pre/post brackets IDENTICAL on every tracked path — the whole
  battery moved zero tracked bytes):
  (1) shape census — 36 ± lock lines, ALL `source` lines, 1 unique bare removed
  / 1 unique `?rev=` added, identical `#d4d71fd5…` fragment; live lock 18
  rev-form / 0 bare, 163121 bytes (+810 = 18×45 exact); third witness
  corroborated (regen stderr "Locking 18 packages" + 18 Adding lines); pre-pin
  lock == HEAD lock byte-identical (sha fdc0d8f9…).
  (2) close gates re-run — `cargo metadata --locked --offline` exit 0 (valid
  JSON) AND `cargo build --locked` exit 0.
  (3) A-before-B substance — `.cargo/config.toml` carries exactly ONE libcosmic
  stanza (:26) keyed on the PINNED `?rev=` source ID, zero bare-keyed stanzas,
  12 replace-with total, `directory = "vendor"` :57; mtime chain vendor.tar
  (1789107149) > lock regen (1789106086) > pin (1789105935).
  (4) vendor.sh — tree == staged copy byte-identical; 1100 bytes mode 755, 25
  lines; my rerun (extract path) exit 0 in ~1 s with config sha fce94048…
  UNCHANGED; vendor/ 973M / 636 crates / vendor.tar 900M. G1 clean-state regen
  + G2b tar-only restore ACCEPTED ON EVIDENCE (not re-run destructively against
  their staged state; G2b's sha identity already proves the config-inside-tar
  delta).
  (5) G3 proxy re-run — host `cargo build --release --frozen --offline` exit 0,
  binary 45,757,432 bytes == their G3 exactly.
  (6) cargo four re-run — fmt exit 0 (empty log), build 0, clippy
  --all-targets -D warnings 0 (20 `?rev=` witness lines), test 0: **39 + 10 =
  49 live-counted exact**.
  (7) G5 — lock sha256 65a910d2… == baseline; baseline integrity cross-proven:
  its pre-edit shas for the packager's three files == their HEAD blobs exactly
  (38594993/cc28e931/142726c5).
  (8) per-file — Cargo.toml: +rev at :28 only. Manifest hunks == apply-list
  E1/E2/E3 verbatim (branch :13; build-args deleted whole with the declared
  env-comma fix; build cmd :42), JSON valid, finish-args exact 6-set, license
  lines BYTE-IDENTICAL (HEAD :49–50 == live :47–48, diff exit 0, zero hunks
  touch them). packaging.rs pure EOF append (@@ -91,3 +91,91 @@), 93→181,
  10 #[test], new tests exactly at :96/:107/:136/:167; only serde_json match
  PRE-EXISTING (:54, via the main dependency — no dev-dep added; lock
  invariance independently confirms). packaging.md 1+/1− with the FROZEN
  item-5 string mechanically verbatim (NEW STRING present, OLD absent,
  T06-consequence clause included). .gitignore :4–7 coverage cite exact.
  DECISIONS.md clean by design (lead applies at the commit turn).
  **Commit-body corrections (record-only; zero artifact impact; no rework):**
  (i) RV-6 anchor — license lines live at **:47–48** (net −2 shift from
  E1+E2); "L49-50" is the HEAD-era anchor (valid as-written in the apply-list,
  whose header labels it as-of HEAD 0297eb7); the body cites live :47–48 or
  labels the HEAD anchor. (ii) Append-drift narrative — observed staged append
  = **73 lines**, tree = 88 → drift **+15**, all rustfmt wraps at four sites
  (verified assert-by-assert: literals/counts/messages identical, zero
  semantic delta); the package said "85+ → +3" — the body restates to the
  observed figures or drops the drift detail; "gates against FINAL bytes"
  stands (mine ran on the tree). **Resolved by the owner's receipt — lineage
  re-derived from the live artifacts, not memory:** "85" was the post-Edit /
  PRE-fmt intermediate tree state (the Edit retyped the staged content with
  +12 manual pre-wraps at five assert sites, 73→85); `cargo fmt --check` then
  flagged the two license-path asserts → method-chain fix +3 → 88 final. The
  staged file was never 85; the "85+" mislabel is owned. Hunk/site reconcile:
  +15 lines across **4 diff hunks / 5 assert sites** (hunk 4 carries BOTH
  license asserts — my "four sites" counted hunks, their five counts asserts).
  Arithmetic closes exactly: 73 + 12 + 3 = 88. Owner-supplied body language:
  "packaging.rs 88+/0− final (staged 73 + 12 Edit-time wraps + 3 fmt wraps;
  4 hunks / 5 assert sites, semantic delta zero)". Artifacts of record: the
  staged file for content (73), the final tree for gated bytes (88).
  Correction (i) accepted likewise — future cites live-or-labeled.
  **D10 verbatim block:** verified against the pre-ruled SHAPE (exactly two
  anchors — 0297eb7 + descriptive "the T05 single commit"; no hash-shaped
  placeholder; linkage-closure language present), against today's live evidence
  (every technical claim independently proven at this gate), and for
  cross-consistency with the frozen item-5 string. The byte-diff leg vs the
  packager's original proposal wire was unreachable from my transcript (phrase
  searches empty); the lead holds both texts — a one-command diff at staging
  closes that leg; my post-commit record-check compares applied text ==
  verbatim file + placement at the D10 "Choice." paragraph end (their
  :246–251 cite vs my anchor base's D10 :238 — plausible; verified at write
  time).
  **Item-6 disposition (flag-before-edit candidates): DEFER BOTH TO T27** —
  the packager's suggestion adopted; banked. Staging census achievable: six
  dirty paths + lead-applied DECISIONS.md = the declared seven; my log and ux
  excluded by construction. Post-commit record-check queued.
- **T05 supplement (packager) + lead alignment wire received — both composed
  pre-verdict (crossing #17); verdict stands APPROVED, unchanged.** The
  supplement's third-witness granularity re-verified from the raw stderr:
  exactly 18 `Adding` lines = 4 cosmic crates (build_helpers, cosmic-config,
  cosmic-config-derive, cosmic-theme) + 13 iced (incl. iced_widget **v0.14.2**
  == the live lock's version) + libcosmic = 18, every one under the `?rev=`
  source ID; the ONLY non-Adding/non-Locking content = the standard
  `--format-version` advisory — zero network legs (no fetch/download/updating
  lines; my first grep's 'http' hits were the source URLs themselves).
  Architect's post-handoff quiescence re-check (lock 05:54:46.382 / toml
  05:52:15.574 unmoved) matches my brackets. The lead's tripwire
  RESOLVED-BY-RECONCILIATION (DECISIONS.md = the seventh path, lead-applied at
  the commit turn) matches my sign-off's treatment exactly; their body
  commitments align with my reproduced actuals. Packager's citation update
  (this log tracked at 48d603d, third-party-dirty, excluded from the
  footprint) acknowledged; their frozen-string ends-match confirmation is
  subsumed by my mechanical full-string compare.
- **Lead's commit turn observed mid-flight — D10 application pre-checked
  read-only, CLEAN (pre-emptive leg of the post-commit record-check).**
  DECISIONS.md dirty at HEAD 8e5b01a: mechanical compare says the verbatim
  frozen block is present BYTE-EXACT in the live file, starting :253
  immediately after the D10 "Choice." paragraph end ("…assertion pins the
  match."), before the `---`/D11 separator — placement semantically exact vs
  the packager's :246–251 cite (lead re-verified live at write time per their
  protocol); exactly two anchors (`0297eb7` + the descriptive T05 reference),
  no hash placeholder; the 19-line insertion is the file's ONLY change (git
  diff census). No deviation → no flag wire; the leg re-confirms against the
  committed blob at the record-check.

## 3. Open banks and package-time checklists

**Queue (lead-confirmed sequencing, LOCKED):** ux sync committed 8e5b01a
(closed). **T05 APPROVED** → lead's T05 commit (seven paths; DECISIONS.md
applied by the lead at the commit turn) → docs window (log rev 2 custodial,
then PLAN rev 10 = the RV-15c-1 fold) → T06 release ping (clean tree, named
HEAD) → T06 evidence review → T07/T08 windows; **Stage D opens at T08's
landing** (rev-5 single-modifier discipline: scripts/ vs src/tests is not
docs-disjoint). Stage-D packages: T09 at 60+6, T10 at 84+6, T11 at 121, T12
at 136+6=142 — all four windows banked; T12's specs ADOPTED with the pin-(c)
refinement.

**T05 package (EXECUTED — APPROVED; results in the §2 verdict entry):**
shape census (every ± lock line a libcosmic `source` line,
bare↔`?rev=`, identical `#` fragment, zero collateral; record actual pair count
— 18 today); close-gate exit 0 post-regen; A-before-B evidence (vendor.sh run
after the pin); vendor.sh from clean state (`rm -rf vendor .cargo vendor.tar`)
+ second-run no-op path + timings; host `cargo build --release --frozen
--offline` green; `cargo metadata --locked --offline` sanity; cargo four at
39 unit + 10 packaging = 49 (live-counted); existing 6 packaging tests
zero-drift; footprint = Cargo.toml + Cargo.lock + manifest + scripts/vendor.sh +
tests/packaging.rs (+ packaging.md §2.3-item-5 correction — FROZEN wording incl.
the T06-consequence clause, rides T05/T06 doc append; + DECISIONS.md D10
addendum — lead-filed, nuance wording verified by me against the packager's
proposal verbatim, staged alongside the T05 commit and declared in package +
sign-off); commit body must carry the three refinements permanently (no rev 10 —
my not-load-bearing judgment on record); no flatpak-builder (RV-15 → T06).

**T06 (evidence review — no flatpak-builder on my side, constraint):**
sandbox offline build exit 0 fully offline; vendor dir-copy timing vs the
§2.3 archive-source revisit threshold (>60 s); ccache/build timings appended to
packaging.md; retroactive Flatpak gate for T01–T05 (RV-15a).

**T07/T08 windows:** smoke-test + verify.sh per packaging.md §3/§4; my skip
authority (b) activates at T08; `GIO_MODULE_DIR=""` as verify/ci env-prep
candidate (packager's T04-ack point 3) WITH the no-real-output-masking caveat;
tampered-vendor fails correctly; fresh-clone unattended run (single D9 network
window).

**Disposition RV-15c-1** (interpretive ruling under the delegated skip
authority; effective immediately; PLAN :78–81's "src-only" text unchanged until
the lead folds a clarification into the next rev — not required for
effectiveness; requests cite "RV-15c + disposition RV-15c-1"; lead copied,
overridable). **Principle:** the authority turns on ARTIFACT NEUTRALITY, not
literal file-path membership — steps 5–10 verify the packaging chain, and a leg
qualifies iff it cannot alter any packaged artifact or packaging input.
**Qualifying legs:** cfg(test) test files + their `#[path] mod` lines;
cfg(test)-only hunks in production src files (T12's config.rs inline module);
comment-only src hunks (T10's commands.rs leg — established by the owner's hunk
census); owner-applied docs-only legs inside docs/migration/ matching the task's
PLAN row (T09's architecture.md Menus-row flip). **Authority OFF — full steps
1–10 —** for any diff touching: compiled non-test code; data/; i18n/ (*.ftl is a
compile-time-embedded runtime input, NOT docs); Cargo.toml/Cargo.lock; the
manifest; scripts/; justfile; .gitignore; docs outside docs/migration/.
**Regime unchanged:** request per package; enumerate every leg with file + line
counts; steps 1–4 always run; every skip recorded in package + task record.
**Self-void clause:** if any step 5–10 proves to consume docs/migration/ or
cfg(test) content, the disposition voids for that class. **Ownership map:**
architecture.md = Architecture; ux.md = ux; packaging.md = packager (its T05/T06
appends ARE the packaging tasks — no skip arises); PLAN.md/DECISIONS.md =
lead-filed, never in task packages; review-*.md = reviewer, never packaged.

**T23 bank (font-dialog improvements; ux + architect spike; PLAN :242):** window
is mine ("Final scope locks after reviewer input"). Same-commit coupling is a
reviewer requirement ON THE ROW: the enumeration commit carries its T12
locked-test updates itself — T12 lands first and becomes T23's guard (declared
once in the T12 addendum §1, the T22/:1348 anchor pattern). At T23's
window/package, cross-check the pinning surface: (a) row-#34 test pins index AND
content (`FONT_FAMILIES.get(3)` = "Noto Sans Mono") + out-of-range-99 ignored;
(b) row-#37 alias legs ("monospace" → Monospace) + named-family membership
("JetBrains Mono" → Name); (c) row-#33 seeds from default "monospace" (stable
iff aliases retained; any weight/style config fields update the Config
construction) — **pin-(c) refinement (binding T12 execution design):** the
seed test mutates `config.font_size = 20` → asserts `size_index == 8`
(non-vacuous FOUND leg; the default 14 = index 5 = fallback cannot
discriminate), and the unknown-size test (15 → unwrap_or(5)) stays SEPARATE
as the sole fallback pin — T12 package check verifies both legs, T23
cross-check inherits them; (d) row-#46 replacement-Config construction (new fields /
config-version bump land here); (e) RV-5 pair + the harness's get_entry version
pin ("config-version handling = architect's call, defaults preserved").
FONT_SIZES pins (#33's index-5 default, #35's clamp-13) expected stable (ux
scope keeps the size list); any change → same-commit rule. T12 package check:
pins (a)–(e) present as enumerated, so the guard is real.

**Stage-D packages:** T09 (60+6; concrete tree-count pin confirmed; Move(Motion::End)
in the non-edit test; architecture.md SINGLE-spot Menus-row flip citing rev 8/9
disposition — interim baseline note voided, folds into T27; no third seed-helper
copy); T10 (24 tests; commands.rs comment-only hunk census; zero new allows;
defensive-path label on test 22; twin cross-reference pair); T11 (31 tests → 121
PLAN-order; advisories' dispositions; harness untouched; existing 5 tests
unmodified); **T12** (gates four at 136+6=142 live-counted; census isolating
app_settings_tests.rs (19) + config.rs inline module (2) + one mod line +
provenance comment; zero production lines; no harness edits; no third seed-helper
copy; window conditions 1–8 dispositioned in the task record; spike-(d) path
layout quoted at execution; Font PartialEq outcome or field-match fallback
recorded; System-scheme darkness legs excluded everywhere per §3.4/OBJ-1).
T14: multi-hop combos per PLAN's T14 row.

**T22:** `:1348` fold — composition `format!("{}\n{}: {err}", fl!("could-not-save"), path.display())`
per ux's option-1 ruling extended; test 11's prefix-lock tightens; save-error
test extends app_file_tests.rs; GoToConfirm focus return (architect edits / ux
co-signs, `Id`+focus-task mechanism).

**T24 (reviewer-gated):** decide at T09's package whether Cut/Copy payload-level
proof is required or the task is formally skipped (current lean: state-effect +
Move(Motion::End) coverage likely suffices — decide on the evidence, then).

**T25:** timeout-free `rx.next` hang-class deferred line (T13 bank); RV-16
version-keyed cache drift detection.

**T27 (end of Stage E, pre-Phase-3):** record-check the citation-only renumber —
architecture.md §2.3 (uniform ~−47 pre-T02 drift class) + ux.md; sampled cites
against the tree; known datapoints: row #16 cites Delete 713–717 vs actual :667;
header update_title 1022–1038 vs actual :1035; **ux.md :174 cites
`commands.rs:20-37` for selection_matches (actual :74–83) while :728 cites :81
correctly — reconcile**; Appendix A :826 internal cites (commands.rs 221–245 vs
actual :215; footer 551–573 vs actual :504; corpus 432–460 vs actual :420/:440);
task-table rows :780–788 internal cites join the sweep; **packaging.md L161
tail (T05 item-6, reviewer-ruled — deferred here): stale "P2-T3" task name
(live: T05) + the pre-regen `Cargo.lock:2740` anchor → symbol-first
`[[package]]` libcosmic cite**; PLAN-side count fixes are
OUT of T27 scope (rev 9 precedent: PLAN fixes ride PLAN revs).

## 4. Verified anchor base (as-of HEAD 8e5b01a; src/ unchanged since b963dce — re-verify before trusting)

**src/app.rs (1565 lines, mtime 1789099383):** `use url::Url` :29; `Flags`
:56–57; `AfterSave` :62–67; `Message` :114 (Clone+Debug, NO PartialEq —
`matches!` per case); `ContextPage` :166; `MenuAction` :172 (22 variants,
Eq+Hash+PartialEq), map :201–227 (About sole non-identical, no LaunchUrl);
`aligned_disabled_item` :251; Editor arm :566–583 (allow :563); OpenSelected
:586–593 (Err names url :590); OpenExternal :594–606 (4-way batch); SaveSelected
:609–616 (Err names url :613); Exit :617–622 (retarget); Undo :624; Redo :633;
Cut :642; Copy :649; Paste :654; ClipboardPaste :658–665; Delete :667–671
(unconditional push_undo :668 — row #16 quirk); GoTo :691–707 (guard :692);
GoToInput :708–718; GoToConfirm :719; SelectAll :720; InsertDateTime :721–726;
dialog arms :779–816 (DialogCancel :779, DialogSave :783, DialogDiscard :789,
CloseError :796, Error :811, Cancelled :814); on_escape :822–837 (pending branch
clears pending AND pending_after :824–825); on_app_exit :839; on_close_requested
:843–852; with_config :872–927 (argv load :921–923, synchronous); edit_menu_items
:928–970 (14 top-level trees both wrap modes, one Go-To per branch); is_dirty
:1011; update_title :1035; push_undo :1053; prefill_search_from_selection
:1122–1129; needle :1131; find_next :1135–1152 (wrap hardcoded :1143,
cannot-find :1148); replace_one :1154–1191; replace_all :1193–1211 (single
push_undo :1207); select_range :1213; confirm_goto :1220–1253 (parse-fail
asymmetry :1222–1231; beyond-end else :1241–1250); guard_unsaved :1255; proceed
:1264; reset_document :1273; load_path :1282 (D8 comment :1283–1288, decode arm
:1291–1303, IO arm :1311–1316); write_to :1327 (Ok stale-prompt clear
:1334–1341; **Err :1346–1351, format :1348 — T22 target**); MAX_UNDO_DEPTH=100
:1472; datetime_stamp :1474–1488; test mod decls :1527–1531.

**src/app_file_tests.rs (216 lines, 5 tests):** seed_undo_redo :24; D8 test
:38–83 (spec bytes :41, captures :49–50, asserts :80/:82); IO test :90–132
(captures :100–103, asserts :128–131); CRLF :140; mixed :161; success guard
:187.

**Others:** app_test_harness.rs 199 lines (5 tests); commands.rs (21 tests,
block :269–449 rev-9-verified; selection_matches :74–83, to_lowercase :81;
find_next :88); key_bind.rs 17 bindings (Ctrl+Shift+Z absent — editor_key_binding
carries it, UX-D8); single_instance.rs 5 tests (run_with comment :103–105);
tests/packaging.rs 93 lines / 6 tests (T05 adds 4 → 10); i18n/en/notepad.ftl
cannot-find/invalid-line-number/line-beyond-end :61–63.

**Packaging (T05 working tree, pre-commit — live-verified at sign-off):**
manifest json 58 lines — command :12, branch "stable" :13 (D9), finish-args
:14–21 (6 entries, ratcheted by the test at packaging.rs :107), build-options
:22–28 (env :24–27; build-args DELETED by T05), cleanup :29–, build-commands
:41 (cargo build `--frozen --offline` :42), LICENSE/COPYRIGHT installs :47–48
(RV-6; HEAD-era :49–50 — net −2 shift from E1+E2), sources :50 (`type: dir`
:52); Cargo.toml libcosmic table :26–36, rev pin live :28; Cargo.lock 6593
lines — 18 libcosmic `source` lines in `?rev=` form (:590…:2215), 0 bare;
scripts/vendor.sh 25 lines (freshness key :15, regen path :18–22);
data/desktop 12 lines (Categories :9); data/metainfo 109 lines (ids :3/:36,
names :6/:33, release 3.0.0 :41, provides :35–38 post-unwrap, binary 6-space
indent kept); justfile vendor L83–88 / vendor-extract L91–93 / clean-vendor
L34–35; .gitignore :4–7 (target/, .cargo/, vendor/, vendor.tar).

**Docs (rev 9 / current):** PLAN (376 lines) — rule 6 :92; §3.1 coverage table
:141–147 (commands row fixed to 21 tests :269–449; :144 = T10/T18/T19 boundary
cite); T04 :201, T05 :202 (amended), T06 :203, T09 :219 (ruling folded), T10
:220 (twin banked), T11 :221 (names exactly three hooks), T12 :222, T14 :224,
T19 :238, T22 :241, T24 :248, T25 :249, T27 :251; rev log :330+ (rev 8), :352+
(rev 9). architecture.md — §2.3 rows: #2–9 :200–207, #17–28 :215–226, #31–39
:229–237, #41 :239, #42–48 :240–246 (#46 :244); §4.3 flows :551–631 (F17 :612,
F18 :616, F19 :619, F20 :622, F21 :626, F22 :631); **task table T2–T10
:780–788** (T4 :782 = RV-1 carrier; T7 :785 = config.rs-inline anticipation,
quoted in the T12 note as "PLAN's" — label corrected; T10 :788 = deferred
reviewer-gated clipboard row → T24 input); Appendix A :807 (Ln/Col row :826 —
internal cites stale-class → T27; Menus row :836). ux.md — D-9 :728
(+:174/:684/:876; :174 stale cite → T27). DECISIONS.md — D9 :202, D10 :238, D12
:286–298.

**Newly verified (T12 window / ux sync):** src/config.rs — `impl Default`
:26–29 (`color_scheme: ColorScheme::System`), theme_for :43–49, pin_independent
:51–57 (private; ThemeType::System→Custom). src/app.rs additions — FONT_FAMILIES
:35–50 (14: monospace/sans-serif/serif + 11 named), FONT_SIZES :52
([8,9,10,11,12,14,16,18,20,22,24,28,32,36]), ContextPage :166–171 (single
variant About; Copy/Clone/Debug/Default/Eq/PartialEq), footer :504 (None iff
!show_status_bar; caret_line_col call :511), Message::New/Open :584–585,
config arms :727–773 (ToggleWrap :727, ToggleStatusBar :731, Font :735–742
[position + unwrap_or(5) → PendingDialog::Font], FontFamily :743–747, FontSize
:748 [min(i,13)], FontFamilyInput :749, ApplyFont :750–756, Scheme :757,
ToggleScheme :758–765, ToggleContextPage :766–773), UpdateConfig :803–810,
system_theme_update :854–864, effective_is_dark :1015–1021, persist_config
:1023–1027, apply_scheme :1029–1033, update_title :1035–1051 (marker :1043,
title format :1044), PendingDialog::SaveChanges :72 (guard sets :1257), save
:1320–1325, open_dialog :1355, untitled-default :1377, save-dialog :1390,
intern_family :1441, font_from_family :1455–1470, inline tests :1537/:1545/:1556
(3). commands.rs — caret_line_col :215 (test :420). Harness —
app_with_tempdir_config :81 (with_custom_path :83); existing ToggleWrap→disk
end-to-end test :151–156. v2 — test_theme.py roundtrip :305–309,
invalid-value→SYSTEM :311–313.

## 5. Crossings and stale-snapshot log (all benign; tree arbitrates)

1. Lead's 6-vs-8 commit list. 2–3. Architect's staging warnings ×2.
4. Architect's T09-note premise (verdict/call already sent). 5. Packager's
"34 tests" vs live 39+6 (run-time counting discipline adopted). 6. Architect's
quiescent ping vs my pre-ping "only owed item" phrasing. 7. Architect's T10
addendum vs my reconcile flag (baseline note voided by rev 8 both directions).
8. Architect's stale T05 gate wording vs my objection wire (resolved: rev 9
makes their explicit ack the release token — issued). 9. Packager's cycle-closed
wire listed the sequence as still ahead ("T04 commit → T05 ruling → …") though
both had landed (a2dc94a, 0297eb7) and the lead's adoption wire released owners
— noted in my reply so the freeze doesn't outlive the ruling. 10. My
record-check wire crossed the lead's receipts wire (lead's adoption pre-dated my
concession roundup; both directions agree — rev 9 hard-codes no count, and the
release-token clause is satisfied by the architect's endorsement on my record).
11. Architect's T12 cite self-correction (PLAN → architecture.md :785) crossed
my verdict wire carrying the identical correction as condition 1 — both
directions agree; satisfied by their correction. 12. Lead's DECISIONS.md
footprint-amendment wire crossed my log edit + acknowledgment already carrying
it — both directions identical. 13. Lead's "channel holds quiet until your
ux-sync verdict" line crossed my APPROVED wire already queued (verdict
delivered; ux.md committed 8e5b01a). 14. Lead's 48d603d receipt counts (38
total / 20 atop) = pre-commit staging snapshot; live at 8e5b01a = 40/22.
15. Lead's receipts-wire item 2 corrected my log's "still untracked" status —
superseded by my own item-6 declaration already queued; dead-leg named by the
lead themselves. 16. Architect's T12-dispositions wire carried two open items
((a) addendum-scope confirmation, (b) the RV-15c ruling) — both crossed my
addendum-disposition wire in flight; resolved at zero divergence by their
follow-up (RV-15c-1 ACCEPTED; the §1–§3 dispositions ARE the scope
confirmation — no carve-out, the lead's T23 release-text banking stands).
17. Packager's T05 supplement + the lead's alignment wire crossed my sign-off
(all composed within minutes; the supplement still said "holding for your
verdict" and the alignment wire "nothing owed until your verdict" while the
verdict sat in both inboxes). Zero divergence: the supplement's third-witness
breakdown verified from the raw stderr (verdict-neutral, confirmed); the
alignment wire's tripwire resolution matches my sign-off's DECISIONS.md
treatment exactly.

**Self-corrections (the class binds me too):** update_title anchor :1022 →
actual :1035 (architect's example was right); tests/packaging.rs 94 → 93
(packager's live count right); write_to Err-arm span variants normalized to
brace-inclusive :1346–1351 with :1348 as the single cited anchor; **T12 cite
check — my first grep for the quoted "possibly src/config.rs" phrase returned a
false negative because the doc text carries markdown backticks; the phrase
exists at architecture.md :785 (the note's actual error was the file label,
"PLAN's" — PLAN.md is 376 lines). Lesson: grep doc quotes backtick-tolerantly
(regex `possibly.*config`, not a literal space-joined string).** **This log's
first-rev history line compressed away the seven Phase-1 doc commits between the
baseline and de2a1e5 (c885ca2, 0386632, 14f7760, 3b41f57, 9fcaf6a, 3e98f92,
37e6ec0) — corrected in the working rev against the live enumeration. Lesson:
git histories get enumerated, never compressed from memory.** Owner-side
cite corrections on the record: packager's PLAN ":181" → live :202; architect's
PLAN ":208" → :220 (pre-rev-8-valid) and "PLAN's arch-table :785" →
architecture.md :785 (self-corrected by the architect; my condition 1 crossed
it). Rev 9 fixed PLAN's stale commands.rs count (22 → 21, live-verified).

*Maintained by the reviewer; lead commits. Wire traffic between teammates is
the operative channel — this log is the durable index, not a replacement.*
