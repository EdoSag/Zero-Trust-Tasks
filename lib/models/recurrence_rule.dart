enum RecurrenceFrequency { daily, weekly, monthly, yearly }

extension RecurrenceFrequencyExtension on RecurrenceFrequency {
  String get displayName {
    switch (this) {
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }
}

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays,
    this.endDate,
    this.occurrenceCount,
  });

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == json['frequency'],
        orElse: () => RecurrenceFrequency.daily,
      ),
      interval: (json['interval'] as int?) ?? 1,
      weekdays: (json['weekdays'] as List?)?.map((e) => e as int).toList(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      occurrenceCount: json['occurrenceCount'] as int?,
    );
  }

  /// Repeats every [interval] units of [frequency].
  final RecurrenceFrequency frequency;

  /// How many units between occurrences (default 1 = every day/week/month/year).
  final int interval;

  /// For weekly: ISO weekday numbers (1=Mon … 7=Sun). Null = same weekday as dueDate.
  final List<int>? weekdays;

  /// Recurrence stops on or before this date (inclusive).
  final DateTime? endDate;

  /// Recurrence stops after this many completions.
  final int? occurrenceCount;

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency.name,
      'interval': interval,
      if (weekdays != null) 'weekdays': weekdays,
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (occurrenceCount != null) 'occurrenceCount': occurrenceCount,
    };
  }

  RecurrenceRule copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    List<int>? weekdays,
    bool clearWeekdays = false,
    DateTime? endDate,
    bool clearEndDate = false,
    int? occurrenceCount,
    bool clearOccurrenceCount = false,
  }) {
    return RecurrenceRule(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: clearWeekdays ? null : (weekdays ?? this.weekdays),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      occurrenceCount: clearOccurrenceCount
          ? null
          : (occurrenceCount ?? this.occurrenceCount),
    );
  }
}
