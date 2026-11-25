import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

bool _looksLikePdf(Uint8List b) =>
    b.length > 4 &&
    b[0] == 0x25 &&
    b[1] == 0x50 &&
    b[2] == 0x44 &&
    b[3] == 0x46;

/// Opens one vault paper (a photo or a PDF), decrypting it in memory only.
Future<void> showVaultFile(BuildContext context, String path) =>
    showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => VaultFileViewer(path: path),
    );

class VaultFileViewer extends ConsumerStatefulWidget {
  const VaultFileViewer({super.key, required this.path});
  final String path;

  @override
  ConsumerState<VaultFileViewer> createState() => _VaultFileViewerState();
}

class _VaultFileViewerState extends ConsumerState<VaultFileViewer> {
  late final Future<Uint8List?> _bytes = ref
      .read(vaultServiceProvider)
      .readFile(widget.path);

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Paper',
    subtitle: 'Decrypted on this phone for viewing only.',
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final b = snap.data;
          if (b == null || b.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Text(
                  'This file is not on this phone any more. Add it again from the original.',
                  style: context.tt.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_looksLikePdf(b)) {
            return PdfViewer.data(b, sourceName: widget.path);
          }
          return InteractiveViewer(
            child: Image.memory(
              b,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  'This file cannot be shown here.',
                  style: context.tt.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
