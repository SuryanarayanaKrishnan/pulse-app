import 'coach_progress.dart';

/// One stop in a walkthrough: [id] names a [CoachTarget] on the screen.
class CoachStep {
  const CoachStep(this.id, this.title, this.body);
  final String id;
  final String title;
  final String body;
}

/// The walkthrough for each screen. A step whose target is not on screen
/// (an empty state, a section that has not loaded) is skipped.
const coachSteps = <CoachScreen, List<CoachStep>>{
  CoachScreen.home: [
    CoachStep(
      'safe',
      'Your number for today',
      'What is safe to spend after bills and goals. Tap it to see how it is worked out.',
    ),
    CoachStep(
      'customise',
      'Make Home yours',
      'Reorder, hide or add tiles so Home shows only what you care about.',
    ),
    CoachStep(
      'settings',
      'Settings and replays',
      'Backup, capture, privacy and every walkthrough live here.',
    ),
  ],
  CoachScreen.budget: [
    CoachStep(
      'hero',
      'Spent against plan',
      'This month at a glance. It updates as card alerts arrive.',
    ),
    CoachStep(
      'categories',
      'Categories, your way',
      'Swipe through them. Tap Edit to rename, set a budget, or add your own category.',
    ),
    CoachStep(
      'manage',
      'Build, import, automate',
      'Build a budget from a few answers, import your sheet, or set rules that file things for you.',
    ),
  ],
  CoachScreen.cards: [
    CoachStep(
      'add',
      'Add a card or account',
      'Pick from the catalogue and the card appears exactly as it looks in your wallet.',
    ),
    CoachStep(
      'which',
      'Which card should I use?',
      'Tap the bolt before you pay. We rank your cards for that purchase.',
    ),
    CoachStep(
      'switch',
      'Cards and accounts',
      'Switch between your cards and your bank accounts here.',
    ),
  ],
  CoachScreen.splits: [
    CoachStep(
      'add',
      'Split an expense',
      'Add who paid and who shares it. Settling up is one more tap.',
    ),
    CoachStep(
      'groups',
      'Your groups',
      'Open a group to see who owes whom, and settle in one go.',
    ),
  ],
  CoachScreen.wealth: [
    CoachStep(
      'hero',
      'Net worth',
      'Everything you own minus everything you owe, in one number.',
    ),
    CoachStep(
      'add',
      'Add assets and loans',
      'Gold, funds, property, savings, loans. Approximate is fine to start.',
    ),
  ],
  CoachScreen.categories: [
    CoachStep(
      'new',
      'Add your own category',
      'Tap + (or New category below) for your own name, icon and monthly budget.',
    ),
    CoachStep(
      'list',
      'Tap to set a budget',
      'Each row opens its budget and icon. Custom ones are marked.',
    ),
  ],
  CoachScreen.vault: [
    CoachStep(
      'add',
      'What your family would need',
      'Tap Add for a policy, a loan, a paper or an investment, and where it is held.',
    ),
    CoachStep(
      'nominee',
      'People you trust',
      'Name someone who can open this if something happens to you.',
    ),
  ],
  CoachScreen.capture: [
    CoachStep(
      'steps',
      'Set up capture once',
      'After this, payments arrive on their own. No typing.',
    ),
  ],
  CoachScreen.plus: [
    CoachStep(
      'perks',
      'What Plus adds',
      'Core budgeting stays free. Plus adds deeper card intel and AI summaries.',
    ),
  ],
};
