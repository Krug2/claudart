import 'dart:io';
import 'dart:isolate';

Future<void> runOrchestrate(List<String> args) async {
  final override = Platform.environment['CLAUDART_ORCHESTRATOR'];
  final package = await Isolate.resolvePackageUri(
    Uri.parse('package:claudart/commands/orchestrate.dart'),
  );
  final script = override != null
      ? File(override)
      : package != null
          ? File.fromUri(package.resolve('../../orchestrator/cli.cjs'))
          : null;
  if (script == null || !script.existsSync()) {
    stderr.writeln('Set CLAUDART_ORCHESTRATOR to orchestrator/cli.cjs or run claudart-orchestrate directly.');
    exitCode = 1;
    return;
  }
  final process = await Process.start(
    'node',
    [script.path, ...args],
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}
