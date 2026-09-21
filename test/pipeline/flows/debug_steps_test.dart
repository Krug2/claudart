// debug_steps_test.dart — DebugSteps.implementer's `bare` contract.
//
// No dedicated test file existed for debug_steps.dart. `bare: true` is
// silently invisible to any caller that doesn't inspect the AgentStep
// directly — a live pipeline run can't distinguish "bare wired but false"
// from "bare wired and true" without this.

import 'package:claudart/pipeline/flows/debug_steps.dart';
import 'package:test/test.dart';

void main() {
  test('implementer runs bare — its own CLAUDE.md must not override the '
      'structured-only output contract', () {
    expect(DebugSteps.implementer.bare, isTrue);
  });
}
