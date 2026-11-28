import '../../capture/capture_source.dart';
import '../../capture/shortcut_links.dart';
import '../../core/env/env.dart';

/// What the guided screen says for one capture path. All four are required
/// parts of setup, so nothing here is labelled optional.
///
/// Wording of iOS UI is exact: Wallet trigger "When I tap any of my Wallet
/// passes or payment cards", and the "Run After Confirmation" row, which the
/// user changes to "Run Immediately". iOS does not let an app create these
/// automations or flip that switch, see docs/SHORTCUT_LINKS.md.
class CapturePath {
  const CapturePath({
    required this.source,
    required this.title,
    required this.why,
    required this.stepsWithLink,
    required this.stepsWithoutLink,
    required this.testHint,
    required this.failHint,
    this.canRunNow = false,
  });

  final CaptureSource source;
  final String title;
  final String why;

  /// Steps after "Add Shortcut" has installed the prebuilt shortcut.
  final List<String> stepsWithLink;

  /// Shortest hand-built route while the iCloud link is not set yet.
  final List<String> stepsWithoutLink;
  final String testHint;
  final String failHint;

  /// Offers a "Run it now" button that runs the shortcut by name.
  final bool canRunNow;

  String get shortcutName => source.shortcutName;

  static const _runImmediately =
      'Tap "Run After Confirmation", choose "Run Immediately", and turn off '
      '"Notify When Run". Tap Done.';

  static final all = <CapturePath>[
    CapturePath(
      source: CaptureSource.wallet,
      title: 'Apple Pay and Wallet cards',
      why:
          'Every tap-to-pay, including Tabby, lands in ${Env.appName} on its own.',
      stepsWithLink: const [
        'In Shortcuts tap Automation, then +, then Wallet ("When I tap any of '
            'my Wallet passes or payment cards"). Choose your cards and tap Next.',
        'Add the action Run Shortcut, choose "Pulse Wallet Payment" and set '
            'its Input to Shortcut Input. Tap Next.',
        _runImmediately,
      ],
      stepsWithoutLink: const [
        'In Shortcuts tap Automation, then +, then Wallet ("When I tap any of '
            'my Wallet passes or payment cards"). Choose your cards and tap Next.',
        'Add the action Record Payment (from ${Env.appName}). Tap Amount, '
            'Merchant and Card and pick the matching Wallet transaction items. '
            'Tap Next.',
        _runImmediately,
      ],
      testHint: 'Tap Test it, then pay with any card in the list.',
      failHint:
          'No payment arrived. Check the automation says "Run Immediately", '
          'that the card you paid with is ticked, then test again.',
    ),
    CapturePath(
      source: CaptureSource.bankSms,
      title: 'Bank SMS',
      why: 'Bank alerts are read on this phone. One-time codes are dropped.',
      stepsWithLink: const [
        'In Shortcuts tap Automation, then +, then Message. Under Sender add '
            'your banks, or put AED in Message Contains. Tap Next.',
        'Add the action Run Shortcut, choose "Pulse Bank SMS" and set its '
            'Input to Shortcut Input. Tap Next.',
        _runImmediately,
      ],
      stepsWithoutLink: const [
        'In Shortcuts tap Automation, then +, then Message. Under Sender add '
            'your banks, or put AED in Message Contains. Tap Next.',
        'Add the action Record Bank SMS (from ${Env.appName}). It takes the '
            'message by itself; leave Sender empty. Tap Next.',
        _runImmediately,
      ],
      testHint:
          'Tap Test it, then wait for your next bank alert, or have someone '
          'text you "AED 1.00 spent at TEST".',
      failHint:
          'No text arrived. Check the Sender or Message Contains filter '
          'matches your bank and the automation says "Run Immediately".',
    ),
    CapturePath(
      source: CaptureSource.screenshot,
      title: 'Screenshot and Back Tap',
      why:
          'For Tabby and other apps that send no text: when the alert or '
          'order is on screen, double-tap the back of the phone (or press the '
          'Action button). The screenshot is taken for you, read on the '
          'phone and thrown away.',
      stepsWithLink: const [
        'Open Settings, Accessibility, Touch, Back Tap, Double Tap, and pick '
            '"Capture to Pulse". iOS only lets you set this yourself. '
            'iPhone 15 Pro or newer: you can use Settings, Action Button, '
            'Shortcut instead.',
      ],
      stepsWithoutLink: const [
        'In Shortcuts tap +, add Take Screenshot, then Capture to Pulse (from '
            '${Env.appName}), and name the shortcut "Capture to Pulse".',
        'Open Settings, Accessibility, Touch, Back Tap, Double Tap, and pick '
            '"Capture to Pulse". iOS only lets you set this yourself.',
      ],
      testHint:
          'Tap Test it, show any receipt or alert with an amount, then '
          'double-tap the back of the phone (or tap Run it now).',
      failHint:
          'Nothing arrived. The screen needs a visible amount such as '
          '"AED 45.00". Check Back Tap points at "Capture to Pulse".',
      canRunNow: true,
    ),
    CapturePath(
      source: CaptureSource.nudge,
      title: 'Ask after shopping apps',
      why:
          'When you close Noon, Talabat, Tabby or Careem, one tap on OK logs '
          'the order you just screenshotted.',
      stepsWithLink: const [
        'In Shortcuts tap Automation, then +, then App. Choose Noon, Talabat, '
            'Tabby and Careem, tick Is Closed, and tap Next.',
        'Add the action Run Shortcut and choose "Pulse Ask then Capture". '
            'Tap Next.',
        _runImmediately,
      ],
      stepsWithoutLink: const [
        'In Shortcuts tap Automation, then +, then App. Choose Noon, Talabat, '
            'Tabby and Careem, tick Is Closed, and tap Next.',
        'Add Get Latest Screenshots (set to 1), then Ask then Capture (from '
            '${Env.appName}). Tap Next.',
        _runImmediately,
      ],
      testHint:
          'Tap Test it, screenshot an order screen, close that shopping app, '
          'then tap OK on the question.',
      failHint:
          'Nothing arrived. Check the app you closed is ticked, you took a '
          'screenshot of the order first, and the automation says '
          '"Run Immediately".',
    ),
  ];

  static CapturePath of(CaptureSource s) =>
      all.firstWhere((p) => p.source == s);
}
