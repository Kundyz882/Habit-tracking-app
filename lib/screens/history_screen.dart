import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'habit_detail_screen.dart';

/// Colour of a day cell/dot for a habit.
Color dayColor(Habit habit, DateTime day) {
  final e = habit.entryOn(day);
  if (e == null) return const Color(0xFFE6E8F0);
  return e.success ? habit.color : lapseColor;
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final habits = store.habits;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'History',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Last 7 days',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (habits.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      'Your history will appear here.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                )
              else
                for (final h in habits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _HistoryCard(store: store, habit: h),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.store, required this.habit});

  final HabitStore store;
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final rate = (habit.completionRate() * 100).round();

    return Container(
      decoration: cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  HabitDetailScreen(store: store, habitId: habit.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(habit.icon, color: habit.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: habit.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              weekdayLetters[d.weekday - 1],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: dayColor(habit, d),
                                shape: BoxShape.circle,
                              ),
                              child: habit.entryOn(d) == null
                                  ? null
                                  : Icon(
                                      habit.entryOn(d)!.success
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
