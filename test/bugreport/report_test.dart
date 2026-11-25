import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/bugreport/report.dart';
import 'package:pulse/bugreport/transport.dart';
import 'package:share_plus/share_plus.dart';

const _device = DeviceSnapshot(
  appVersion: '1.0.0',
  build: '7',
  platform: 'android',
  osVersion: 'Android 14',
  locale: 'en-AE',
  theme: 'dark',
  route: '/home',
);

BugReport _report({List<int>? png, String note = 'Chart looks wrong', List<String>? log}) => BugReport(
  category: BugCategory.bug,
  note: note,
  device: _device,
  logLines: log ?? ['10:00:01 route /home', '10:00:02 event first_capture'],
  createdAt: DateTime.utc(2026, 5, 1, 10),
  screenshotPng: png == null ? null : Uint8List.fromList(png),
);

void main() {
  test('markdown has category, note, device facts and the log', () {
    final md = _report(png: [1, 2, 3]).toMarkdown();
    expect(md, contains('# [Bug] Chart looks wrong'));
    expect(md, contains('- app_version: 1.0.0'));
    expect(md, contains('- build: 7'));
    expect(md, contains('- platform: android'));
    expect(md, contains('- locale: en-AE'));
    expect(md, contains('- theme: dark'));
    expect(md, contains('- screen: /home'));
    expect(md, contains('See `screenshot.png`'));
    expect(md, contains('route /home'));
  });

  test('log is redacted again and capped at 200 lines', () {
    final lines = [for (var i = 0; i < 260; i++) 'x event_$i'];
    lines.add('boom sara@example.ae paid AED 99.00');
    final md = _report(log: lines).toMarkdown();
    expect(md, contains('last 200 lines'));
    expect(md, isNot(contains('sara@')));
    expect(md, isNot(contains('99.00')));
    expect(md, isNot(contains('event_0')));
  });

  test('no screenshot means no screenshot section; empty note is handled', () {
    final r = _report(note: '');
    expect(r.toMarkdown(), isNot(contains('screenshot.png')));
    expect(r.toMarkdown(), contains('_No note._'));
    expect(r.title, '[Bug] Report from the beta');
  });

  test('local transport writes report.md and screenshot.png then shares both', () async {
    final tmp = await Directory.systemTemp.createTemp('bugrep');
    addTearDown(() => tmp.delete(recursive: true));
    ShareParams? shared;
    final t = LocalShareTransport(tempDir: () async => tmp, share: (p) async => shared = p);
    final out = await t.send(_report(png: [137, 80, 78, 71]));
    expect(out.ok, isTrue);
    final dirs = tmp.listSync().whereType<Directory>().toList();
    expect(dirs.length, 1);
    expect(File('${dirs.single.path}/report.md').readAsStringSync(), contains('Chart looks wrong'));
    expect(File('${dirs.single.path}/screenshot.png').readAsBytesSync(), [137, 80, 78, 71]);
    expect(shared!.files!.map((f) => f.name), containsAll(['report.md', 'screenshot.png']));
  });

  test('local transport without a screenshot shares only the markdown', () async {
    final tmp = await Directory.systemTemp.createTemp('bugrep');
    addTearDown(() => tmp.delete(recursive: true));
    ShareParams? shared;
    final t = LocalShareTransport(tempDir: () async => tmp, share: (p) async => shared = p);
    await t.send(_report());
    expect(shared!.files!.length, 1);
  });

  test('issue transport is off without a URL', () async {
    final t = GithubIssueTransport(url: '');
    expect(t.available, isFalse);
    expect((await t.send(_report())).ok, isFalse);
  });

  test('issue transport posts JSON with the screenshot, and size-limits it', () async {
    final dio = Dio();
    RequestOptions? seen;
    dio.httpClientAdapter = _Fake((o) {
      seen = o;
      return ResponseBody.fromString(jsonEncode({'issue_url': 'https://github.com/o/r/issues/1'}), 201, headers: {Headers.contentTypeHeader: ['application/json']});
    });
    final t = GithubIssueTransport(url: 'https://reports.example/api', dio: dio);
    final out = await t.send(_report(png: [1, 2, 3]));
    expect(out.ok, isTrue);
    expect(out.method, DeliveryMethod.issue);
    expect(out.issueUrl, 'https://github.com/o/r/issues/1');
    final body = seen!.data as Map;
    expect(body['title'], '[Bug] Chart looks wrong');
    expect(body['screenshot_png_base64'], base64Encode([1, 2, 3]));
    expect(seen!.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
    final big = t.payload(_report(png: List.filled(GithubIssueTransport.maxScreenshotBytes + 1, 0)));
    expect(big.containsKey('screenshot_png_base64'), isFalse);
  });

  test('issue transport reports failure so the sheet can fall back', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Fake((_) => ResponseBody.fromString('{}', 429));
    final out = await GithubIssueTransport(url: 'https://reports.example/api', dio: dio).send(_report());
    expect(out.ok, isFalse);
    expect(out.error, 'http_429');
  });
}

class _Fake implements HttpClientAdapter {
  _Fake(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async => respond(o);
  @override
  void close({bool force = false}) {}
}
