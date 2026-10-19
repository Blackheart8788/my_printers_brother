import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks that the method names Dart sends over the 'another_brother' channel
/// are handled by the native plugins, by reading the plugin sources.
/// Run from the package root, as `flutter test` does.

const String _androidSrc = 'android/src/main/kotlin/com/rouninlabs/another_brother';
const String _iosSrc = 'ios/Classes';

/// Printer methods that are only implemented on Android. Each one must be
/// documented with [_androidOnlyNote] in lib/printer_info.dart.
const Set<String> _androidOnly = {
  'flushPTTPrint',
  'getBatteryInfo',
  'getBatteryWeak',
  'getBluetoothPreference',
  'getBootMode',
  'getFirmFileVer',
  'getFirmVersion',
  'getLabelInfo',
  'getLabelParam',
  'getMediaFileVer',
  'getMediaVersion',
  'getNetPrinterInfo',
  'getPrinterSettings',
  'getSerialNumber',
  'getSystemReport',
  'getTemplateList',
  'removeTemplate',
  'replaceText',
  'replaceTextIndex',
  'replaceTextName',
  'sendBinary',
  'sendBinaryFile',
  'sendDatabase',
  'startPTTPrint',
  'transfer',
  'updateBluetoothPreference',
  'updateFirm',
  'updatePrinterSettings',
};

/// Methods that iOS handles in Dart, so they never reach the iOS plugin.
const Set<String> _handledInDartOnIos = {'getBLEPrinters'};

const String _androidOnlyNote = '/// Available on Android only.';

String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//.*$', multiLine: true), '');

Iterable<File> _sourceFiles(String dir, String extension) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith(extension));

Set<String> _matches(RegExp pattern, String source) =>
    pattern.allMatches(source).map((m) => m.group(1)!).toSet();

/// Method names Dart invokes on the channel.
Set<String> _dartMethods() => {
      for (final file in _sourceFiles('lib', '.dart'))
        ..._matches(RegExp(r'''invokeMethod(?:<[^>]*>)?\(\s*["']([^"']+)["']'''),
            _stripComments(file.readAsStringSync())),
    };

/// Method names a plugin dispatches: inline string literals plus the
/// METHOD_NAME of each method call class it routes to.
Set<String> _nativeMethods({
  required String pluginPath,
  required String sourceDir,
  required String extension,
  required RegExp literalPattern,
  required RegExp classPattern,
  required RegExp methodNamePattern,
}) {
  final String plugin = _stripComments(File(pluginPath).readAsStringSync());
  final Map<String, File> classFiles = {
    for (final file in _sourceFiles(sourceDir, extension))
      file.uri.pathSegments.last.replaceAll(extension, ''): file,
  };

  final Set<String> methods = _matches(literalPattern, plugin);
  for (final String className in _matches(classPattern, plugin)) {
    final File? file = classFiles[className];
    expect(file, isNotNull, reason: 'No source file for $className');
    final Set<String> names =
        _matches(methodNamePattern, file!.readAsStringSync());
    expect(names, hasLength(1), reason: 'Expected one METHOD_NAME in $className');
    methods.addAll(names);
  }
  return methods;
}

Set<String> _androidMethods() => _nativeMethods(
      pluginPath: '$_androidSrc/AnotherBrotherPlugin.kt',
      sourceDir: _androidSrc,
      extension: '.kt',
      literalPattern: RegExp(r'call\.method == "([^"]+)"'),
      classPattern: RegExp(r'call\.method == (\w+)\.METHOD_NAME'),
      methodNamePattern: RegExp(r'METHOD_NAME\s*=\s*"([^"]+)"'),
    );

Set<String> _iosMethods() => _nativeMethods(
      pluginPath: '$_iosSrc/AnotherBrotherPlugin.m',
      sourceDir: _iosSrc,
      extension: '.m',
      literalPattern: RegExp(r'\[@"([^"]+)" isEqualToString:call\.method\]'),
      classPattern: RegExp(r'\[\[(\w+) METHOD_NAME\] isEqualToString:call\.method'),
      methodNamePattern: RegExp(r'METHOD_NAME\s*=\s*@"([^"]+)"'),
    );

void main() {
  test('finds the methods on each side', () {
    // Guards against the parsing silently matching nothing.
    expect(_dartMethods().length, greaterThan(40));
    expect(_androidMethods().length, greaterThan(40));
    expect(_iosMethods().length, greaterThan(20));
  });

  test('every method Dart calls is handled on Android', () {
    expect(_dartMethods().difference(_androidMethods()), isEmpty);
  });

  test('the methods missing on iOS are exactly the documented Android-only ones',
      () {
    final Set<String> missingOnIos = _dartMethods()
        .difference(_iosMethods())
        .difference(_handledInDartOnIos);

    expect(missingOnIos, _androidOnly);
  });

  test('every Android-only method is documented as such', () {
    final List<String> lines =
        File('lib/printer_info.dart').readAsLinesSync();

    for (final String method in _androidOnly) {
      final int signature = lines.indexWhere((line) =>
          RegExp('^  Future<\\S+> $method\\(').hasMatch(line));
      expect(signature, isNot(-1), reason: 'No Printer.$method in printer_info.dart');

      final List<String> comments = lines
          .sublist(0, signature)
          .reversed
          .takeWhile((line) => line.trimLeft().startsWith('//'))
          .map((line) => line.trim())
          .toList();
      expect(comments, contains(_androidOnlyNote),
          reason: 'Printer.$method is missing "$_androidOnlyNote"');
    }
  });
}
