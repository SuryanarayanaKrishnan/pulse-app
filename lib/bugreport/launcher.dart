import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/analytics/analytics.dart';
import '../core/router/router.dart';
import '../core/widgets/pulse_sheet.dart';
import 'bug_log.dart';
import 'bug_report_sheet.dart';
import 'report.dart';
import 'transport.dart';

/// The RepaintBoundary at the app root that screenshots come from.
final captureKeyProvider = Provider<GlobalKey>((ref) => GlobalKey(debugLabel: 'bug-report-capture'));

final bugReportLauncherProvider = Provider<BugReportLauncher>((ref) => BugReportLauncher(ref));

/// Takes the screenshot first, then shows the sheet, so the picture is of
/// the screen the person was on and not of the sheet.
class BugReportLauncher {
  BugReportLauncher(this._ref);
  final Ref _ref;
  bool _open = false;

  bool get isOpen => _open;

  Future<ui.Image?> capture() async {
    try {
      final boundary = _ref.read(captureKeyProvider).currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return null;
      final dpr = ui.PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 2;
      return await boundary
          .toImage(pixelRatio: math.min(dpr, 2.0))
          .timeout(const Duration(seconds: 3));
    } on Object {
      return null;
    }
  }

  /// [source] is `shake` or `settings` (analytics only).
  Future<void> launch(String source) async {
    if (_open) return;
    _open = true;
    ui.Image? shot;
    try {
      shot = await capture();
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      _ref.read(analyticsProvider).track(AnalyticsEvent.bugReportOpened(source));
      final log = _ref.read(bugLogProvider);
      final device = await DeviceSnapshot.collect(
        locale: Localizations.maybeLocaleOf(ctx) ?? const Locale('en'),
        brightness: Theme.of(ctx).brightness,
        route: log.currentRoute,
      );
      if (!ctx.mounted) return;
      await showPulseSheet<void>(
        ctx,
        full: true,
        builder: (_) => BugReportSheet(
          screenshot: shot,
          device: device,
          logLines: log.lines(BugReport.maxLogLines),
          local: _ref.read(localShareTransportProvider),
          issue: _ref.read(issueTransportProvider),
          onSent: (m) => _ref.read(analyticsProvider).track(
            AnalyticsEvent.bugReportSent(m == DeliveryMethod.issue ? 'issue' : 'local'),
          ),
        ),
      );
    } finally {
      _open = false;
      shot?.dispose();
    }
  }
}
