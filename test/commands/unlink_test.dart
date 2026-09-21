import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:claudart/commands/unlink.dart';
import '../helpers/mocks.dart';

const _cwd = '/projects/my-app';

void main() {
  group('runUnlink — removes symlinks', () {
    test('removes a .claude symlink', () {
      final io = MemoryFileIO(links: {p.join(_cwd, '.claude')});
      runUnlink(io: io, cwdOverride: _cwd);
      expect(io.linkExists(p.join(_cwd, '.claude')), isFalse);
    });

    test('removes a CLAUDE.md symlink', () {
      final io = MemoryFileIO(links: {p.join(_cwd, 'CLAUDE.md')});
      runUnlink(io: io, cwdOverride: _cwd);
      expect(io.linkExists(p.join(_cwd, 'CLAUDE.md')), isFalse);
    });

    test('removes both when both are symlinks', () {
      final io = MemoryFileIO(
        links: {p.join(_cwd, '.claude'), p.join(_cwd, 'CLAUDE.md')},
      );
      runUnlink(io: io, cwdOverride: _cwd);
      expect(io.linkExists(p.join(_cwd, '.claude')), isFalse);
      expect(io.linkExists(p.join(_cwd, 'CLAUDE.md')), isFalse);
    });
  });

  group('runUnlink — real directories/files are never deleted', () {
    test('a real .claude/ directory is left alone', () {
      final io = MemoryFileIO(dirs: {p.join(_cwd, '.claude')});
      runUnlink(io: io, cwdOverride: _cwd);
      expect(io.dirExists(p.join(_cwd, '.claude')), isTrue);
    });

    test('a real CLAUDE.md file is left alone', () {
      final io = MemoryFileIO(files: {p.join(_cwd, 'CLAUDE.md'): '# hi'});
      runUnlink(io: io, cwdOverride: _cwd);
      expect(io.fileExists(p.join(_cwd, 'CLAUDE.md')), isTrue);
    });
  });

  group('runUnlink — nothing to remove', () {
    test('does not throw when neither exists', () {
      final io = MemoryFileIO();
      expect(() => runUnlink(io: io, cwdOverride: _cwd), returnsNormally);
    });
  });
}
