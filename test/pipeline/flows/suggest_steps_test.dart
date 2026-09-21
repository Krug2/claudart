// suggest_steps_test.dart — SuggestSteps.applier's target-section fallback.
//
// _applierPrompt sends only the sections a change plan targets, to avoid
// round-tripping the full six-section analysis every refinement pass. If a
// targeted tag is missing from the analysis (model forgot to emit it), the
// naive version silently dropped it from what the applier sees — this locks
// in the fallback: any missing target sends the full analysis instead.

import 'package:claudart/pipeline/flows/suggest_steps.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:test/test.dart';

const _projectRoot = '/tmp/test-project';

PipelineContext _ctx({required String reasonerOut, required String plannerOut}) =>
    PipelineContext(
      projectRoot: _projectRoot,
      bug: '',
      expected: '',
      files: const [],
    ).withSlot('reasoner', reasonerOut).withSlot('planner', plannerOut);

void main() {
  group('SuggestSteps.applier — target-section fallback', () {
    test('all targeted sections present → prompt contains only those sections', () {
      const analysis = '<ROOT_CAUSE>rc</ROOT_CAUSE>'
          '<SCOPE_FILES>sf</SCOPE_FILES>'
          '<CONSTRAINTS>c</CONSTRAINTS>';
      const changePlan = '<CHANGES>Update CONSTRAINTS only</CHANGES>';

      final prompt = SuggestSteps.applier(1).buildPrompt(
        _ctx(reasonerOut: analysis, plannerOut: changePlan),
      );

      expect(prompt, contains('<CONSTRAINTS>c</CONSTRAINTS>'));
      expect(prompt, isNot(contains('<ROOT_CAUSE>')));
    });

    test('a targeted section missing from the analysis → falls back to the '
        'full analysis, not a partial prompt missing that section entirely', () {
      // Analysis is missing SCOPE_FILES even though the change plan targets it.
      const analysis = '<ROOT_CAUSE>rc</ROOT_CAUSE>'
          '<CONSTRAINTS>c</CONSTRAINTS>';
      const changePlan = '<CHANGES>Update SCOPE_FILES and CONSTRAINTS</CHANGES>';

      final prompt = SuggestSteps.applier(1).buildPrompt(
        _ctx(reasonerOut: analysis, plannerOut: changePlan),
      );

      // Full analysis present (fallback), not just the extractable subset.
      expect(prompt, contains('<ROOT_CAUSE>rc</ROOT_CAUSE>'));
      expect(prompt, contains('<CONSTRAINTS>c</CONSTRAINTS>'));
    });

    test('no recognized section names in the change plan → full analysis sent', () {
      const analysis = '<ROOT_CAUSE>rc</ROOT_CAUSE><CONSTRAINTS>c</CONSTRAINTS>';
      const changePlan = '<CHANGES>Something vague</CHANGES>';

      final prompt = SuggestSteps.applier(1).buildPrompt(
        _ctx(reasonerOut: analysis, plannerOut: changePlan),
      );

      expect(prompt, contains('<ROOT_CAUSE>rc</ROOT_CAUSE>'));
      expect(prompt, contains('<CONSTRAINTS>c</CONSTRAINTS>'));
    });
  });
}
