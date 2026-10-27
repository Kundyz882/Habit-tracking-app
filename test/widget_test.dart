import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/habit.dart';
import 'package:habit_tracker/utils/dates.dart';

Habit _habit(HabitType t) => Habit(
      id: '1',
      name: 'Water',
      type: t,
      category: 'Health',
      colorValue: 0xFF5B6CFF,
      createdAt: addDays(dateOnly(DateTime.now()), -10),
    );

void _mark(Habit h, int daysAgo, bool success) {
  final day = addDays(dateOnly(DateTime.now()), -daysAgo);
  h.entries[dateKey(day)] = Entry(success: success, timestamp: DateTime.now());
}

void main() {
  test('streak counts consecutive successful days ending today', () {
    final h = _habit(HabitType.build);
    for (var i = 0; i < 3; i++) {
      _mark(h, i, true);
    }
    expect(h.currentStreak, 3);
  });

  test('streak stays alive if today is not logged yet', () {
    final h = _habit(HabitType.build);
    _mark(h, 1, true);
    _mark(h, 2, true);
    expect(h.currentStreak, 2);
  });

  test('a lapse today resets the streak', () {
    final h = _habit(HabitType.quit);
    _mark(h, 1, true);
    _mark(h, 0, false);
    expect(h.currentStreak, 0);
  });

  test('best streak finds the longest run', () {
    final h = _habit(HabitType.build);
    for (final d in [5, 4, 3, 1]) {
      _mark(h, d, true);
    }
    expect(h.bestStreak, 3);
  });

  test('json round trip keeps entries', () {
    final h = _habit(HabitType.quit);
    _mark(h, 0, false);
    final copy = Habit.fromJson(h.toJson());
    expect(copy.type, HabitType.quit);
    expect(copy.entryOn(DateTime.now())?.success, false);
  });
}
