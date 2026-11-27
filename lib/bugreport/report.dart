import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'redactor.dart';

enum BugCategory {
  bug('Bug'),
  confusing('Confusing'),
  idea('Idea');

  const BugCategory(this.label);
  final String label;
}

/// Facts about the app and phone. Nothing about the person.
@immutable
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.appVersion,
    required this.build,
    required this.platform,
    required this.osVersion,
    this.model = 'unknown',
    required this.locale,
    required this.theme,
    required this.route,
  });

  final String appVersion;
  final String build;
  final String platform;
  final String osVersion;

  /// Hardware identifier (iOS: `iPhone16,2`; Android: maker and model).
  final String model;
  final String locale;
  final String theme;
  final String route;

  static Future<DeviceSnapshot> collect({
    required Locale locale,
    required Brightness brightness,
    String? route,
  }) async {
    var version = 'unknown';
    var build = 'unknown';
    try {
      final p = await PackageInfo.fromPlatform();
      version = p.version;
      build = p.buildNumber;
    } on Object {
      // No plugin (tests, desktop): leave unknown.
    }
    var os = 'unknown';
    var osVersion = 'unknown';
    try {
      os = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
    } on Object {
      os = defaultTargetPlatform.name;
    }
    var model = 'unknown';
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isIOS) {
        model = (await info.iosInfo).utsname.machine;
      } else if (Platform.isAndroid) {
        final a = await info.androidInfo;
        model = '${a.manufacturer} ${a.model}';
      }
    } on Object {
      // No plugin (tests, desktop): leave unknown.
    }
    return DeviceSnapshot(
      appVersion: version,
      build: build,
      platform: os,
      osVersion: osVersion,
      model: model,
      locale: locale.toLanguageTag(),
      theme: brightness == Brightness.dark ? 'dark' : 'light',
      route: route ?? 'unknown',
    );
  }

  Map<String, String> toJson() => {
    'app_version': appVersion,
    'build': build,
    'platform': platform,
    'os_version': osVersion,
    'model': model,
    'locale': locale,
    'theme': theme,
    'screen': route,
  };
}

/// What the person is about to send.
@immutable
class BugReport {
  const BugReport({
    required this.category,
    required this.note,
    required this.device,
    required this.logLines,
    required this.createdAt,
    this.screenshotPng,
  });

  final BugCategory category;
  final String note;
  final DeviceSnapshot device;

  /// Already redacted lines, oldest first.
  final List<String> logLines;
  final DateTime createdAt;
  final Uint8List? screenshotPng;

  static const screenshotFile = 'screenshot.png';
  static const maxLogLines = 200;

  String get title {
    final first = note.trim().split('\n').first.trim();
    final short = first.length > 70 ? '${first.substring(0, 70)}...' : first;
    return '[${category.label}] ${short.isEmpty ? 'Report from the beta' : short}';
  }

  /// The report as Markdown. The log is redacted again here as a second
  /// line of defence.
  String toMarkdown({bool screenshotFileLink = true}) {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('**Category:** ${category.label}')
      ..writeln('**Sent:** ${createdAt.toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('## What happened')
      ..writeln(note.trim().isEmpty ? '_No note._' : note.trim())
      ..writeln()
      ..writeln('## App and device');
    for (final e in device.toJson().entries) {
      b.writeln('- ${e.key}: ${e.value}');
    }
    if (screenshotPng != null && screenshotFileLink) {
      b
        ..writeln()
        ..writeln('## Screenshot')
        ..writeln('See `$screenshotFile`.');
    }
    final lines = logLines.length > maxLogLines
        ? logLines.sublist(logLines.length - maxLogLines)
        : logLines;
    b
      ..writeln()
      ..writeln('## Activity log (last ${lines.length} lines)')
      ..writeln('Route changes, event names and errors only. Numbers, amounts, names and contacts are removed.')
      ..writeln()
      ..writeln('```');
    for (final l in lines) {
      b.writeln(Redactor.redact(l).replaceAll('```', "'''"));
    }
    b.writeln('```');
    return b.toString();
  }
}
