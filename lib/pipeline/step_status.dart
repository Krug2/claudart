// step_status.dart — UI-facing lifecycle state of a single pipeline step
//
// Not produced by PipelineExecutor directly — the executor's real
// lifecycle model is the sealed PipelineEvent hierarchy (pipeline_event.dart).
// StepStatus is a derived projection of that stream for consumers that want
// a per-step display state (spinner glyph, colour) rather than the full
// event. `StepStatus.fromEvent` is the one canonical, tested projection —
// consumers should use it instead of re-deriving their own mapping.

import 'pipeline_event.dart';

enum StepStatus { pending, running, done, failed }

extension StepStatusFromEvent on StepStatus {
  /// Projects a [PipelineEvent] onto a [StepStatus], or `null` when the
  /// event carries no per-step status change of its own — the caller
  /// should keep whatever status it already had. Only the three events
  /// that identify a single step (`stepId`) drive a status transition;
  /// every other event is session-level (escalation pause/resume, the
  /// flow-command approval gate, pipeline completion) and leaves the
  /// active step's displayed status untouched.
  static StepStatus? fromEvent(PipelineEvent event) => switch (event) {
        AgentStarted() => StepStatus.running,
        AgentCompleted() => StepStatus.done,
        AgentFailed() => StepStatus.failed,
        AgentEscalating() ||
        AgentResumed() ||
        PlanDraft() ||
        AwaitingApproval() ||
        PipelineCompleted() =>
          null,
      };
}
