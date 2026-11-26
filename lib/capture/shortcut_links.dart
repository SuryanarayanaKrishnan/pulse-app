import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/env/env.dart';
import 'capture_source.dart';

/// iOS only imports signed shortcuts from an iCloud share link, and we cannot
/// sign without a Mac or iPhone. So each prebuilt shortcut is built once on a
/// device, shared with "Copy iCloud Link", and its link is put in [Env]. See
/// docs/SHORTCUT_LINKS.md.
///
/// URL schemes Shortcuts really supports (Apple "Shortcuts URL scheme"):
/// `shortcuts://` (open), `shortcuts://create-shortcut`,
/// `shortcuts://run-shortcut?name=`, `shortcuts://open-shortcut?name=`. There
/// is no scheme for the Automation tab, Back Tap or creating an automation.
class ShortcutDeepLinks {
  const ShortcutDeepLinks._();

  static final open = Uri.parse('shortcuts://');
  static final create = Uri.parse('shortcuts://create-shortcut');

  static Uri run(String name) =>
      Uri.parse('shortcuts://run-shortcut')
          .replace(queryParameters: {'name': name});
}

/// Names of the prebuilt shortcuts. They must match docs/SHORTCUT_LINKS.md,
/// because the Back Tap picker and "Run Shortcut" list them by name.
extension CaptureSourceShortcut on CaptureSource {
  String get shortcutName => switch (this) {
    CaptureSource.wallet => 'Pulse Wallet Payment',
    CaptureSource.bankSms => 'Pulse Bank SMS',
    CaptureSource.screenshot => 'Capture to Pulse',
    CaptureSource.nudge => 'Pulse Ask then Capture',
  };
}

/// Accepts only a real iCloud share link; anything else (empty, a leftover
/// placeholder, another host) counts as "not set yet".
Uri? parseShortcutLink(String raw) {
  final u = Uri.tryParse(raw.trim());
  if (u == null || u.scheme != 'https') return null;
  final host = u.host.toLowerCase();
  if (host != 'www.icloud.com' && host != 'icloud.com') return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length < 2 || segs.first != 'shortcuts') return null;
  if (segs[1].startsWith('REPLACE')) return null;
  return u;
}

class ShortcutLinks {
  const ShortcutLinks(this._raw);

  /// Reads the links from [Env] (dart-defines).
  const ShortcutLinks.fromEnv()
    : _raw = const {
        CaptureSource.wallet: Env.shortcutLinkWallet,
        CaptureSource.bankSms: Env.shortcutLinkBankSms,
        CaptureSource.screenshot: Env.shortcutLinkCapture,
        CaptureSource.nudge: Env.shortcutLinkAskCapture,
      };

  final Map<CaptureSource, String> _raw;

  Uri? linkFor(CaptureSource s) => parseShortcutLink(_raw[s] ?? '');
  bool has(CaptureSource s) => linkFor(s) != null;
}

final shortcutLinksProvider = Provider<ShortcutLinks>(
  (ref) => const ShortcutLinks.fromEnv(),
);

/// Opens a URL outside the app. Overridden in tests.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
