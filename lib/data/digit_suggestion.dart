/// "Is ••1234 your SIB card?": alerts that carry card digits Pulse cannot place,
/// while exactly the kind of card they might belong to has no digits yet.
class DigitSuggestion {
  const DigitSuggestion({
    required this.last4,
    required this.institution,
    required this.candidates,
    required this.waiting,
  });

  final String last4;

  /// Bank name as the alert gave it (display only).
  final String institution;

  /// Accounts at that bank with no digits yet: (account id, label).
  final List<({String id, String label})> candidates;

  /// Alerts waiting on this answer.
  final int waiting;

  String get question => candidates.length == 1
      ? 'Is ••$last4 your ${candidates.single.label}?'
      : 'Is ••$last4 one of your $institution cards?';
}
