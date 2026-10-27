import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'reflection_sheet.dart';

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({
    super.key,
    required this.store,
    required this.habitId,
  });

  final HabitStore store;
  final String habitId;

  Future<void> _confirmDelete(BuildContext context, Habit habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('"${habit.name}" and its history will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await store.remove(habit.id);
      if (!context.mounted) return;
      if (store.error == null) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(store.error!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final habit = store.byId(habitId);
        if (habit == null) return const Scaffold();
        return Scaffold(
          appBar: AppBar(
            title: Text(habit.name),
            actions: [
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirmDelete(context, habit),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Row(
                children: [
                  _Stat(
                    label: 'Current streak',
                    value: '${habit.currentStreak}',
                    color: habit.color,
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    label: 'Best streak',
                    value: '${habit.bestStreak}',
                    color: habit.color,
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    label: '30-day rate',
                    value: '${(habit.completionRate() * 100).round()}%',
                    color: habit.color,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Heatmap(habit: habit, store: store),
              const SizedBox(height: 20),
              _RecentList(habit: habit, store: store),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.habit, required this.store});

  final HabitStore store;

  final Habit habit;

  static const _weeks = 5;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final monday = addDays(today, -(today.weekday - 1));
    final start = addDays(monday, -7 * (_weeks - 1));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 5 weeks · tap a day to add or edit a check-in',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Light days have no entry yet. Future days are hidden.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final l in weekdayLetters)
                Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < _weeks; w++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                      child: _cell(context, addDays(start, w * 7 + d), today)),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legend(habit.color, habit.isQuit ? 'Held on' : 'Done'),
              _legend(lapseColor, habit.isQuit ? 'Slip' : 'Missed'),
              _legend(const Color(0xFFE9ECF5), 'No check-in'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime day, DateTime today) {
    if (day.isAfter(today) || day.isBefore(dateOnly(habit.createdAt))) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox());
    }
    final isToday = day == today;
    final entry = habit.entryOn(day);
    final color = entry == null
        ? const Color(0xFFE9ECF5)
        : entry.success
            ? habit.color
            : lapseColor;
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
            onTap: () =>
                showReflection(context, store, habit, day, allowSuccess: true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: const Color(0xFF1B2559), width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color:
                        entry == null ? const Color(0xFF7C839D) : Colors.white,
                  ),
                ),
              ),
            )),
      ),
    );
  }

  Widget _legend(Color c, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.habit, required this.store});

  final HabitStore store;

  final Habit habit;

  String _status(Entry e) {
    final status = e.success
        ? (habit.isQuit ? 'Held on' : 'Completed')
        : (habit.isQuit ? 'Slipped' : 'Missed');
    final reasons = e.reasons.map((r) => reflectionReasons[r] ?? r).join(', ');
    return [
      status,
      if (reasons.isNotEmpty) reasons,
      if (e.trigger != null) e.trigger!,
      if (e.note != null) e.note!
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final keys = habit.entries.keys.toList()..sort((a, b) => b.compareTo(a));
    final shown = keys.take(10).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No check-ins yet.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            for (final k in shown)
              Builder(builder: (context) {
                final e = habit.entries[k]!;
                final day = DateTime.parse(k);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        e.success
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: e.success ? habit.color : lapseColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatLongDate(day),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _status(e),
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatTime(e.timestamp),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45),
                      ),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }
}
