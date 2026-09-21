import 'dart:io';
import 'package:path/path.dart' as p;
import '../file_io.dart';
import '../ui/render.dart' as render;

void runUnlink({FileIO? io, String? cwdOverride}) {
  final fileIO = io ?? const RealFileIO();
  final cwd = cwdOverride ?? Directory.current.path;

  print(render.header('CLAUDART UNLINK'));

  var removed = 0;

  for (final name in ['.claude', 'CLAUDE.md']) {
    final path = p.join(cwd, name);

    if (fileIO.linkExists(path)) {
      fileIO.deleteLink(path);
      print('✓ Removed symlink: $name');
      removed++;
    } else if (fileIO.fileExists(path) || fileIO.dirExists(path)) {
      print('⚠  $name exists but is not a symlink — skipped (not safe to delete)');
    }
  }

  if (removed == 0) {
    print('\nNo claudart symlinks found in $cwd');
  } else {
    print('\nProject directory is clean.\n');
  }
}
