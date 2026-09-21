// pipeline_executor_test.dart — PipelineExecutor mechanics: postProcess and
// mode, isolated from any real flow/suggest/debug business steps.
//
// agent_pipeline_test.dart covers PipelineFlowType × PipelineFeature — the
// business flows. This file covers the executor's own step-independent
// contracts: postProcess rewrites what's stored and routed on, and mode
// reaches the runner. Minimal custom AgentSteps, no LLM.

import 'dart:async';

import 'package:claudart/pipeline/agent_model.dart';
import 'package:claudart/pipeline/agent_step.dart';
import 'package:claudart/pipeline/pipeline_context.dart';
import 'package:claudart/pipeline/pipeline_event.dart';
import 'package:claudart/pipeline/pipeline_executor.dart';
import 'package:claudart/pipeline/route_tag.dart';
import 'package:claudart/pipeline/step_mode.dart';
import 'package:claudart/pipeline/step_route.dart';
import 'package:claudart/pipeline/usage.dart';
import 'package:test/test.dart';

const _projectRoot = '/tmp/test-project';

Future<String> _capturePrinted(Future<void> Function() action) async {
  final output = <String>[];
  await runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) => output.add(line),
    ),
  );
  return output.join('\n');
}

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
          StepMode mode = StepMode.project,
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
          StepMode mode = StepMode.project,
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
          StepMode mode = StepMode.project,
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

  group('PipelineExecutor — mode', () {
    test('AgentStep.mode reaches the runner call', () async {
      StepMode? capturedMode;
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
        mode: StepMode.bare,
      );

      final exec = PipelineExecutor(
        runner: ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          StepMode mode = StepMode.project,
        }) async {
          capturedMode = mode;
          return (text: '', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0));
        },
      );

      await exec.runFuture(steps: [step], ctx: _ctx(), displayStep: 1, displayTotal: 1);

      expect(capturedMode, equals(StepMode.bare));
    });

    test('AgentStep.mode defaults to project', () async {
      StepMode? capturedMode;
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
          StepMode mode = StepMode.project,
        }) async {
          capturedMode = mode;
          return (text: '', usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0));
        },
      );

      await exec.runFuture(steps: [step], ctx: _ctx(), displayStep: 1, displayTotal: 1);

      expect(capturedMode, equals(StepMode.project));
    });
  });

  group('PipelineExecutor.runFuture — verbose trace output', () {
    AgentStep rewritingStep() => AgentStep(
          id: 'a',
          label: 'Step A',
          model: AgentModel.haiku,
          systemPrompt: 'sys',
          buildPrompt: (_) => 'msg',
          postProcess: (raw, ctx) => raw.toUpperCase(),
        );

    ClaudeRunner staticRunner(String text) => ({
          required model,
          required systemPrompt,
          required message,
          required workingDir,
          StepMode mode = StepMode.project,
        }) async =>
            (text: text, usage: const Usage(input: 1, output: 1, cacheRead: 0, cost: 0));

    test('verbose: true prints the trace line when postProcess rewrites output', () async {
      final exec = PipelineExecutor(runner: staticRunner('raw'), verbose: true);

      final printed = await _capturePrinted(() => exec.runFuture(
            steps: [rewritingStep()],
            ctx: _ctx(),
            displayStep: 1,
            displayTotal: 1,
          ));

      expect(printed, contains('postProcess fired on "a"'));
    });

    test('verbose: false never prints the trace line, even when postProcess rewrites', () async {
      final exec = PipelineExecutor(runner: staticRunner('raw'));

      final printed = await _capturePrinted(() => exec.runFuture(
            steps: [rewritingStep()],
            ctx: _ctx(),
            displayStep: 1,
            displayTotal: 1,
          ));

      expect(printed, isNot(contains('postProcess fired')));
    });

    test('verbose: true but postProcess does not change the output — no trace line', () async {
      final step = AgentStep(
        id: 'a',
        label: 'Step A',
        model: AgentModel.haiku,
        systemPrompt: 'sys',
        buildPrompt: (_) => 'msg',
        postProcess: (raw, ctx) => raw, // identity — never "rewrites"
      );
      final exec = PipelineExecutor(runner: staticRunner('raw'), verbose: true);

      final printed = await _capturePrinted(() => exec.runFuture(
            steps: [step],
            ctx: _ctx(),
            displayStep: 1,
            displayTotal: 1,
          ));

      expect(printed, isNot(contains('postProcess fired')));
    });
  });
}
