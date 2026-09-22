// step_status_test.dart — StepStatus.fromEvent, the canonical PipelineEvent
// → StepStatus projection. One test() per PipelineEvent subtype, per
// dartrix's testing paradigm — a loop here would collapse every variant's
// pass/fail into one result and hide failures after the first.

import 'package:claudart/pipeline/agent_model.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:claudart/pipeline/pipeline_event.dart';
import 'package:claudart/pipeline/step_status.dart';
import 'package:claudart/pipeline/usage.dart';
import 'package:test/test.dart';

void main() {
  group('StepStatusFromEvent.fromEvent', () {
    test('AgentStarted maps to running', () {
      const event = AgentStarted(
        stepId: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        displayStep: 1,
        displayTotal: 1,
      );
      expect(StepStatusFromEvent.fromEvent(event), equals(StepStatus.running));
    });

    test('AgentCompleted maps to done', () {
      const event = AgentCompleted(stepId: 'a', usage: Usage());
      expect(StepStatusFromEvent.fromEvent(event), equals(StepStatus.done));
    });

    test('AgentFailed maps to failed', () {
      const event = AgentFailed(stepId: 'a');
      expect(StepStatusFromEvent.fromEvent(event), equals(StepStatus.failed));
    });

    test('AgentEscalating carries no per-step status change', () {
      const event = AgentEscalating(question: 'which file?');
      expect(StepStatusFromEvent.fromEvent(event), isNull);
    });

    test('AgentResumed carries no per-step status change', () {
      const event = AgentResumed();
      expect(StepStatusFromEvent.fromEvent(event), isNull);
    });

    test('PlanDraft carries no per-step status change', () {
      const event = PlanDraft(plan: 'draft text');
      expect(StepStatusFromEvent.fromEvent(event), isNull);
    });

    test('AwaitingApproval carries no per-step status change', () {
      const event = AwaitingApproval();
      expect(StepStatusFromEvent.fromEvent(event), isNull);
    });

    test('PipelineCompleted carries no per-step status change', () {
      const event = PipelineCompleted(
        ctx: PipelineContext(projectRoot: '/tmp', bug: '', expected: '', files: []),
      );
      expect(StepStatusFromEvent.fromEvent(event), isNull);
    });
  });
}
