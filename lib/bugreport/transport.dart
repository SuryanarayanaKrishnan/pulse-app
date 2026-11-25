import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/env/env.dart';
import 'report.dart';

enum DeliveryMethod { local, issue }

class SendOutcome {
  const SendOutcome.ok(this.method, {this.issueUrl}) : ok = true, error = null;
  const SendOutcome.failed(this.method, this.error) : ok = false, issueUrl = null;
  final bool ok;
  final DeliveryMethod method;
  final String? issueUrl;
  final String? error;
}

/// Where a finished report goes.
abstract class BugReportTransport {
  DeliveryMethod get method;

  /// False when this way of sending is not set up in this build.
  bool get available;

  Future<SendOutcome> send(BugReport report);
}

/// Writes `report.md` (and `screenshot.png`) to a folder and opens the system
/// share sheet. Needs no setup and no network, so it is always there.
class LocalShareTransport implements BugReportTransport {
  LocalShareTransport({
    Future<Directory> Function()? tempDir,
    Future<void> Function(ShareParams)? share,
  }) : _tempDir = tempDir ?? getTemporaryDirectory,
       _share = share ?? ((p) async => SharePlus.instance.share(p));

  final Future<Directory> Function() _tempDir;
  final Future<void> Function(ShareParams) _share;

  @override
  DeliveryMethod get method => DeliveryMethod.local;
  @override
  bool get available => true;

  /// Writes the bundle folder and returns it.
  Future<Directory> writeBundle(BugReport r) async {
    final parent = await _tempDir();
    final stamp = r.createdAt.toUtc().millisecondsSinceEpoch;
    final dir = await Directory('${parent.path}/pulse-report-$stamp').create(recursive: true);
    await File('${dir.path}/report.md').writeAsString(r.toMarkdown());
    if (r.screenshotPng != null) {
      await File('${dir.path}/${BugReport.screenshotFile}').writeAsBytes(r.screenshotPng!);
    }
    return dir;
  }

  @override
  Future<SendOutcome> send(BugReport r) async {
    try {
      final dir = await writeBundle(r);
      final files = [
        XFile('${dir.path}/report.md', mimeType: 'text/markdown'),
        if (r.screenshotPng != null)
          XFile('${dir.path}/${BugReport.screenshotFile}', mimeType: 'image/png'),
      ];
      await _share(ShareParams(files: files, subject: r.title, text: r.title));
      return const SendOutcome.ok(DeliveryMethod.local);
    } on Object catch (e) {
      return SendOutcome.failed(DeliveryMethod.local, e.runtimeType.toString());
    }
  }
}

/// POSTs the report to a backend that files a GitHub issue (see
/// docs/BUG_REPORTS.md). The app holds only the endpoint URL; the GitHub
/// token stays on the server. Disabled while the URL is empty.
class GithubIssueTransport implements BugReportTransport {
  GithubIssueTransport({String? url, Dio? dio})
    : url = url ?? Env.bugReportUrl,
      _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), sendTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 20)));

  final String url;
  final Dio _dio;

  /// Larger screenshots are left out of the upload (they stay in local share).
  static const maxScreenshotBytes = 700 * 1024;

  @override
  DeliveryMethod get method => DeliveryMethod.issue;
  @override
  bool get available => Uri.tryParse(url)?.hasScheme ?? false;

  Map<String, Object?> payload(BugReport r) {
    final png = r.screenshotPng;
    final withShot = png != null && png.length <= maxScreenshotBytes;
    return {
      'title': r.title,
      'category': r.category.name,
      'body': r.toMarkdown(screenshotFileLink: false),
      'device': r.device.toJson(),
      if (withShot) 'screenshot_png_base64': base64Encode(png),
    };
  }

  @override
  Future<SendOutcome> send(BugReport r) async {
    if (!available) return const SendOutcome.failed(DeliveryMethod.issue, 'not_configured');
    try {
      final res = await _dio.post<Object?>(
        url,
        data: payload(r),
        options: Options(contentType: Headers.jsonContentType),
      );
      final data = res.data;
      final issue = data is Map ? data['issue_url'] : null;
      return SendOutcome.ok(DeliveryMethod.issue, issueUrl: issue is String ? issue : null);
    } on DioException catch (e) {
      return SendOutcome.failed(DeliveryMethod.issue, 'http_${e.response?.statusCode ?? 'network'}');
    } on Object catch (e) {
      return SendOutcome.failed(DeliveryMethod.issue, e.runtimeType.toString());
    }
  }
}

final localShareTransportProvider = Provider<LocalShareTransport>((ref) => LocalShareTransport());
final issueTransportProvider = Provider<GithubIssueTransport>((ref) => GithubIssueTransport());
