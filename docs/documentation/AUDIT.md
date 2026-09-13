# Documentation audit

Every user-facing or developer-facing documentation claim was checked against
the source, the vendored dependencies, `cargo test --locked` output, and the
running app (release binary on the live COSMIC/Wayland session, 2026-09-13).

## README.md (before rewrite)

The feature list was already largely accurate — the 3.0.0 rewrite kept the
documented surface. Verified claims: menu bar and check column, file
lifecycle, editing commands, Find/Replace/Go To, font dialog, F5 stamp, word
wrap + status bar, color schemes, unsaved-changes flow, single instance,
config persistence, tech stack, dependency list, `just` recipes, Rust 1.93+
(libcosmic's `rust-version`).

Problems found and resolved:

| Claim | Verdict | Resolution |
|---|---|---|
| No end-user installation section at all | INCOMPLETE | Added: gosh remote (with the caveat it still serves 2.0.4), local Flatpak build, native `just install` |
| Flatpak build commands go straight to `flatpak-builder` | INCORRECT on a clean checkout | `cargo build --frozen --offline` requires `vendor/` + `.cargo/config.toml`, both gitignored and produced by `scripts/vendor.sh`. Added the vendor step |
| Find bar features | INCOMPLETE | "Match case" checkbox was undocumented; added |
| Shortcuts | INCOMPLETE | No list existed. Added the full table. Note: the migration docs' "G-1" claim that shortcuts fire only with editor focus turned out to be **wrong** — the custom-bound keys fire app-wide (except under modal dialogs); documented the real model |
| Go To availability | MISSING | Documented: greyed out while Word Wrap is on |
| File formats | MISSING | Documented UTF-8-only strict load and byte-exact CRLF/mixed-ending round-trip |
| Right-click editor menu | MISSING | Exists by libcosmic default (`has_context_menu`); documented |
| Single document / CLI | INCOMPLETE | Documented one-document design, first-arg-only rule, no CLI flags |
| Undo | INCOMPLETE | Documented the 100-entry cap |
| AI-development transparency notice | MISSING | Added |
| License / contributing | MISSING | Added license section and CONTRIBUTING.md link |
| "Current release: **3.0.0**", "leading check column" | VERIFIED | Kept — both strings are pinned by `tests/packaging.rs` |

## docs/migration/ (PLAN.md, architecture.md, DECISIONS.md, packaging.md, ux.md, review-phase1.md, review-phase2.md)

~5,600 lines of internal process documentation for an agent-team migration
project that ran 2026-09-10/11 and stopped after task T06. It was never
written for users or contributors of the app.

| Problem | Classification |
|---|---|
| Describes a workflow, not the application: ownership maps, objection protocols, gate ramps, reviewer sign-off records | OUTDATED — process concluded mid-flight; the repo is the released 3.0.0 app |
| Tasks T07–T27 (except T13) never landed; docs still present them as the live plan | MISLEADING — implies `scripts/verify.sh`, `scripts/smoke-test.sh`, `scripts/ci.sh`, a CI workflow, and four more `src/app_*_tests.rs` files exist or are in progress. None do |
| UX fixes T15–T23 (focus handling, disabled menu states, accessible names, About attribution, font enumeration) documented as planned work | UNVERIFIABLE as product docs — none are in the code |
| Environment specifics (Ubuntu host, `/home/gosh/.cache/notepad-v2.0.4/` parity source, agent sandbox details) | OUTDATED — machine and checkout no longer exist |
| architecture.md subsystem mapping and DECISIONS.md D8/D9/D10/D14 | VERIFIED and still true — distilled into `docs/ARCHITECTURE.md` |
| ux.md §1 parity checklist (~90 rows vs. v2.0.4 source) | UNVERIFIABLE — the v2.0.4 source it references is not in this repo |

Resolution: removed from the working tree. Git history preserves them in
full. Durable, verified facts were carried into `docs/ARCHITECTURE.md`.

## plans/ (bugfix-pass.md, libcosmic-rewrite.md)

Completed planning checklists for the 3.0.0 rewrite (every item ticked).
Historically accurate, but they describe the work of producing this code, not
the app itself. Removed; history preserves them.

## data/com.goshapps.Notepad.metainfo.xml

All claims verified against the code: feature list, release history, identity,
portal dialogs, persistence. Kept as-is.

## tests/packaging.rs

Not documentation, but it pins two README strings ("Current release:
**3.0.0**", "leading check column"), the absence of "Vaughan", and the Gosh
copyright string. The rewritten README keeps all of them; no test changes
needed.

## Code comments checked

- `src/app.rs` comments about menu check-column alignment, strict UTF-8 (D8),
  test seams — all match the code they describe.
- `src/single_instance.rs` header comment (protocol description) — accurate.
- `scripts/vendor.sh` header comment (cache contract) — accurate.
- `src/commands.rs` doc comments — match test-verified behavior.
- Several comments cite `docs/migration/*` file:line references and task IDs
  (T02, T13, D8, etc.). These are historical provenance notes; the referenced
  files are preserved in git history. Left in place — they describe *why* the
  code looks the way it does.
