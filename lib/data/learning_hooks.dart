import 'dart:async';

import '../core/engine/superapps.dart';
import '../core/learning/learning_controller.dart';
import '../core/learning/merchant_memory.dart';
import 'models.dart';

/// The person confirmed [category] for [tx] (recategorise or a Review swipe).
/// Only the payment id (a local de-duplication marker, never sent), the
/// merchant name and the category key are read; the amount, date and account
/// are not looked at. Learning must never get in the way, so errors are
/// swallowed.
Future<void> recordConfirmedCategory(
  LearningController learning,
  Transaction tx,
  SpendCategory category,
) async {
  try {
    await learning.recordConfirmation(
      paymentId: tx.id,
      merchant: tx.merchant,
      categoryId: category.id,
    );
  } on Object {
    // ignore
  }
}

/// Remembers a category choice for this merchant on this phone, so the next
/// payment from it (or a near-identical spelling) starts in the right place.
/// [fix] is a deliberate change, which counts more than a "yes, that is
/// right". "Other" and income are never learned: they say nothing about the
/// merchant. Errors are swallowed; learning must never get in the way.
Future<void> rememberCategoryChoice(
  MerchantMemory memory,
  Transaction tx,
  SpendCategory category, {
  bool fix = false,
}) async {
  try {
    if (category.id == SpendCategory.other.id || tx.isIncome) return;
    final sa = superAppFor(tx.merchant);
    if (sa != null) {
      // A silently applied category the person then changed.
      if (fix && tx.learned && tx.category.id != category.id) {
        unawaited(memory.bump(autoCorrected: 1));
      }
      // Super-apps sell many things: learn by size and time, not by name.
      await memory.confirmHabit(
        sa.key,
        (tx.amount * 100).round(),
        tx.date,
        category.id,
        weight: fix ? fixWeight : confirmWeight,
      );
      return;
    }
    await memory.confirm(
      tx.merchant,
      category.id,
      weight: fix ? fixWeight : confirmWeight,
    );
  } on Object {
    // ignore
  }
}
