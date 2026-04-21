/// Model for deal scheduling
class DealSchedule {
  final ScheduleType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final DayOfWeek? dayOfWeek;
  final bool isRecurring;

  DealSchedule({
    required this.type,
    this.startDate,
    this.endDate,
    this.dayOfWeek,
    this.isRecurring = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'day_of_week': dayOfWeek?.index,
      'is_recurring': isRecurring,
    };
  }

  factory DealSchedule.fromJson(Map<String, dynamic> json) {
    return DealSchedule(
      type: ScheduleType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ScheduleType.none,
      ),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'])
          : null,
      dayOfWeek: json['day_of_week'] != null
          ? DayOfWeek.values[json['day_of_week']]
          : null,
      isRecurring: json['is_recurring'] ?? false,
    );
  }

  bool get isScheduled => type != ScheduleType.none;

  /// Check if deal is available based on schedule
  bool isAvailableNow() {
    final now = DateTime.now();

    switch (type) {
      case ScheduleType.none:
        return true;

      case ScheduleType.dateRange:
        if (startDate == null || endDate == null) return true;
        final isAfterStart =
            now.isAfter(startDate!) || now.isAtSameMomentAs(startDate!);
        final isBeforeEnd =
            now.isBefore(endDate!) || now.isAtSameMomentAs(endDate!);
        return isAfterStart && isBeforeEnd;

      case ScheduleType.dayOfWeek:
        if (dayOfWeek == null) return true;
        return now.weekday - 1 == dayOfWeek!.index;
    }
  }
}

enum ScheduleType { none, dateRange, dayOfWeek }

enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
}

extension DayOfWeekExtension on DayOfWeek {
  String get displayName {
    switch (this) {
      case DayOfWeek.monday:
        return 'Monday';
      case DayOfWeek.tuesday:
        return 'Tuesday';
      case DayOfWeek.wednesday:
        return 'Wednesday';
      case DayOfWeek.thursday:
        return 'Thursday';
      case DayOfWeek.friday:
        return 'Friday';
      case DayOfWeek.saturday:
        return 'Saturday';
      case DayOfWeek.sunday:
        return 'Sunday';
    }
  }
}
