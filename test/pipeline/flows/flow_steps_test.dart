// flow_steps_test.dart — FlowSteps.clarify's postProcess contract.
//
// clarify's postProcess wraps untagged prose in <ANSWER> so a plan feedback
// loop doesn't silently fall through when the model forgets to tag its
// output. No test exercised this — a regression here would only surface as
// "plan gets stuck," not a compile or obvious runtime error.

import 'package:claudart/pipeline/flows/flow_steps.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:test/test.dart';

const _projectRoot = '/tmp/test-project';

PipelineContext _ctx() => const PipelineContext(
      projectRoot: _projectRoot,
      bug: '',
      expected: '',
      files: [],
    );

void main() {
  group('FlowSteps.clarify.postProcess', () {
    test('untagged prose is wrapped in <ANSWER>', () {
      final result = FlowSteps.clarify.postProcess!('the label field is String?', _ctx());
      expect(result, equals('<ANSWER>the label field is String?</ANSWER>'));
    });

    test('output already containing <ANSWER> is left unchanged', () {
      const tagged = '<ANSWER>label is String?</ANSWER>';
      final result = FlowSteps.clarify.postProcess!(tagged, _ctx());
      expect(result, equals(tagged));
    });

    test('output already containing <UNKNOWN> is left unchanged', () {
      const tagged = '<UNKNOWN>not enough context to say</UNKNOWN>';
      final result = FlowSteps.clarify.postProcess!(tagged, _ctx());
      expect(result, equals(tagged));
    });

    test('empty output is still wrapped — an empty ANSWER, not silently dropped', () {
      final result = FlowSteps.clarify.postProcess!('', _ctx());
      expect(result, equals('<ANSWER></ANSWER>'));
    });
  });
}
