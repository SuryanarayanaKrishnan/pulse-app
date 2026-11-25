import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/household/household_invite.dart';
import '../../core/theme/tokens.dart';

/// Whether this build can open the camera scanner. Desktop and web builds
/// keep the paste field only.
bool get inviteScannerAvailable =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Opens the camera and returns the text of the first household invite QR it
/// sees, or null when the user backs out. Anything that is not an intact
/// invite is ignored (the code's checksum is checked here as well as when
/// joining). Nothing is stored or sent; the camera is released on close.
Future<String?> scanInviteCode(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InviteScannerPage(),
      ),
    );

/// The code carried by a scanned barcode value, or null if it is not an
/// intact household invite. Pure, so it is tested without a camera.
String? inviteFromScan(String? raw) {
  if (raw == null) return null;
  try {
    HouseholdInvite.decode(raw);
    return raw.trim();
  } on FormatException {
    return null;
  }
}

class InviteScannerPage extends StatefulWidget {
  const InviteScannerPage({super.key});
  @override
  State<InviteScannerPage> createState() => _InviteScannerPageState();
}

class _InviteScannerPageState extends State<InviteScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _wrong = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    var sawOther = false;
    for (final b in capture.barcodes) {
      final code = inviteFromScan(b.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
      sawOther = true;
    }
    if (sawOther && !_wrong) setState(() => _wrong = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan invite'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            key: const Key('invite_scanner'),
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScanProblem(error),
          ),
          Positioned(
            left: Space.gutter,
            right: Space.gutter,
            bottom: Space.xxl,
            child: Text(
              _wrong
                  ? "That QR code isn't a Pulse household invite. Try the one on your partner's phone, or go back and paste the code."
                  : 'Point the camera at the QR code on the inviting phone. Nothing is recorded or uploaded.',
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium!.copyWith(
                color: _wrong ? c.warning : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the preview when the camera cannot start. The paste
/// field on the previous screen always works.
class _ScanProblem extends StatelessWidget {
  const _ScanProblem(this.error);
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: Space.md),
            Text(
              denied
                  ? 'Pulse needs the camera to scan the code. You can allow it in your phone settings, or go back and paste the code instead.'
                  : "The camera couldn't start. Go back and paste the code instead.",
              key: const Key('scanner_problem'),
              textAlign: TextAlign.center,
              style: context.tt.bodyMedium!.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
