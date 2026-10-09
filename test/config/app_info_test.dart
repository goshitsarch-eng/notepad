import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xp_notepad/config/app_info.dart';

/// The version number lives in several files, and a release that updates some of them and
/// not the rest ships the wrong number. These checks make that a failing test instead.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final pubspecVersion = RegExp(
    r'^version: *([0-9]+\.[0-9]+\.[0-9]+)(\+[0-9]+)?\s*$',
    multiLine: true,
  ).firstMatch(read('pubspec.yaml'));

  test('pubspec.yaml has a semantic version with a build number', () {
    expect(pubspecVersion, isNotNull);
    expect(
      pubspecVersion!.group(2),
      isNotNull,
      reason: 'the build number after + is missing',
    );
  });

  test('Help > About shows the version in pubspec.yaml', () {
    expect(appVersion, pubspecVersion!.group(1));
  });

  test('the Flatpak metadata lists this version as its newest release', () {
    final first = RegExp(
      r'<release version="([^"]+)"',
    ).firstMatch(read('packaging/flatpak/com.goshapps.Notepad.metainfo.xml'));
    expect(first!.group(1), appVersion);
  });

  test('the Windows installer script defaults to this version', () {
    final match = RegExp(r'#define AppVersion "([^"]+)"')
        .firstMatch(read('packaging/windows/xp-notepad.iss'));
    expect(match!.group(1), appVersion);
  });

  test('the README states this version', () {
    expect(read('README.md'), contains('Version $appVersion'));
  });
}
