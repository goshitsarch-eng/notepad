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

**Anchor baseline:** branch `cosmic-migration`, HEAD `0297eb7` (PLAN rev 9),
2026-09-11. History: base 776b74d ← de2a1e5 (review-phase1) ← 8fb2e18 ← 5ae4e6d
(T01) ← 58fbb8a (rev 4) ← 419a140 (rev 5) ← 78b9e1f (T13) ← e1a61c3 (T02) ←
4bbf4f3 (rev 6) ← cea3201 (rev 7) ← 31c856d (rev 8) ← b963dce (T03) ← a2dc94a
(T04) ← 0297eb7 (rev 9).

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

## 3. Open banks and package-time checklists

**Immediate queue:** ux sync package (doc-only review: expect ~55+/33− plus the
two lead-requested corrections — three ":1348 micro-task candidate" sites
re-judged to the T22 fold, and four `app_file_tests.rs` cites re-anchored
post-patch per ux's own baseline convention; save-error row re-judged Partial;
citation-baseline convention in the preamble) → T05 execution package → T06
evidence review.

**T05 package:** shape census (every ± lock line a libcosmic `source` line,
bare↔`?rev=`, identical `#` fragment, zero collateral; record actual pair count
— 18 today); close-gate exit 0 post-regen; A-before-B evidence (vendor.sh run
after the pin); vendor.sh from clean state (`rm -rf vendor .cargo vendor.tar`)
+ second-run no-op path + timings; host `cargo build --release --frozen
--offline` green; `cargo metadata --locked --offline` sanity; cargo four at
39 unit + 10 packaging = 49 (live-counted); existing 6 packaging tests
zero-drift; footprint = Cargo.toml + Cargo.lock + manifest + scripts/vendor.sh +
tests/packaging.rs (+ packaging.md §2.3-item-5 correction — pre-approved
wording, rides T05/T06 doc append); no flatpak-builder (RV-15 → T06).

**T06 (evidence review — no flatpak-builder on my side, constraint):**
sandbox offline build exit 0 fully offline; vendor dir-copy timing vs the
§2.3 archive-source revisit threshold (>60 s); ccache/build timings appended to
packaging.md; retroactive Flatpak gate for T01–T05 (RV-15a).

**T07/T08 windows:** smoke-test + verify.sh per packaging.md §3/§4; my skip
authority (b) activates at T08; `GIO_MODULE_DIR=""` as verify/ci env-prep
candidate (packager's T04-ack point 3) WITH the no-real-output-masking caveat;
tampered-vendor fails correctly; fresh-clone unattended run (single D9 network
window).

**Stage-D packages:** T09 (60+6; concrete tree-count pin confirmed; Move(Motion::End)
in the non-edit test; architecture.md SINGLE-spot Menus-row flip citing rev 8/9
disposition — interim baseline note voided, folds into T27; no third seed-helper
copy); T10 (24 tests; commands.rs comment-only hunk census; zero new allows;
defensive-path label on test 22; twin cross-reference pair); T11 (31 tests → 121
PLAN-order; advisories' dispositions; harness untouched; existing 5 tests
unmodified). T12 window after that (app_settings_tests.rs; RV-5
invalid-config-fallback). T14: multi-hop combos per PLAN's T14 row.

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
correctly — reconcile**; PLAN-side count fixes are OUT of T27 scope (rev 9
precedent: PLAN fixes ride PLAN revs).

## 4. Verified anchor base (as-of HEAD 0297eb7 — re-verify before trusting)

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

**Packaging:** manifest json — command L12 (branch insert point), finish-args
L13–20 (6 entries, T05 pins the allowlist), build-options L21–30 (build-args
L27–29 delete target), cleanup L31–38, cargo build L44 (→ `--frozen --offline`),
LICENSE/COPYRIGHT installs L49–50 (RV-6), sources L52–57 (`type: dir`);
Cargo.toml libcosmic table :26–36 (rev insert after :27); Cargo.lock libcosmic
source :2740 bare form (→ 18 `?rev=` pairs at T05 Step A); data/desktop 12
lines (Categories :9); data/metainfo 109 lines (ids :3/:36, names :6/:33,
release 3.0.0 :41, provides :35–38 post-unwrap, binary 6-space indent kept);
justfile vendor L83–88 / vendor-extract L91–93 / clean-vendor L34–35;
.gitignore :5–7 (.cargo/, vendor/, vendor.tar).

**Docs (rev 9 / current):** PLAN — rule 6 :92; §3.1 coverage table :141–147
(commands row fixed to 21 tests :269–449; :144 = T10/T18/T19 boundary cite);
T04 :201, T05 :202 (amended), T06 :203, T09 :219 (ruling folded), T10 :220
(twin banked), T11 :221, T14 :224, T19 :238, T22 :241, T24 :248, T27 :251; rev
log :330+ (rev 8), :352+ (rev 9). architecture.md — §2.3 rows: #2–9 :200–207,
#17–28 :215–226, #42–48 :240–246; §4.3 flows :551–631 (F21 :626, F22 :631);
Appendix A :807 (Menus row :836, RV-1 :8/:782). ux.md — D-9 :728 (+:174/:684/:876;
:174 stale cite → T27). DECISIONS.md — D9 :202, D10 :238, D12 :286–298.

## 5. Crossings and stale-snapshot log (all benign; tree arbitrates)

1. Lead's 6-vs-8 commit list. 2–3. Architect's staging warnings ×2.
4. Architect's T09-note premise (verdict/call already sent). 5. Packager's
"34 tests" vs live 39+6 (run-time counting discipline adopted). 6. Architect's
quiescent ping vs my pre-ping "only owed item" phrasing. 7. Architect's T10
addendum vs my reconcile flag (baseline note voided by rev 8 both directions).
8. Architect's stale T05 gate wording vs my objection wire (resolved: rev 9
makes their explicit ack the release token — issued).

**Self-corrections (the class binds me too):** update_title anchor :1022 →
actual :1035 (architect's example was right); tests/packaging.rs 94 → 93
(packager's live count right); write_to Err-arm span variants normalized to
brace-inclusive :1346–1351 with :1348 as the single cited anchor. Owner-side
cite corrections on the record: packager's PLAN ":181" → live :202; architect's
PLAN ":208" → :220 (pre-rev-8-valid). Rev 9 fixed PLAN's stale commands.rs
count (22 → 21, live-verified).

*Maintained by the reviewer; lead commits. Wire traffic between teammates is
the operative channel — this log is the durable index, not a replacement.*
