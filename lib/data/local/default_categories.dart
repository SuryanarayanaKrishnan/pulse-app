/// The default category set: same slugs, names, kinds and order as the
/// backend's migration 0003. The slug is the id.
class DefaultCategory {
  const DefaultCategory(this.slug, this.name, this.kind, this.isFixed, this.icon, this.color, this.order);
  final String slug, name, kind, icon, color;
  final bool isFixed;
  final int order;
}

const defaultCategories = <DefaultCategory>[
  DefaultCategory('salary', 'Salary', 'income', true, 'briefcase', 'emerald', 10),
  DefaultCategory('other_income', 'Other Income', 'income', false, 'plus-circle', 'lime', 20),
  DefaultCategory('groceries', 'Groceries', 'expense', false, 'shopping-basket', 'green', 30),
  DefaultCategory('dining', 'Dining & Delivery', 'expense', false, 'utensils', 'orange', 40),
  DefaultCategory('transport', 'Transport & Fuel', 'expense', false, 'car', 'sky', 50),
  DefaultCategory('car_loan', 'Car Loan', 'expense', true, 'car-key', 'blue', 60),
  DefaultCategory('home_loan', 'Home Loan / Mortgage', 'expense', true, 'landmark', 'slate', 70),
  DefaultCategory('rent', 'Rent & Housing', 'expense', true, 'home', 'indigo', 80),
  DefaultCategory('utilities', 'Utilities', 'expense', false, 'zap', 'yellow', 90),
  DefaultCategory('telecom', 'Telecom & Internet', 'expense', true, 'wifi', 'cyan', 100),
  DefaultCategory('fixed_expenses', 'Fixed Expenses', 'expense', true, 'repeat', 'violet', 110),
  DefaultCategory('education', 'Education Fees', 'expense', true, 'graduation-cap', 'blue', 120),
  DefaultCategory('health', 'Health', 'expense', false, 'heart-pulse', 'rose', 130),
  DefaultCategory('shopping', 'Shopping', 'expense', false, 'shopping-bag', 'pink', 140),
  DefaultCategory('travel', 'Travel', 'expense', false, 'plane', 'teal', 150),
  DefaultCategory('entertainment', 'Entertainment', 'expense', false, 'film', 'fuchsia', 160),
  DefaultCategory('family', 'Family & Remittances', 'expense', false, 'users', 'amber', 170),
  DefaultCategory('savings', 'Savings & Investments', 'expense', false, 'piggy-bank', 'emerald', 180),
  DefaultCategory('cc_payment', 'Credit Card Payments', 'transfer', false, 'credit-card', 'gray', 190),
  DefaultCategory('transfer', 'Transfer', 'transfer', false, 'arrows-left-right', 'gray', 200),
  DefaultCategory('fees', 'Fees & Charges', 'expense', false, 'receipt', 'red', 210),
  DefaultCategory('other', 'Other', 'expense', false, 'ellipsis', 'stone', 220),
];
