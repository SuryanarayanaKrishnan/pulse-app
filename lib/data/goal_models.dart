import '../core/engine/dates.dart';
import '../core/engine/goals.dart';

/// A goal as stored. Money is integer minor units (fils).
class GoalRecord {
  const GoalRecord({
    required this.id,
    required this.name,
    required this.kind,
    this.iconKey,
    required this.targetMinor,
    this.startMinor = 0,
    this.targetDate,
    this.monthlyMinor,
    this.linkedRef,
    this.paused = false,
    this.completedAt,
    required this.createdAt,
  });

  final String id, name;
  final GoalKind kind;
  final String? iconKey;
  final int targetMinor, startMinor;
  final CalDate? targetDate;
  final int? monthlyMinor;
  final String? linkedRef;
  final bool paused;
  final DateTime? completedAt;
  final DateTime createdAt;

  GoalRecord copyWith({
    String? name,
    GoalKind? kind,
    String? iconKey,
    int? targetMinor,
    int? startMinor,
    CalDate? targetDate,
    bool clearDate = false,
    int? monthlyMinor,
    bool clearMonthly = false,
    String? linkedRef,
    bool clearLink = false,
    bool? paused,
    DateTime? completedAt,
    bool clearCompleted = false,
  }) => GoalRecord(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    iconKey: iconKey ?? this.iconKey,
    targetMinor: targetMinor ?? this.targetMinor,
    startMinor: startMinor ?? this.startMinor,
    targetDate: clearDate ? null : (targetDate ?? this.targetDate),
    monthlyMinor: clearMonthly ? null : (monthlyMinor ?? this.monthlyMinor),
    linkedRef: clearLink ? null : (linkedRef ?? this.linkedRef),
    paused: paused ?? this.paused,
    completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
    createdAt: createdAt,
  );
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.date,
    this.note,
  });
  final String id, goalId;

  /// Positive adds (or pays down), negative withdraws.
  final int amountMinor;
  final CalDate date;
  final String? note;
}

/// A goal with everything worked out, for the screens.
class GoalView {
  const GoalView({
    required this.record,
    required this.input,
    required this.state,
    required this.pace,
    required this.plannedMinor,
    required this.suggestedMinor,
    required this.reservedMinor,
    this.projected,
    this.linkedName,
    this.contributions = const [],
  });
  final GoalRecord record;
  final GoalInput input;
  final GoalState state;
  final GoalPace pace;

  /// The monthly amount the goal plans (yours, else suggested).
  final int plannedMinor;

  /// remaining / months left, when there is a deadline.
  final int? suggestedMinor;

  /// What it currently holds back from safe-to-spend.
  final int reservedMinor;
  final CalDate? projected;
  final String? linkedName;

  /// Newest first.
  final List<GoalContribution> contributions;

  String get id => record.id;
  bool get isPaydown => record.kind == GoalKind.paydown;
  bool get linked => record.linkedRef != null;
}
