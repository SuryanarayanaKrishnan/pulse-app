import 'package:material_ui/material_ui.dart';

import '../../core/router/router.dart';

/// One place in the app a person can go to, with the words they might
/// search for it by.
class PulseFeature {
  const PulseFeature({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.group,
    this.keywords = const [],
  });
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String group;

  /// Extra search words ("repeat" finds Recurring, "joint" finds Household).
  final List<String> keywords;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = '$title $subtitle $group ${keywords.join(' ')}'.toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }
}

/// Every feature that is not one of the five tabs. Titles match the screens
/// they open, so what is searched for is what is found.
const pulseFeatures = <PulseFeature>[
  PulseFeature(
    id: 'recurring',
    title: 'Recurring',
    subtitle: 'Bills, subscriptions and repeat rules',
    icon: Icons.event_repeat_rounded,
    route: Routes.recurring,
    group: 'Money',
    keywords: ['repeat', 'rules', 'subscription', 'bills', 'monthly'],
  ),
  PulseFeature(
    id: 'household',
    title: 'Household',
    subtitle: 'Share a budget and bills with a partner',
    icon: Icons.home_work_outlined,
    route: Routes.household,
    group: 'Together',
    keywords: ['joint', 'partner', 'couple', 'switch', 'shared', 'spouse'],
  ),
  PulseFeature(
    id: 'reports',
    title: 'Reports',
    subtitle: 'Where the month went',
    icon: Icons.grid_view_rounded,
    route: Routes.reports,
    group: 'Money',
    keywords: ['treemap', 'spending', 'trend', 'insights'],
  ),
  PulseFeature(
    id: 'goals',
    title: 'Goals',
    subtitle: 'Save toward something, track how close you are',
    icon: Icons.flag_outlined,
    route: Routes.goals,
    group: 'Money',
    keywords: ['saving', 'target', 'savings'],
  ),
  PulseFeature(
    id: 'categories',
    title: 'Categories & budgets',
    subtitle: 'Add your own, set budgets and icons',
    icon: Icons.category_outlined,
    route: Routes.categories,
    group: 'Money',
    keywords: ['budget', 'limit', 'icons'],
  ),
  PulseFeature(
    id: 'automations',
    title: 'Automations',
    subtitle: 'Rules that categorise for you',
    icon: Icons.auto_mode_rounded,
    route: Routes.automations,
    group: 'Money',
    keywords: ['rules', 'categorise', 'merchant'],
  ),
  PulseFeature(
    id: 'statements',
    title: 'Monthly close',
    subtitle: 'Check statements against what was captured',
    icon: Icons.fact_check_outlined,
    route: Routes.statements,
    group: 'Money',
    keywords: ['statement', 'reconcile', 'pdf'],
  ),
  PulseFeature(
    id: 'review',
    title: 'Review',
    subtitle: 'Transactions that need a quick look',
    icon: Icons.inbox_outlined,
    route: Routes.review,
    group: 'Money',
    keywords: ['uncategorised', 'inbox'],
  ),
  PulseFeature(
    id: 'combos',
    title: 'Card combos',
    subtitle: 'Card pairs that earn more together',
    icon: Icons.layers_outlined,
    route: Routes.cardsRanked,
    group: 'Cards',
    keywords: ['best moves', 'stack', 'cashback', 'savings', 'rewards'],
  ),
  PulseFeature(
    id: 'family',
    title: 'Family',
    subtitle: 'Members, invites and what each person shares',
    icon: Icons.groups_2_outlined,
    route: Routes.family,
    group: 'Together',
    keywords: ['invite', 'members'],
  ),
  PulseFeature(
    id: 'vault',
    title: 'Family vault',
    subtitle: 'Emergency access for the people you trust',
    icon: Icons.lock_outline_rounded,
    route: Routes.legacy,
    group: 'Together',
    keywords: ['legacy', 'emergency', 'will', 'documents'],
  ),
  PulseFeature(
    id: 'backup',
    title: 'Backup',
    subtitle: 'Encrypted copy you can restore on a new phone',
    icon: Icons.cloud_upload_outlined,
    route: Routes.backup,
    group: 'Settings',
    keywords: ['restore', 'export'],
  ),
  PulseFeature(
    id: 'privacy',
    title: 'Privacy',
    subtitle: 'What is shared, and what never leaves this phone',
    icon: Icons.shield_outlined,
    route: Routes.privacy,
    group: 'Settings',
    keywords: ['analytics', 'data'],
  ),
  PulseFeature(
    id: 'connections',
    title: 'Connections',
    subtitle: 'Gmail, bank texts, Apple Pay and email receipts, on or off',
    icon: Icons.power_outlined,
    route: Routes.connections,
    group: 'Settings',
    keywords: [
      'gmail',
      'email',
      'statements',
      'sms',
      'texts',
      'apple pay',
      'shortcut',
      'receipts',
      'connect',
      'turn on',
      'turn off',
      'capture',
    ],
  ),
  PulseFeature(
    id: 'salary',
    title: 'Salary',
    subtitle: 'Set your pay day and amount by hand',
    icon: Icons.payments_outlined,
    route: '/settings/money',
    group: 'Settings',
    keywords: ['pay', 'income', 'payday', 'paycheck'],
  ),
  PulseFeature(
    id: 'look',
    title: 'Theme and colour',
    subtitle: 'Light, dark, Sage or Stone, currency, notifications',
    icon: Icons.palette_outlined,
    route: '/settings/look',
    group: 'Settings',
    keywords: ['appearance', 'dark', 'light', 'sage', 'stone', 'currency'],
  ),
  PulseFeature(
    id: 'help',
    title: 'Help and about',
    subtitle: 'Replay the tour, report a bug, version',
    icon: Icons.help_outline_rounded,
    route: '/settings/help',
    group: 'Settings',
    keywords: ['tour', 'tips', 'bug', 'feedback', 'shake', 'walkthrough'],
  ),
  PulseFeature(
    id: 'settings',
    title: 'Settings',
    subtitle: 'Connections, money, family, backup and more',
    icon: Icons.settings_outlined,
    route: Routes.settings,
    group: 'Settings',
    keywords: ['preferences'],
  ),
];

PulseFeature featureById(String id) =>
    pulseFeatures.firstWhere((f) => f.id == id);
