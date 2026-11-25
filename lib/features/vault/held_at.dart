import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/vault_models.dart';
import '../../data/providers.dart';
import '../../data/vault_service.dart' show VaultGuardException;

/// "Held at": where an investment, piece of gold or property lives (the
/// broker, the app, the locker, the agent). It is saved as a family vault
/// entry tied to the item by [sourceRef], so a nominee can find it. Never a
/// login: the vault's input guard refuses those.
Future<VaultEntry?> heldAtEntry(WidgetRef ref, String sourceRef) async {
  final all = await ref.read(vaultServiceProvider).entries();
  return all.where((e) => e.sourceRef == sourceRef).firstOrNull;
}

/// Creates or updates the entry. Returns an error message to show, or null.
/// Blank text leaves any existing entry alone.
Future<String?> saveHeldAt(
  WidgetRef ref, {
  required String sourceRef,
  required VaultType type,
  required String where,
  required String title,
  VaultEntry? existing,
}) async {
  final text = where.trim();
  if (text.isEmpty) return null;
  final vault = ref.read(vaultServiceProvider);
  try {
    final now = DateTime.now().toUtc();
    final current = existing ?? await heldAtEntry(ref, sourceRef);
    await vault.saveEntry(
      current != null
          ? current.copyWith(institution: text)
          : VaultEntry(
              id: vault.blank(type).id,
              type: type,
              institution: text,
              title: title,
              sourceRef: sourceRef,
              createdAt: now,
              updatedAt: now,
            ),
    );
    ref.invalidate(vaultEntriesProvider);
    return null;
  } on VaultGuardException catch (e) {
    return e.message;
  }
}

/// The field and its one-line explanation.
class HeldAtField extends StatelessWidget {
  const HeldAtField({super.key, required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
      ),
      Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Text(
          'Added to your family vault so a nominee knows where to look. No logins, ever.',
          style: context.tt.bodySmall,
        ),
      ),
    ],
  );
}
