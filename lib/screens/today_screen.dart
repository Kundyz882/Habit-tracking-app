import 'dart:async';

import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme.dart';
import '../utils/dates.dart';
import 'add_habit_screen.dart';
import 'habit_detail_screen.dart';
import 'habit_setup_screen.dart';
import 'reflection_sheet.dart';
import 'ai_coach_screen.dart';
import '../widgets/ai_tips_section.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  HabitStore get store => widget.store;
  Timer? _timer;
  String _day = dateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshDay());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.habits.isEmpty) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => HabitSetupScreen(store: store)));
      }
    });
  }

  void _refreshDay() {
    final day = dateKey(DateTime.now());
    if (mounted && day != _day) setState(() => _day = day);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddHabitScreen(store: store)),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New habit'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final habits = store.habits;
            final today = dateOnly(DateTime.now());
            final done =
                habits.where((h) => h.entryOn(today)?.success == true).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 110),
              children: [
                Text(
                  greeting(),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.1,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 15,
                        color:
                            tint(Theme.of(context).colorScheme.primary, 0.8)),
                    const SizedBox(width: 8),
                    Text(
                      formatLongDate(today),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tint(const Color(0xFF1B2559), 0.58),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (habits.isNotEmpty)
                  _SummaryCard(done: done, total: habits.length),
                const SizedBox(height: 16),
                if (habits.isNotEmpty) ...[
                  AiTipsSection(store: store),
                  const SizedBox(height: 4),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_rounded),
                      title: const Text('Talk to your AI habit coach'),
                      subtitle: const Text('Get a practical suggestion based on your check-ins'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AiCoachScreen(store: store),
                      )),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (habits.any((h) => unrecordedDays(h, today).isNotEmpty))
                  Card(
                      child: ListTile(
                    leading: const Icon(Icons.rate_review_outlined),
                    title: const Text('How did the past days go?'),
                    subtitle: const Text(
                        'Review unrecorded days from the last week. You can do this later.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => _ReviewScreen(store: store))),
                  )),
                if (habits.isNotEmpty)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Your daily routine · check in without choosing again',
                          style: TextStyle(color: Colors.black54))),
                if (habits.isEmpty)
                  const _EmptyState()
                else
                  for (final h in habits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _HabitTile(store: store, habit: h),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [primary, const Color(0xFF8E6CEF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's progress",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '$done of $total habits',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.eco_rounded,
              size: 64,
              color: tint(Theme.of(context).colorScheme.primary, 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No habits yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "New habit" to start your first one.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.store, required this.habit});

  final HabitStore store;
  final Habit habit;

  Future<void> _lapse(BuildContext context) async {
    await showReflection(context, store, habit, DateTime.now());
  }

  Future<bool> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text('"${habit.name}" and its history will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    await store.remove(habit.id);
    if (context.mounted && store.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(store.error!)));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final entry = habit.entryOn(today);
    final streak = habit.currentStreak;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Dismissible(
        key: ValueKey('habit-${habit.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _delete(context),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: lapseColor,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
              SizedBox(height: 4),
              Text('Delete',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        child: Container(
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
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: tint(habit.color, 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(habit.icon, color: habit.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TypeChip(isQuit: habit.isQuit),
                              const SizedBox(width: 8),
                              const Icon(Icons.local_fire_department_rounded,
                                  size: 16, color: Color(0xFFFF8A5B)),
                              const SizedBox(width: 2),
                              Text(
                                '$streak day${streak == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Action(
                      habit: habit,
                      entry: entry,
                      onToggle: () => store.toggleToday(habit),
                      onHeld: () => store.setEntry(habit, today, true),
                      onLapse: () => _lapse(context),
                      onUndo: () => store.clearEntry(habit, today),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.isQuit});

  final bool isQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isQuit ? 'Quit' : 'Build',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.habit,
    required this.entry,
    required this.onToggle,
    required this.onHeld,
    required this.onLapse,
    required this.onUndo,
  });

  final Habit habit;
  final Entry? entry;
  final VoidCallback onToggle;
  final VoidCallback onHeld;
  final VoidCallback onLapse;
  final VoidCallback onUndo;

  Widget _circle({
    required bool filled,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: filled ? Colors.white : color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!habit.isQuit) {
      final done = entry?.success == true;
      if (entry != null) {
        return _circle(
            filled: true,
            color: done ? habit.color : lapseColor,
            icon: done ? Icons.check_rounded : Icons.close_rounded,
            onTap: onUndo,
            tooltip: 'Undo');
      }
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _circle(
            filled: false,
            color: lapseColor,
            icon: Icons.close_rounded,
            onTap: onLapse,
            tooltip: 'Missed today'),
        const SizedBox(width: 8),
        _circle(
            filled: false,
            color: habit.color,
            icon: Icons.check_rounded,
            onTap: onToggle,
            tooltip: 'Mark as done'),
      ]);
    }

    // Quit habit
    if (entry == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circle(
            filled: false,
            color: lapseColor,
            icon: Icons.close_rounded,
            onTap: onLapse,
            tooltip: 'I slipped',
          ),
          const SizedBox(width: 8),
          _circle(
            filled: false,
            color: habit.color,
            icon: Icons.check_rounded,
            onTap: onHeld,
            tooltip: 'I held on',
          ),
        ],
      );
    }
    return entry!.success
        ? _circle(
            filled: true,
            color: habit.color,
            icon: Icons.check_rounded,
            onTap: onUndo,
            tooltip: 'Undo',
          )
        : _circle(
            filled: true,
            color: lapseColor,
            icon: Icons.close_rounded,
            onTap: onUndo,
            tooltip: 'Undo',
          );
  }
}

class _ReviewScreen extends StatelessWidget {
  const _ReviewScreen({required this.store});
  final HabitStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Review past days')),
        body: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final pending = [
                for (final habit in store.habits)
                  for (final day in unrecordedDays(habit, DateTime.now()))
                    (habit, day),
              ]..sort((a, b) => b.$2.compareTo(a.$2));
              return ListView(padding: const EdgeInsets.all(20), children: [
                const Text(
                    'No record does not mean failure. Tell us what happened, or come back later.'),
                const SizedBox(height: 12),
                if (pending.isEmpty) const Text('All caught up!'),
                for (final item in pending)
                  Card(
                      child: ListTile(
                          title: Text(item.$1.name),
                          subtitle: Text(formatLongDate(item.$2)),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => showReflection(
                              context, store, item.$1, item.$2,
                              allowSuccess: true))),
              ]);
            }),
      );
}
