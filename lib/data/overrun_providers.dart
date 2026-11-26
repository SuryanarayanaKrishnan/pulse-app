import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/kv_store.dart';
import 'budget_plan_service.dart';
import 'providers.dart';

/// Where "this was a one-off" is remembered (this phone only).
final overrunKvProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

/// The months the person called a one-off, by category id. Marking leaves the
/// budget alone; it only keeps that month out of the "is this a habit?" count.
class OverrunMarks extends Notifier<Map<String, Set<String>>> {
  static const storageKey = 'budget.overrun_oneoffs';

  @override
  Map<String, Set<String>> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(overrunKvProvider).read(storageKey);
      if (raw == null || raw.isEmpty) return;
      final j = jsonDecode(raw);
      if (j is! Map) return;
      final loaded = {
        for (final e in j.entries)
          if (e.value is List)
            '${e.key}': {for (final m in e.value as List) '$m'},
      };
      if (loaded.isNotEmpty) state = {...loaded, ...state};
    } on Object catch (e) {
      debugPrint('One-off marks unreadable, starting empty: $e');
    }
  }

  Future<void> _save() async {
    try {
      await ref
          .read(overrunKvProvider)
          .write(
            storageKey,
            jsonEncode({
              for (final e in state.entries) e.key: e.value.toList(),
            }),
          );
    } on Object catch (e) {
      debugPrint('One-off marks not saved: $e');
    }
  }

  Future<void> mark(String categoryId, String month) async {
    state = {
      ...state,
      categoryId: {...?state[categoryId], month},
    };
    await _save();
  }

  Future<void> unmark(String categoryId, String month) async {
    final left = {...?state[categoryId]}..remove(month);
    state = {...state, categoryId: left};
    await _save();
  }
}

final overrunMarksProvider =
    NotifierProvider<OverrunMarks, Map<String, Set<String>>>(OverrunMarks.new);

/// What is over plan this month and why. Recomputed when payments, the plan or
/// the marks change.
final overrunReportProvider = FutureProvider<OverrunReport>((ref) async {
  ref.watch(transactionsProvider);
  ref.watch(budgetPlanProvider);
  // Nothing is "over" until there is a budget to be over.
  final overview = await ref.watch(budgetProvider.future);
  if (overview.planned <= 0) return OverrunReport.empty;
  final marks = ref.watch(overrunMarksProvider);
  return ref.watch(budgetPlanServiceProvider).overruns(marked: marks);
});
