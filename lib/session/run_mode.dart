// run_mode.dart — how much a command asks the human versus decides itself
//
// Not StepMode (lib/pipeline/step_mode.dart) — that's how a single claude
// subprocess call is invoked. This is a command-level axis: does the
// command stop and ask at each decision point (interactive, the default,
// every prompt/confirm/pick call reaches a real human), or does it resolve
// every decision itself from the same signals it would have offered as
// defaults, then print a summary for the human to verify afterward
// (headless)? Headless never invents a decision a human wasn't already
// going to be offered as the pre-filled default — it just stops asking
// and prints what it chose.

enum RunMode {
  /// Every prompt/confirm/pick reaches a real human. The default.
  interactive,

  /// No prompt/confirm/pick blocks on human input. Every decision resolves
  /// to whatever would have been the pre-filled default (agent-suggested
  /// value, heuristic, or a documented fallback) — never invented, never
  /// silently different from what interactive mode would have offered.
  /// The command prints a full summary of what it did so the human
  /// verifies the outcome instead of each individual choice.
  headless,
}
