/// The allow-list of product analytics.
///
/// Nothing leaves the phone unless it is described here. An event that is not
/// listed is dropped; a property that is not listed, or whose value is not one
/// of its allowed values, is dropped. Every property is a fixed choice, a
/// yes/no, or a coarse bucket, so free text, amounts, merchants, names and
/// contacts cannot be expressed at all.
///
/// The Privacy screen renders this same list, so what people read is what the
/// code enforces.
library;

import 'package:flutter/foundation.dart';

/// A property's allowed values.
@immutable
sealed class PropSpec {
  const PropSpec(this.description);

  /// One plain sentence for the Privacy screen.
  final String description;

  bool accepts(Object? value);

  /// Short human form of the allowed values ("one of: a, b" / "yes or no").
  String get shape;
}

/// One of a fixed set of words. Buckets are enums too (`lt_5`, `few`, ...).
class EnumProp extends PropSpec {
  const EnumProp(super.description, this.values);
  final List<String> values;

  @override
  bool accepts(Object? value) => value is String && values.contains(value);

  @override
  String get shape => 'one of: ${values.join(', ')}';
}

class BoolProp extends PropSpec {
  const BoolProp(super.description);

  @override
  bool accepts(Object? value) => value is bool;

  @override
  String get shape => 'yes or no';
}

/// One analytics event.
@immutable
class EventSpec {
  const EventSpec(
    this.name,
    this.group,
    this.what, {
    this.props = const {},
    this.oncePerInstall = false,
  });

  final String name;

  /// Heading on the Privacy screen.
  final String group;

  /// Plain sentence: when it is sent.
  final String what;
  final Map<String, PropSpec> props;

  /// Sent at most once per install (the `first_*` milestones).
  final bool oncePerInstall;
}

abstract final class AnalyticsSchema {
  // ---- Shared value sets (also used by the event factories). ----

  /// Default spending categories, plus `custom` for any category you made.
  /// (A test keeps this in step with the app's default categories.)
  static const categories = [
    'salary', 'groceries', 'dining', 'transport', 'car_loan', 'home_loan',
    'rent', 'utilities', 'telecom', 'fixed_expenses', 'education', 'health',
    'shopping', 'travel', 'entertainment', 'family', 'savings',
    'cc_payment', 'fees', 'other', 'custom', //
  ];
  static const triggers = ['manual', 'auto', 'resume', 'daily', 'setup'];
  static const durations = ['lt_5s', '5_30s', '30_120s', 'gt_120s'];
  static const sizes = ['<1MB', '1-10MB', '10-100MB', '>100MB'];
  static const backupReasons = [
    'offline', 'signed_out', 'storage_full', 'provider_unavailable',
    'keys_missing', 'wrong_passphrase', 'other', //
  ];
  static const syncReasons = [
    'offline', 'signed_out', 'too_new', 'integrity', 'keys_missing', 'other', //
  ];
  static const restoreReasons = [
    'wrong_passphrase', 'not_found', 'incomplete', 'corrupt', 'too_new', //
    'other',
  ];
  static const sources = ['cloud', 'file'];

  /// The built-in Home widgets (a test keeps this in step with `DashKind`).
  static const dashboardWidgetKinds = [
    'safe_to_spend', 'budget_progress', 'upcoming', 'card_rewards',
    'net_worth', 'spend_by_category', 'cash_flow', 'savings_rate',
    'split_balances', 'recent_captures', 'goals', //
  ];

  static const _trigger = EnumProp('What started it', triggers);
  static const _duration = EnumProp('How long it took, in coarse buckets', durations);

  static const events = <EventSpec>[
    // ---- Getting started ----
    EventSpec('onboarding_started', 'Getting started', 'You open the intro for the first time.'),
    EventSpec('onboarding_completed', 'Getting started', 'You finish the intro and start using Pulse.', oncePerInstall: true),
    EventSpec('onboarding_step_completed', 'Getting started', 'You finish a step of the intro.', props: {
      'step': EnumProp('Which step', ['intro_1', 'sign_in', 'connect_sources', 'restore_cloud', 'restore_file']),
    }),
    EventSpec('tour_started', 'Getting started', 'The short tour begins.'),
    EventSpec('tour_step_viewed', 'Getting started', 'You see a tour page.', props: {
      'step': EnumProp('Which page', ['safe_to_spend', 'right_card', 'auto_capture', 'net_worth']),
    }),
    EventSpec('tour_skipped', 'Getting started', 'You skip the tour.', props: {
      'step': EnumProp('Which page you were on', ['safe_to_spend', 'right_card', 'auto_capture', 'net_worth']),
    }),
    EventSpec('tour_completed', 'Getting started', 'You reach the end of the tour.'),
    EventSpec('signup_completed', 'Getting started', 'You sign in.'),
    EventSpec('source_connected', 'Getting started', 'You connect a way for Pulse to see payments.', props: {
      'type': EnumProp('Which kind of source', ['gmail', 'sms', 'wallet_notifications', 'apple_pay_shortcut', 'statement_upload']),
    }),

    // ---- First times (once each) ----
    EventSpec('first_capture', 'First times', 'The first payment is captured automatically.', oncePerInstall: true),
    EventSpec('first_card_added', 'First times', 'You add your first card.', oncePerInstall: true),
    EventSpec('first_budget_set', 'First times', 'You set your first budget.', oncePerInstall: true),
    EventSpec('first_split_settled', 'First times', 'Your first shared expense is settled.', oncePerInstall: true),
    EventSpec('app_returned', 'First times', 'You open Pulse again about a day, or about a week, after the first time.', props: {
      'bucket': EnumProp('Roughly how long after your first day', ['d1', 'd7']),
    }),

    // ---- Everyday use ----
    EventSpec('statement_uploaded', 'Everyday use', 'You upload a statement.'),
    EventSpec('transaction_recategorized', 'Everyday use', 'You move a payment to another category.', props: {
      'from': EnumProp('Category it was in', categories),
      'to': EnumProp('Category you chose', categories),
    }),
    EventSpec('manual_transaction_added', 'Everyday use', 'You add a payment by hand.', props: {
      'category': EnumProp('Its category', categories),
    }),
    EventSpec('recategorise_scope', 'Everyday use', 'You choose how far a category change reaches.', props: {
      'scope': EnumProp('Just that payment, future ones, or past and future', ['once', 'future', 'all']),
    }),
    EventSpec('review_swiped', 'Everyday use', 'You swipe a payment in Review.', props: {
      'direction': EnumProp('Right if it looked right, left if you fixed it', ['right', 'left']),
    }),
    EventSpec('review_inbox_zero', 'Everyday use', 'You finish everything in Review.'),
    EventSpec('dashboard_customised', 'Everyday use', 'You change a widget on your Home dashboard.', props: {
      'action': EnumProp('What you did', ['added', 'removed', 'resized', 'moved']),
      'widget': EnumProp('Which widget', dashboardWidgetKinds),
    }),
    EventSpec('goal_created', 'Everyday use', 'You set a goal.', props: {
      'type': EnumProp('Saving up, or paying something down', ['save', 'paydown']),
    }),
    EventSpec('goal_completed', 'Everyday use', 'A goal reaches its target.'),
    EventSpec('household_created', 'Everyday use', 'You start a household.'),
    EventSpec('household_member_joined', 'Everyday use', 'You join a household with an invite.'),
    EventSpec('budget_mode_changed', 'Everyday use', 'You switch the Budget between flex groups and single categories.', props: {
      'mode': EnumProp('Flex groups, or every category on its own', ['flex', 'category']),
    }),
    EventSpec('money_moved', 'Everyday use', 'You move money between two categories in a month.'),
    EventSpec('budget_created', 'Everyday use', 'You create a budget.'),
    EventSpec('card_added', 'Everyday use', 'You add a card.'),
    EventSpec('card_check_shown', 'Everyday use', 'Pulse tells you whether you used the best card.', props: {
      'result': EnumProp('Right card or not', ['right', 'wrong']),
      'estimated': BoolProp('Whether the answer was an estimate'),
    }),
    EventSpec('card_check_wrong', 'Everyday use', 'The card check says another card would have been better.', props: {
      'missed_bucket': EnumProp('Rough size of the missed reward, in AED', ['lt_5', '5_20', 'gt_20']),
    }),
    EventSpec('card_recommendation_viewed', 'Everyday use', 'You look at a card recommendation.', props: {
      'category': EnumProp('Where you saw it', ['detail', 'which_card']),
    }),
    EventSpec('permission_granted', 'Everyday use', 'You allow Android to share bank alerts with Pulse.', props: {
      'permission': EnumProp('Which permission', ['sms_receive', 'sms_read', 'notification_access']),
    }),
    EventSpec('permission_denied', 'Everyday use', 'You decline one of those permissions.', props: {
      'permission': EnumProp('Which permission', ['sms_receive', 'sms_read', 'notification_access']),
    }),

    // ---- Splits ----
    EventSpec('split_expense_added', 'Shared expenses', 'You add a shared expense.'),
    EventSpec('split_auto_settled', 'Shared expenses', 'Pulse marks a shared expense as paid back.', props: {
      'match': EnumProp('How sure the match was', ['phone', 'iban', 'exactName', 'fuzzyName']),
      'partial': BoolProp('Whether only part was paid'),
      'direction': EnumProp('Money going out or coming in', ['debit', 'credit']),
    }),
    EventSpec('split_settle_undone', 'Shared expenses', 'You undo an automatic settle.'),
    EventSpec('split_settle_asked', 'Shared expenses', 'Pulse asks you to confirm a possible settle.', props: {
      'match': EnumProp('How sure the match was', ['phone', 'iban', 'exactName', 'fuzzyName']),
    }),

    // ---- Backup and sync ----
    EventSpec('backup_enabled', 'Backup and sync', 'You turn on encrypted backup.', oncePerInstall: false, props: {
      'secret_kind': EnumProp('Recovery phrase or passphrase', ['phrase', 'passphrase']),
      'destination': EnumProp('Cloud or a file', ['cloud', 'file']),
    }),
    EventSpec('backup_completed', 'Backup and sync', 'A backup finishes.', props: {
      'trigger': _trigger,
      'size_bucket': EnumProp('Backup size, in coarse buckets', sizes),
      'duration': _duration,
    }),
    EventSpec('backup_failed', 'Backup and sync', 'A backup does not finish.', props: {
      'trigger': _trigger,
      'reason': EnumProp('A general reason', backupReasons),
    }),
    EventSpec('backup_exported', 'Backup and sync', 'You save a backup file.'),
    EventSpec('backup_passphrase_changed', 'Backup and sync', 'You change your backup passphrase.'),
    EventSpec('backup_cloud_deleted', 'Backup and sync', 'You delete your cloud backup.'),
    EventSpec('backup_disabled', 'Backup and sync', 'You turn backup off.'),
    EventSpec('sync_enabled', 'Backup and sync', 'You turn on sync between your devices.'),
    EventSpec('sync_started', 'Backup and sync', 'A sync starts.', props: {'trigger': _trigger}),
    EventSpec('sync_completed', 'Backup and sync', 'A sync finishes.', props: {
      'trigger': _trigger,
      'changes_bucket': EnumProp('How much changed', ['none', 'few', 'many']),
      'duration': _duration,
    }),
    EventSpec('sync_failed', 'Backup and sync', 'A sync does not finish.', props: {
      'trigger': _trigger,
      'reason': EnumProp('A general reason', syncReasons),
    }),
    EventSpec('restore_started', 'Backup and sync', 'You start restoring a backup.', props: {
      'source': EnumProp('Cloud or a file', sources),
    }),
    EventSpec('restore_completed', 'Backup and sync', 'A restore finishes.', props: {
      'source': EnumProp('Cloud or a file', sources),
    }),
    EventSpec('restore_failed', 'Backup and sync', 'A restore does not finish.', props: {
      'source': EnumProp('Cloud or a file', sources),
      'reason': EnumProp('A general reason', restoreReasons),
    }),
  ];

  /// Screens that may be reported (fixed paths only; pages with an id in the
  /// address, such as a group or a document, are never reported).
  static const screens = [
    '/onboarding', '/sign-in', '/connect', '/home', '/budget', '/cards',
    '/splits', '/wealth', '/activity', '/settings', '/categories',
    '/automations', '/statements', '/family', '/cards-ranked', '/legacy',
    '/goals', '/household', '/backup', '/backup/setup', '/sync', '/restore', '/tour', '/privacy', '/review', //
  ];

  static final _byName = {for (final e in events) e.name: e};

  static EventSpec? specFor(String name) => _byName[name];

  /// Only the properties the schema lists, and only with allowed values.
  /// Returns null for an event that is not in the schema.
  static Map<String, Object>? clean(String name, Map<String, Object?> props) {
    final spec = _byName[name];
    if (spec == null) return null;
    final out = <String, Object>{};
    for (final entry in props.entries) {
      final p = spec.props[entry.key];
      final v = entry.value;
      if (p != null && v != null && p.accepts(v)) out[entry.key] = v;
    }
    return out;
  }

  /// Events grouped for display, in schema order.
  static Map<String, List<EventSpec>> get grouped {
    final m = <String, List<EventSpec>>{};
    for (final e in events) {
      (m[e.group] ??= []).add(e);
    }
    return m;
  }
}
