import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/kv_store.dart';
import '../../core/analytics/analytics.dart';
import '../../core/engine/split_settle.dart';
import '../../core/engine/types.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../data/splits_util.dart';

final autoSettleKvProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

/// Matches captured payments to open splits and applies or asks, on device.
class AutoSettleService {
  AutoSettleService({
    required this.repo,
    required this.analytics,
    required this.kv,
    required this.messenger,
    this.onChanged,
  });

  final PulseRepository repo;
  final Analytics analytics;
  final KvStore kv;
  final ScaffoldMessengerState? Function() messenger;

  /// Called after the ledger changed so lists can refresh.
  final void Function()? onChanged;

  static const answersKey = 'splits.autosettle.answers';

  Future<Map<String, RememberedAnswer>> _answers() async {
    try {
      final raw = await kv.read(answersKey);
      if (raw == null) return {};
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: e.value == 'yes' ? RememberedAnswer.yes : RememberedAnswer.no,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _remember(String key, RememberedAnswer a) async {
    try {
      final all = await _answers();
      all[key] = a;
      await kv.write(
        answersKey,
        jsonEncode({for (final e in all.entries) e.key: e.value.name}),
      );
    } catch (_) {}
  }

  static List<SplitContact> contactsOf(List<SplitGroup> groups) => [
    for (final g in groups)
      for (final m in g.members.where((m) => m.id != 'me'))
        SplitContact(
          groupId: g.id,
          memberId: m.id,
          name: m.name,
          phone: m.phone,
          ibanTail: m.ibanTail,
          balanceMinor: ((groupBalances(g)[m.id] ?? 0) * -100).round(),
        ),
  ];

  /// Handle one payment. Safe to call for every capture; most do nothing.
  Future<void> handle(Counterparty c, int amountMinor) async {
    final List<SplitGroup> groups;
    try {
      groups = await repo.splitGroups();
    } catch (_) {
      return;
    }
    final decision = decideSettlement(
      counterparty: c,
      amountMinor: amountMinor,
      contacts: contactsOf(groups),
      remembered: await _answers(),
    );
    switch (decision) {
      case NoSettle():
        return;
      case AutoSettle(:final proposal):
        await _apply(proposal, auto: true);
      case AskSettle(:final proposal, :final key):
        _ask(proposal, key);
    }
  }

  Future<void> _apply(SettleProposal p, {required bool auto}) async {
    final me = 'me', them = p.contact.memberId;
    final amount = p.amountMinor / 100;
    final SettlementRecord rec;
    try {
      final paid = await repo.markSettlementPaid(
        p.contact.groupId,
        from: p.fromMe ? me : them,
        to: p.fromMe ? them : me,
        amount: amount,
      );
      // The bank line is the evidence, so there is nothing left to confirm.
      rec = await repo.confirmSettlement(p.contact.groupId, paid.id);
    } catch (_) {
      return;
    }
    analytics.track(
      AnalyticsEvent.splitAutoSettled(
        match: p.strength.name,
        partial: p.isPartial,
        direction: p.fromMe ? 'debit' : 'credit',
      ),
    );
    analytics.track(AnalyticsEvent.firstSplitSettled);
    onChanged?.call();
    final name = p.contact.name;
    final text = p.fromMe
        ? 'Marked your payment to $name as settled'
        : '$name paid you back';
    final left = p.isPartial
        ? ' · ${(p.remainingMinor / 100).toStringAsFixed(2)} still open'
        : '';
    messenger()?.showSnackBar(
      SnackBar(
        content: Text('$text$left'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repo.undoSettlement(p.contact.groupId, rec.id);
            } catch (_) {
              return;
            }
            analytics.track(AnalyticsEvent.splitSettleUndone);
            onChanged?.call();
          },
        ),
      ),
    );
  }

  void _ask(SettleProposal p, String key) {
    final m = messenger();
    if (m == null) return;
    analytics.track(AnalyticsEvent.splitSettleAsked(match: p.strength.name));
    final name = p.contact.name;
    final amt = (p.amountMinor / 100).toStringAsFixed(2);
    m.clearMaterialBanners();
    m.showMaterialBanner(
      MaterialBanner(
        content: Text(
          p.fromMe
              ? 'Was this $amt to $name for your split? We will remember your answer.'
              : 'Did $name pay you $amt for your split? We will remember your answer.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              m.hideCurrentMaterialBanner();
              unawaited(_remember(key, RememberedAnswer.no));
            },
            child: const Text('Not this'),
          ),
          TextButton(
            onPressed: () async {
              m.hideCurrentMaterialBanner();
              await _remember(key, RememberedAnswer.yes);
              await _apply(p, auto: false);
            },
            child: const Text('Yes, settle'),
          ),
        ],
      ),
    );
  }
}

final Provider<AutoSettleService> autoSettleServiceProvider = Provider<AutoSettleService>((ref) {
  return AutoSettleService(
    repo: ref.watch(repositoryProvider),
    analytics: ref.watch(analyticsProvider),
    kv: ref.watch(autoSettleKvProvider),
    messenger: () => AutoSettleHost.messengerKey.currentState,
    onChanged: () => ref.invalidate(splitGroupsProvider),
  );
});

/// Sits above the app: turns new captures into settle attempts.
class AutoSettleHost extends ConsumerWidget {
  const AutoSettleHost({super.key, required this.child});
  final Widget child;

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(captureOutcomesProvider, (_, next) async {
      final out = next.value;
      final id = out?.transactionId;
      if (id == null || !out!.isNew) return;
      final repo = ref.read(repositoryProvider);
      final svc = ref.read(autoSettleServiceProvider);
      try {
        final tx = (await repo.transactions()).firstWhere((t) => t.id == id);
        await svc.handle(counterpartyOf(tx), (tx.amount * 100).round());
      } catch (_) {}
    });
    return child;
  }
}

/// The counterparty of a captured transaction.
Counterparty counterpartyOf(Transaction tx) {
  final ids = extractTransferIds(tx.description);
  return Counterparty(
    name: tx.merchant,
    direction: tx.isIncome ? Direction.credit : Direction.debit,
    phone: ids.phone,
    ibanTail: ids.ibanTail,
  );
}
