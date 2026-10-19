import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks that every custom paper asset path in lib/custom_paper.dart points
/// to a bundled file. Flutter serves a package's assets under
/// `packages/<package name>/`, and the native code loads these paths as is,
/// so a stale package name only fails when printing.
/// Run from the package root, as `flutter test` does.

String _packageName() => RegExp(r'^name:\s*(\S+)', multiLine: true)
    .firstMatch(File('pubspec.yaml').readAsStringSync())!
    .group(1)!;

void main() {
  final String prefix = 'packages/${_packageName()}/';
  final String pubspec = File('pubspec.yaml').readAsStringSync();
  final List<String> paperClasses = File('lib/custom_paper.dart')
      .readAsStringSync()
      // Ignore commented-out papers.
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
      .split(RegExp(r'^class ', multiLine: true))
      .where((block) => block.startsWith('BinPaper_'))
      .toList();

  test('finds the custom paper classes', () {
    expect(paperClasses.length, greaterThan(15));
  });

  test('every custom paper asset exists under the package asset path', () {
    for (final String block in paperClasses) {
      final String className = block.substring(0, block.indexOf(' '));
      final String rootDir =
          RegExp(r'_rootDir = "([^"]+)"').firstMatch(block)!.group(1)!;
      expect(rootDir, startsWith(prefix), reason: '$className asset path');

      final String assetDir = rootDir.substring(prefix.length);
      expect(pubspec, contains('- $assetDir/'),
          reason: '$assetDir is not declared under assets in pubspec.yaml');

      final Iterable<String> files = RegExp(r'"\$_rootDir/([^"]+)"')
          .allMatches(block)
          .map((m) => m.group(1)!);
      expect(files, isNotEmpty, reason: '$className has no papers');
      for (final String file in files) {
        expect(File('$assetDir/$file').existsSync(), isTrue,
            reason: '$className: $assetDir/$file is missing');
      }
    }
  });
}
