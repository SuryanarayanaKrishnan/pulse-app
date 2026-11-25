import 'dart:math';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/vault_models.dart';
import 'package:pulse/features/vault/open_file_sheet.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  testWidgets(
    'a nominee opens a file with two codes and sees entries and papers',
    (tester) async {
      final kit = await VaultSeal.createKit(
        ownerName: 'Leila',
        nominee: Nominee(id: 'n1', name: 'Karim', createdAt: t0),
        entries: [
          VaultEntry(
            id: 'e1',
            type: VaultType.bank,
            institution: 'Mashreq',
            whereToFind: 'Grey folder',
            photoPaths: const ['p'],
            createdAt: t0,
            updatedAt: t0,
          ),
        ],
        now: t0,
        random: Random(1),
        readPaper: (_) async => Uint8List.fromList([1, 2, 3]),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: PulseTheme.light,
            home: const Scaffold(body: OpenFileSheet()),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('open_file_text')),
        kit.sealedFile,
      );
      await tester.enterText(
        find.byKey(const Key('open_code_a')),
        kit.nomineeShare,
      );
      await tester.enterText(
        find.byKey(const Key('open_code_b')),
        'not a code',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_go')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open_error')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('open_code_b')),
        kit.escrowShare,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_go')));
      await tester.pumpAndSettle();
      expect(find.text('Left for you by Leila'), findsOneWidget);
      expect(find.textContaining('Grey folder'), findsOneWidget);
      expect(find.byKey(const ValueKey('opened_paper_e1_0')), findsOneWidget);
    },
  );
}
