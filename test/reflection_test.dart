import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/utils/dates.dart';

Habit habitCreated(DateTime day) => Habit(
    id: 'habit',
    name: 'Read',
    type: HabitType.build,
    category: 'Study',
    colorValue: 0xFF5B6CFF,
    createdAt: day);

void main() {
  test('old entries load without reflection fields', () {
    final entry = Entry.fromJson({
      'success': false,
      'timestamp': '2026-10-13T20:00:00',
      'trigger': 'Stress'
    });
    expect(entry.reasons, isEmpty);
    expect(entry.note, isNull);
    expect(entry.trigger, 'Stress');
  });

  test('reflection round trip retains multiple factors and note', () {
    final habit = habitCreated(DateTime(2026, 10, 12));
    habit.entries['2026-10-13'] = Entry(
        success: false,
        timestamp: DateTime(2026, 10, 14, 9),
        reasons: ['stress', 'social'],
        note: 'Friends were smoking');
    final entry = Habit.fromJson(habit.toJson()).entries['2026-10-13']!;
    expect(entry.success, false);
    expect(entry.reasons, ['stress', 'social']);
    expect(entry.note, 'Friends were smoking');
    expect(entry.timestamp.day, 14);
  });

  test('review excludes today, future, and days before creation', () {
    final habit = habitCreated(DateTime(2026, 10, 12, 22));
    expect(unrecordedDays(habit, DateTime(2026, 10, 14, 9)),
        [DateTime(2026, 10, 13), DateTime(2026, 10, 12)]);
    expect(unrecordedDays(habit, DateTime(2026, 10, 12)), isEmpty);
  });

  test('review excludes recorded outcomes and never invents failures', () {
    final habit = habitCreated(DateTime(2026, 10, 1));
    habit.entries['2026-10-13'] =
        Entry(success: true, timestamp: DateTime(2026, 10, 14));
    habit.entries['2026-10-12'] =
        Entry(success: false, timestamp: DateTime(2026, 10, 14));
    final pending = unrecordedDays(habit, DateTime(2026, 10, 14));
    expect(pending.length, 5);
    expect(pending.first, DateTime(2026, 10, 11));
    expect(pending.last, DateTime(2026, 10, 7));
    expect(habit.entries.length, 2);
    expect(habit.entryOn(DateTime(2026, 10, 11)), isNull);
  });

  test('missed build habit resets streak and is excluded from completion', () {
    final habit = habitCreated(DateTime(2026, 10, 12));
    final now = dateOnly(DateTime.now());
    final recent = habitCreated(addDays(now, -1));
    recent.entries[dateKey(addDays(now, -1))] =
        Entry(success: true, timestamp: now);
    recent.entries[dateKey(now)] =
        Entry(success: false, timestamp: now, reasons: ['fatigue']);
    expect(recent.currentStreak, 0);
    expect(recent.completionRate(), 0.5);
    expect(habit.entries, isEmpty);
  });
}
