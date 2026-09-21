import 'package:test/test.dart';
import 'package:claudart/commands/suggest.dart';
import 'package:claudart/registry.dart';
import 'package:claudart/paths.dart';
import 'package:claudart/pipeline/pipeline_executor.dart';
import '../helpers/mocks.dart';

// suggest_test.dart — validation-path coverage for runSuggest.
//
// Scope: only the paths reachable without stdin/arrowMenu — runSuggest
// has no injectable seam for its two stdin.readLineSync() call sites or
// its arrowMenu() call, unlike setup.dart's confirmFn/promptFn/pickFn
// pattern. Full coverage of the interactive review/refine loop needs that
// gap closed first; this covers what's safely testable today.

const _projectRoot = '/projects/my-app';
const _workspace   = '/workspaces/my-app';

class _ExitException implements Exception {
  final int code;
  const _ExitException(this.code);
}

Never _throwExit(int code) => throw _ExitException(code);

const _handoffWithScope = '''# Agent Handoff — my-app

## Status

suggest-investigating

## Bug

Something is broken.

## Expected Behavior

It should work.

## Scope

### Files in play
- `lib/foo.dart`
''';

const _handoffWithoutScope = '''# Agent Handoff — my-app

## Status

suggest-investigating

## Bug

Something is broken.

## Expected Behavior

It should work.

## Scope

### Files in play
_Not yet determined._
''';

MemoryFileIO _io({String? handoff = _handoffWithScope}) {
  const entry = RegistryEntry(
    name: 'my-app',
    projectRoot: _projectRoot,
    workspacePath: _workspace,
    createdAt: '2026-01-01',
    lastSession: '2026-03-15',
  );
  final registry = Registry.empty().add(entry);
  final io = MemoryFileIO(
    files: {
      if (handoff != null) handoffPathFor(_workspace): handoff,
    },
  );
  registry.save(io: io);
  return io;
}

/// Executor whose runner always returns null — simulates the reader step
/// producing nothing (e.g. claude CLI not installed/authenticated),
/// without ever reaching the interactive review loop.
PipelineExecutor _executorWithNoOutput() =>
    PipelineExecutor(runner: ({required model, required systemPrompt, required message, required workingDir}) async => null);

void main() {
  group('runSuggest — validation', () {
    test('exits 1 when project is not registered', () async {
      final io = MemoryFileIO(); // empty registry
      await expectLater(
        runSuggest(
          io: io,
          projectRootOverride: _projectRoot,
          exitFn: _throwExit,
        ),
        throwsA(isA<_ExitException>()),
      );
    });

    test('exits 1 when no handoff exists', () async {
      final io = _io(handoff: null);
      await expectLater(
        runSuggest(
          io: io,
          projectRootOverride: _projectRoot,
          exitFn: _throwExit,
        ),
        throwsA(isA<_ExitException>()),
      );
    });

    test('exits 1 when Scope / Files in play is empty', () async {
      final io = _io(handoff: _handoffWithoutScope);
      await expectLater(
        runSuggest(
          io: io,
          projectRootOverride: _projectRoot,
          exitFn: _throwExit,
        ),
        throwsA(isA<_ExitException>()),
      );
    });
  });

  group('runSuggest — reader step produces nothing', () {
    test('exits 1 without reaching the interactive review loop', () async {
      final io = _io();
      await expectLater(
        runSuggest(
          io: io,
          projectRootOverride: _projectRoot,
          exitFn: _throwExit,
          executor: _executorWithNoOutput(),
        ),
        throwsA(isA<_ExitException>()),
      );
    });

    test('handoff is left untouched — no partial write on reader failure', () async {
      final io = _io();
      try {
        await runSuggest(
          io: io,
          projectRootOverride: _projectRoot,
          exitFn: _throwExit,
          executor: _executorWithNoOutput(),
        );
      } on _ExitException {
        // expected
      }
      expect(io.read(handoffPathFor(_workspace)), equals(_handoffWithScope));
    });
  });
}
