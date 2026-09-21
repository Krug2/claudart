// debug_steps_test.dart — DebugSteps.implementer's `mode` contract.
//
// No dedicated test file existed for debug_steps.dart.

import 'package:claudart/pipeline/flows/debug_steps.dart';
import 'package:claudart/pipeline/step_mode.dart';
import 'package:test/test.dart';

void main() {
  test('implementer runs in StepMode.project, NOT StepMode.bare — verified '
      'live that --bare requires ANTHROPIC_API_KEY/apiKeyHelper and never '
      'reads OAuth or keychain, which is this pipeline\'s standard auth '
      'path (a normal OAuth session gets "Not logged in" under --bare); '
      'StepMode.bare here would break claudart debug for the common case, '
      'not just guard against a project CLAUDE.md overriding the system '
      'prompt', () {
    expect(DebugSteps.implementer.mode, equals(StepMode.project));
  });
}
