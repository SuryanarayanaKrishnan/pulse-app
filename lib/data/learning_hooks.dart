import '../core/learning/learning_controller.dart';
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
