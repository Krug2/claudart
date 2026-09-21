// pipeline_executor_test.dart — PipelineExecutor mechanics: postProcess and
// bare, isolated from any real flow/suggest/debug business steps.
//
// agent_pipeline_test.dart covers PipelineFlowType × PipelineFeature — the
// business flows. This file covers the executor's own step-independent
// contracts: postProcess rewrites what's stored and routed on, and bare
// reaches the runner. Minimal custom AgentSteps, no LLM.

import 'package:claudart/pipeline/agent_model.dart';
import 'package:claudart/pipeline/agent_step.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:claudart/pipeline/pipeline_event.dart';
import 'package:claudart/pipeline/pipeline_executor.dart';
import 'package:claudart/pipeline/route_tag.dart';
import 'package:claudart/pipeline/step_route.dart';
import 'package:claudart/pipeline/usage.dart';
import 'package:test/test.dart';

const _projectRoot = '/tmp/test-project';

PipelineContext _ctx() => const PipelineContext(
      projectRoot: _projectRoot,
      bug: '',
      expected: '',
      files: [],
    );

void main() {
  group('PipelineExecutor — postProcess', () {
    test('stores the postProcess result, not the raw runner output', () async {
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
        postProcess: (raw, ctx) => raw.toUpperCase(),
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          bool bare = false,
        }) async =>
            (text: 'raw output', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0)),
      );

      final ctx = await exec.runFuture(
        steps: [step],
        ctx: _ctx(),
        displayStep: 1,
        displayTotal: 1,
      );

      expect(ctx['a'], equals('RAW OUTPUT'));
    });

    test('routing matches against the postProcess result, not the raw text — '
        'lets postProcess inject a tag the raw output never emitted', () async {
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
        routes: const {RouteTag.handoff: Complete()},
        postProcess: (raw, ctx) => '<${RouteTag.handoff.wireTag}>$raw</${RouteTag.handoff.wireTag}>',
      );
      // A second step that would only ever run via routing fallthrough —
      // run() advances to the next step in `steps` when no route matches.
      // If it starts, routing missed the tag postProcess injected (i.e.
      // matched against the raw, untagged text instead).
      final decoy = AgentStep(
        id: 'decoy',
        label: 'Decoy',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          bool bare = false,
        }) async =>
            (text: 'no tags here', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0)),
      );

      final events = await exec
          .run(steps: [step, decoy], ctx: _ctx(), displayStep: 1, displayTotal: 2)
          .toList();

      // Note: PipelineCompleted always fires exactly once regardless of
      // whether a route matched (a fallthrough past the last step also
      // completes) — asserting on it alone wouldn't prove routing used the
      // injected tag. Asserting decoy never started does: Complete()
      // terminates the pipeline immediately after step 'a' only if the
      // tag postProcess injected was actually matched.
      final startedIds = events.whereType<AgentStarted>().map((e) => e.stepId).toList();
      expect(startedIds, equals(['a']));
      expect(events.whereType<PipelineCompleted>(), hasLength(1));
    });

    test('no postProcess set → raw output stored unchanged', () async {
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          bool bare = false,
        }) async =>
            (text: 'unchanged', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0)),
      );

      final ctx = await exec.runFuture(
        steps: [step],
        ctx: _ctx(),
        displayStep: 1,
        displayTotal: 1,
      );

      expect(ctx['a'], equals('unchanged'));
    });
  });

  group('PipelineExecutor — bare', () {
    test('AgentStep.bare reaches the runner call', () async {
      bool? capturedBare;
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
        bare: true,
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          bool bare = false,
        }) async {
          capturedBare = bare;
          return (text: '', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0));
        },
      );

      await exec.runFuture(steps: [step], ctx: _ctx(), displayStep: 1, displayTotal: 1);

      expect(capturedBare, isTrue);
    });

    test('AgentStep.bare defaults to false', () async {
      bool? capturedBare;
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          bool bare = false,
        }) async {
          capturedBare = bare;
          return (text: '', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0));
        },
      );

      await exec.runFuture(steps: [step], ctx: _ctx(), displayStep: 1, displayTotal: 1);

      expect(capturedBare, isFalse);
    });
  });
}
