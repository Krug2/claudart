# claudart Audit — feature/bare-string-lint

> Working tracker for this branch, not a public document. Not the same thing
> as `README.md` (current released state) or `PLAN.md` (roadmap) — see
> CLAUDE.md's document hierarchy. This file is scoped to the branch and can
> be deleted once the audit closes out; findings that should persist belong
> in PLAN.md, docs/design.md, or docs/session_log.md instead.

## Scope

Auditing claudart's session paradigm end to end: `link` → `setup` →
`suggest`/`save`/`debug` → `teardown`, plus the surrounding lifecycle
commands (`rotate`, `kill`, `preflight`, `scan`, `report`, `map`). Looking
at: where each command collects metadata, how that metadata is passed to
templates, and how session state is tracked — then tightening whatever
doesn't match its own documented intent.

## Status legend

`done` — merged to `main` · `landed` — on this branch, in PR #37 or later ·
`open` — found, not yet fixed · `deciding` — needs a call before fixing

## Findings

| # | Area | Status | Summary |
|---|------|--------|---------|
| 1 | `link.dart` | done (`main` @ `bb18297`) | Real (non-symlinked) `.claude/` never received template writes — `<projectRoot>/.claude/commands/` silently drifted stale forever. Fixed: sync into both bare and suffixed filenames when the symlink is skipped, without deleting either. |
| 2 | lint enforcement | landed (PR #37) | "No bare strings" rule had no enforcement beyond `missing_enum_constant_in_switch`, which can't catch a switch that was never typed on an enum. Added `tool/claudart_lints` custom_lint plugin, rule `bare_string_for_enum`. |
| 3 | `bin/claudart.dart` | open | The command dispatch switch is exactly what rule #2 now flags — 21 subcommands switched on raw strings, 6 of which (`suggest`/`debug`/`setup`/`save`/`teardown`/`flow`) duplicate `AgentFlow`'s enum variants as a second, unlinked bare-string source. Needs a `ClaudartCommand`-style enum covering all 21, or reuse of `AgentFlow` extended to cover the non-pipeline commands too. |
| 4 | `kill.dart:61-64` | open | Checks `linkExists('.claude')` to decide whether a session is active; reports "No active session symlink found" on a real (non-symlinked) `.claude/` even mid-session. Same root-cause class as #1 — code assumed the symlink always exists. Breaks self-hosting on this exact repo. |
| 5 | honored workspace `knowledge/` | open | `~/dev/dev_tools/claude/claudart/knowledge/` doesn't exist. `workspace.json.session.knowledge` lists 4 files (`dart_flutter`, `testing`, `enum-vs-variable`, `git-authorship`) that resolve nowhere. `/setup` (Agent 1, scaffold compiler) would fail or produce an empty scaffold if run today. |
| 6 | scaffold.md protocol | deciding | `docs/design.md` formally proves an Agent-1/Agent-2 split (`K_scaffold` vs `K_session`) built around `/setup` compiling `scaffold.md`. After fix #1, every command template (bare and suffixed) reads `handoff.md`/`skills.md` directly with zero `scaffold.md` dependency. Is the scaffold protocol still intended, or is `docs/design.md`'s proof describing a design that's now dead in practice? Needs a decision before anything here gets "fixed" — could go either way (revive scaffold.md properly, or retire the proof). |
| 7 | `good_intentions` (jolexxa) | parked | Researched: static analyzer-based architecture-layer validation (view→viewModel→useCase→repository→dataSource) + PlantUML diagram, via a Dart build hook. Blocked: requires `sdk: ^3.11.0`, this machine has 3.8.1. Also a layering mismatch — none of claudart (CLI), dartrix (test matrix), or zedup (bloc-free nocterm TUI) are shaped like the CRUD/bloc apps this tool targets. Not adopting as-is. |
| 8 | dartrix `PARADIGMS.md` PR | deciding, agreed direction | Architecture/paradigm ownership belongs to dartrix (`PARADIGMS.md` already says so explicitly: "dartrix — the law... claudart — applies the law"). If dependency-layering validation (the useful idea inside finding #7) is wanted, it must land as a proposed rule under dartrix's `architecture` dimension (or a new dimension) per `PARADIGMS.md`'s own Growth section, not invented unilaterally in claudart. PR not yet drafted. |
| 9 | `StackType`/`ProofNotation` → paradigm-package resolution | open | `lib/workspace/workspace_config.dart` already types `StackType` (dart/flutter/bloc/riverpod/typescript/react/swift/kotlin) and `ProofNotation` (dartGrounded/tsGrounded/generic) — the multi-language extension point already exists, but is completely unwired. `WorkspaceConfig.load()` is called in `suggest.dart`/`debug.dart`/`flow.dart`/`rotate.dart`/`scan.dart`, yet only `.owner.strict` is ever read — `.project.stack` drives nothing. Templates (`suggest_template.dart` etc.) hardcode `knowledge/generic/dart.md`/`testing.md` regardless of stack. No concept exists yet of "which package owns the paradigm for this stack" (dartrix for dart/flutter/bloc/riverpod; nothing modeled for typescript/python/etc.). Needed for "a new workspace requires suggest for Python" to actually work. |
| 10 | duplicate `suggest` implementations | open, needs investigation | Two independent things both called "suggest": `runSuggest` in `lib/commands/suggest.dart` (a real Dart-executed pipeline — haiku reads scope files, sonnet writes handoff KT, per `PLAN.md`) and the markdown `/suggest-claudart` skill template (instructs an interactive editor agent to do the same job conversationally). Relationship/overlap between the two not yet investigated — surfaced in passing while checking `WorkspaceConfig` usage, not yet chased down. |
| 11 | `logic_blocks` (jolexxa/bestie) | researched, split recommendation | Hierarchical statechart library, SDK-compatible (`>=3.5.0 <4.0.0`, unlike finding #7). Doesn't fit claudart's CLI — every command is a fresh short-lived process, state must be durable/file-backed for that reason, and LogicBlocks assumes a persistent in-memory instance. Strong fit for **zedup's TUI** specifically — long-running `nocterm` process, and `bestie` (same framework) already has a reusable `logic_bloc_adapter` reference implementation. Recommendation: don't touch claudart's `HandoffStatus`/`SessionState` model; consider `logic_blocks` for zedup's pane/session view state instead. |
| 12 | workspace-config → state-object idea | deciding | User's original ask ("once claudart is linked, a config communicates workspace state, updates a state object on construction") splits into two different targets depending on scope: the CLI's `WorkspaceConfig`/`SessionState` (durable-file model — see #9 for the actual gap there) vs. zedup's live view state (where #11's `logic_blocks` recommendation applies). Needs a decision on which one before scoping further. |

## Topology notes (reference, not action items)

- `link` writes exactly two things: `registry.json` (durable addressing —
  `projectRoot → workspacePath`, re-read by every other command) and
  `.claude/commands/*.md` (frozen template snapshot, only updated when
  `link` runs again — paths are string-interpolated in at generation time,
  not resolved live).
- Session *state* (`HandoffStatus`) lives entirely in `handoff.md`, never
  touched by `link`.
- `AgentFlow` enum is the source of truth for the 6 pipeline flows
  (`suggest`, `debug`, `setup`, `save`, `teardown`, `flow`) — model,
  steps, and command-file template all keyed off one enum. The other 15
  CLI commands have no equivalent typed model (see finding #3).

## Next up

Going through the command list in order (per `bin/claudart.dart`'s own
usage string) to audit each one the same way `link` was audited — metadata
in, template/state out. `setup` is next.
