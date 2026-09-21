// flow_steps.dart — AgentStep definitions for the flow pipeline
//
// The flow pipeline is an agent-constructed session: the user provides a
// freeform prompt; agents categorize intent, generate a dependency-ordered
// plan, await approval, then construct the handoff automatically.
//
// Steps:
//   [categorize] haiku  — classifies input using the τ taxonomy; emits
//                         <CATEGORY>, <INTENT>, <COMPLEXITY>, <MODEL>
//   [plan]       sonnet — generates a dependency-ordered implementation plan;
//                         emits <PLAN> (ApprovalGate → construct) or
//                         <QUESTION> (QuestionBranch → clarify)
//   [clarify]    haiku  — resolves questions from plan against input context;
//                         emits <ANSWER> (FeedBackTo → plan) or
//                         <UNKNOWN> (EscalateUser → plan)
//   [construct]  sonnet — writes the full handoff structure from the approved
//                         plan; emits <HANDOFF> (Complete)
//
// Approval gate: plan → ApprovalGate(RouteTag.plan, 'construct')
//   User sees the plan before construct runs.
//   Declining aborts and yields PipelineCompleted with pre-construct ctx.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../agent_model.dart';
import '../agent_step.dart';
import '../agents/categorization.dart';
import '../pipeline_context.dart';
import '../route_tag.dart';
import '../step_route.dart';

abstract final class FlowSteps {
  /// Built once at class load from the categorize taxonomy
  /// (`CategorizeTag.values` × each tag's `.allowedValues`) so a
  /// rename of any enum variant — `AgentCategory.feature` →
  /// `AgentCategory.featureWork`, or adding `IntentClass.review` —
  /// propagates into the LLM-facing prompt without manual edits.
  ///
  /// Closes the prompt/parser drift seam that silently defeats
  /// `ComplexityTier`-driven model routing (slice 5 of the planner
  /// audit). `static final` (not `const`) because the builder reads
  /// each enum's `.values`.
  static final String _categorizeSystem = buildCategorizePrompt();

  static const String _planSystem =
      'You are a dependency-ordered planner. Given a classified task, generate '
      'a structured implementation plan where each item lists what must exist '
      'before it can start. Output <PLAN>...</PLAN> with numbered items ordered '
      'by dependency, or <QUESTION>...</QUESTION> if critical context is missing. '
      'Do not propose features, files, or abstractions beyond what the task '
      'explicitly requires. When uncertain about project structure, output QUESTION.';

  static const String _clarifySystem =
      'You are a context resolver. Given a question and the original user input, '
      'determine if the answer can be inferred from what was provided. '
      'Output <ANSWER>...</ANSWER> if resolvable, or <UNKNOWN>...</UNKNOWN> if not.';

  static const String _constructSystem =
      'You are a handoff constructor. Given an approved plan, construct a '
      'complete handoff.md document. Output only <HANDOFF>...</HANDOFF> '
      'with these exact section headers in order. '
      'Use only directory paths and type names from the project index provided — '
      'do not reference any path, directory, or type not listed there.\n'
      '## Status\nready-for-suggest\n\n'
      '## Bug\n(concise bug or goal description)\n\n'
      '## Expected Behavior\n(what should happen)\n\n'
      '## Root Cause\n(key insight from the plan)\n\n'
      '## Scope\n'
      '### Files in play\n'
      '- `relative/path/to/file` — what changes\n\n'
      '### Must not touch\n(files or patterns to leave alone)\n\n'
      '## Constraints\n(implementation constraints from the plan)';

  // ── Steps ─────────────────────────────────────────────────────────────────

  static final AgentStep categorize = AgentStep(
    id:    'categorize',
    label: 'Categorizing intent',
    model: AgentModel.haiku,
    systemPrompt: _categorizeSystem,
    buildPrompt: (PipelineContext ctx) =>
        'Classify this task:\n\n${ctx.bug}',
    routes: const {},
  );

  /// Sonnet is the fallback when the categorize step's output is
  /// missing or ambiguous — per the audit constraint "degrade to
  /// sonnet on ambiguity, the cost win comes from confident haiku
  /// routing on atomic tasks."
  static const AgentModel _planFallbackModel = AgentModel.sonnet;

  /// Reads `<CATEGORY>` / `<INTENT>` / `<COMPLEXITY>` from the
  /// categorize step's output and consults the τ matrix
  /// (`routeModel`) for the right model. Falls back to sonnet when
  /// any tag is missing or maps to an unknown enum variant.
  static AgentModel _planModelSelector(PipelineContext ctx) =>
      modelForCategorizeOutput(
        ctx[PipelineSlot.categorize] ?? '',
        fallback: _planFallbackModel,
      );

  static final AgentStep plan = AgentStep(
    id:    'plan',
    label: 'Generating plan',
    model: _planFallbackModel,
    modelSelector: _planModelSelector,
    systemPrompt: _planSystem,
    buildPrompt: (PipelineContext ctx) {
      final classification = ctx[PipelineSlot.categorize] ?? '';
      final clarification  = ctx.clarification ?? '';
      final index          = _projectIndex(ctx.projectRoot);
      return [
        'Classification:\n$classification',
        'Task:\n${ctx.bug}',
        if (index.isNotEmpty) index,
        if (clarification.isNotEmpty) 'Additional context:\n$clarification',
      ].join('\n\n');
    },
    routes: const {
      RouteTag.plan: ApprovalGate(
        planTag: RouteTag.plan,
        nextStepId: 'construct',
      ),
      RouteTag.question: QuestionBranch('clarify'),
    },
  );

  static final AgentStep clarify = AgentStep(
    id:    'clarify',
    label: 'Resolving question',
    model: AgentModel.haiku,
    systemPrompt: _clarifySystem,
    buildPrompt: (PipelineContext ctx) =>
        'Question: ${ctx[PipelineSlot.question] ?? ''}\n\nOriginal input: ${ctx.bug}',
    routes: const {
      RouteTag.answer:  FeedBackTo('plan'),
      RouteTag.unknown: EscalateUser('plan'),
    },
    // If clarify produces prose without tags, treat the full output as an
    // ANSWER and feed it back to plan rather than silently falling through.
    postProcess: (text, ctx) {
      if (!text.contains('<${RouteTag.answer.wireTag}>') &&
          !text.contains('<${RouteTag.unknown.wireTag}>')) {
        return '<${RouteTag.answer.wireTag}>$text</${RouteTag.answer.wireTag}>';
      }
      return text;
    },
  );

  static final AgentStep construct = AgentStep(
    id:    'construct',
    label: 'Constructing handoff',
    model: AgentModel.sonnet,
    systemPrompt: _constructSystem,
    buildPrompt: (PipelineContext ctx) {
      final plan  = ctx[PipelineSlot.plan] ?? '';
      final index = _projectIndex(ctx.projectRoot);
      return [
        'Approved plan:\n$plan',
        'Original task:\n${ctx.bug}',
        if (index.isNotEmpty) index,
      ].join('\n\n');
    },
    routes: const {
      RouteTag.handoff: Complete(),
    },
  );

  static final List<AgentStep> all = [categorize, plan, clarify, construct];
}

// Returns a compact snapshot of the project's directory structure and known
// enum types. Injected into plan/construct so agents cannot invent paths or
// types that do not exist in the actual codebase.
String _projectIndex(String projectRoot) {
  final lines = <String>[];

  // Directory tree for test/ and lib/src/
  final scanRoots = ['test', p.join('lib', 'src')];
  final dirs = <String>[];
  for (final root in scanRoots) {
    final dir = Directory(p.join(projectRoot, root));
    if (!dir.existsSync()) continue;
    dirs.add(root);
    dir
        .listSync(recursive: true)
        .whereType<Directory>()
        .map((d) => p.relative(d.path, from: projectRoot))
        .forEach(dirs.add);
  }
  if (dirs.isNotEmpty) {
    lines
      ..add('Existing directories (use only these as parent paths for new files):')
      ..addAll(dirs.map((d) => '  $d'));
  }

  // Enum type inventory
  final enumDir = Directory(p.join(projectRoot, 'lib', 'src', 'enums'));
  if (enumDir.existsSync()) {
    final names = <String>[];
    for (final file in enumDir.listSync().whereType<File>()) {
      for (final line in file.readAsLinesSync()) {
        final m = RegExp(r'^enum\s+(\w+)').firstMatch(line);
        if (m != null) names.add(m.group(1)!);
      }
    }
    if (names.isNotEmpty) {
      lines
        ..add('')
        ..add('Known enum types (do not reference types not in this list):')
        ..add('  ${names.join(', ')}');
    }
  }

  return lines.join('\n');
}
