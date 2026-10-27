import 'package:flutter/material.dart';

import '../utils/dates.dart';

enum HabitType { build, quit }

/// Categories and their icons. Kept as a fixed list so the same labels can
/// later be used as features for the AI module.
const Map<String, IconData> habitCategories = {
  'Health': Icons.favorite_rounded,
  'Fitness': Icons.fitness_center_rounded,
  'Study': Icons.menu_book_rounded,
  'Mindfulness': Icons.self_improvement_rounded,
  'Sleep': Icons.bedtime_rounded,
  'Nutrition': Icons.restaurant_rounded,
  'Social': Icons.people_rounded,
  'Other': Icons.star_rounded,
};

const List<String> lapseTriggers = [
  'Stress',
  'Boredom',
  'Social situation',
  'Habit / routine',
  'Other',
];

const reflectionReasons = {
  'stress': 'Stress / anxiety',
  'fatigue': 'Tiredness / poor sleep',
  'time': 'Not enough time',
  'forgot': 'Forgot',
  'motivation': 'Low motivation',
  'illness': 'Illness / pain',
  'social': 'People around me',
  'environment': 'Environment / temptation',
  'routine': 'Change of routine',
  'boredom': 'Boredom',
  'other': 'Other',
};

/// One check-in for one day.
/// build habit: success == true  -> completed
/// quit habit:  success == true  -> held on, false -> lapse (with trigger)
class Entry {
  Entry(
      {required this.success,
      required this.timestamp,
      this.trigger,
      this.reasons = const [],
      this.note});

  final bool success;
  final DateTime timestamp;
  final String? trigger;
  final List<String> reasons;
  final String? note;

  Map<String, dynamic> toJson() => {
        'success': success,
        'timestamp': timestamp.toIso8601String(),
        'trigger': trigger,
        'reasons': reasons,
        'note': note,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        success: j['success'] as bool,
        timestamp: DateTime.parse(j['timestamp'] as String),
        trigger: j['trigger'] as String?,
        reasons: List<String>.from(j['reasons'] as List? ?? const []),
        note: j['note'] as String?,
      );
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.colorValue,
    required this.createdAt,
    Map<String, Entry>? entries,
  }) : entries = entries ?? {};

  final String id;
  final String name;
  final HabitType type;
  final String category;
  final int colorValue;
  final DateTime createdAt;

  /// Keyed by yyyy-MM-dd.
  final Map<String, Entry> entries;

  Color get color => Color(colorValue);
  IconData get icon => habitCategories[category] ?? Icons.star_rounded;
  bool get isQuit => type == HabitType.quit;

  Entry? entryOn(DateTime day) => entries[dateKey(day)];

  int get currentStreak {
    var day = dateOnly(DateTime.now());
    if (entries[dateKey(day)] == null) day = addDays(day, -1);
    var count = 0;
    while (true) {
      final e = entries[dateKey(day)];
      if (e == null || !e.success) break;
      count++;
      day = addDays(day, -1);
    }
    return count;
  }

  int get bestStreak {
    final days = entries.entries
        .where((e) => e.value.success)
        .map((e) => DateTime.parse(e.key))
        .toList()
      ..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev != null && addDays(prev, 1) == d) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// Share of successful days in the last [days] days (or since creation).
  double completionRate({int days = 30}) {
    final today = dateOnly(DateTime.now());
    final since = daysBetween(dateOnly(createdAt), today) + 1;
    final window = since < days ? since : days;
    if (window <= 0) return 0;
    var ok = 0;
    for (var i = 0; i < window; i++) {
      if (entries[dateKey(addDays(today, -i))]?.success == true) ok++;
    }
    return ok / window;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'category': category,
        'color': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'entries': entries.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        type: HabitType.values.byName(j['type'] as String),
        category: j['category'] as String,
        colorValue: j['color'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        entries: (j['entries'] as Map).map(
          (k, v) => MapEntry(
            k as String,
            Entry.fromJson(Map<String, dynamic>.from(v as Map)),
          ),
        ),
      );
}

/// Unrecorded past days are unknown outcomes, never inferred failures.
List<DateTime> unrecordedDays(Habit habit, DateTime now, {int days = 7}) {
  final today = dateOnly(now);
  return [
    for (var offset = 1; offset <= days; offset++)
      if (!addDays(today, -offset).isBefore(dateOnly(habit.createdAt)) &&
          habit.entryOn(addDays(today, -offset)) == null)
        addDays(today, -offset),
  ];
}
