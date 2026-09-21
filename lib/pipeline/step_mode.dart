// step_mode.dart — how the claude subprocess is invoked for a pipeline step

/// How the claude subprocess is invoked for this step.
enum StepMode {
  /// Standard: ambient OAuth session, CLAUDE.md loaded, project context applies.
  project,

  /// Bare: passes `--bare` to the claude CLI. No CLAUDE.md, requires
  /// ANTHROPIC_API_KEY. A step in a normal OAuth session will get
  /// "Not logged in" with this variant — verified live. No built-in
  /// pipeline step uses this; only tests exercising the mechanism do.
  bare,
}
