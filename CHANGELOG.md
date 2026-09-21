# Changelog

## 2.0.0

**Breaking:** `ClaudeRunner` (exported via `pipeline_executor.dart`) gained a
`bare` named parameter. Any code constructing `PipelineExecutor(runner: ...)`
with a function literal that doesn't declare `bare` will fail to type-check;
add `bool bare = false` to the closure's parameter list. No compatibility
adapter provided — `ClaudeRunner` has no known external consumers (no
pub.dev publish, no other package in this workspace imports it; zedup has
an unrelated same-named local type).

- `AgentStep` gained `postProcess` (rewrite a step's output before it's
  stored/routed on) and `bare` (passes `--bare` to the claude CLI
  subprocess — no built-in step sets it; see the doc comment on the field
  for why not).
- `PipelineExecutor` applies `postProcess` before routing and wires `bare`
  through to `ClaudeRunner`.
- `flow`'s plan/construct steps inject a project directory/enum index so
  generated handoffs can't reference paths or types that don't exist.
- `suggest`'s applier step now sends/receives only the analysis sections a
  change plan targets, merged back into the full document, instead of
  round-tripping all six sections every refinement pass.

## 1.0.0

Initial release.

- `claudart` interactive launcher — lists workspace projects, routes into setup workflow
- `claudart init` — scaffolds workspace with generic Dart/Flutter/BLoC/Riverpod/testing knowledge
- `claudart init --project <name>` — creates project-specific knowledge file
- `claudart link` — symlinks workspace into project, reads `pubspec.yaml` to embed SDK constraints in `CLAUDE.md`
- `claudart unlink` — removes workspace symlinks cleanly
- `claudart setup` — prompts for bug context, writes `handoff.md`
- `claudart status` — prints active handoff state
- `claudart teardown` — classifies session learnings, archives handoff, suggests commit message
- `FileIO` and `ProcessRunner` interfaces for testable I/O injection
- `MemoryFileIO` and `mocktail`-based mocks for unit testing without disk access
