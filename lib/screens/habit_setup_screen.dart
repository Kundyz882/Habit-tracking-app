import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme.dart';
import 'add_habit_screen.dart';

const _suggestions = [
  ('Drink water', HabitType.build, 'Health'),
  ('Walk every day', HabitType.build, 'Fitness'),
  ('Read a book', HabitType.build, 'Study'),
  ('Go to bed on time', HabitType.build, 'Sleep'),
  ('Practice mindfulness', HabitType.build, 'Mindfulness'),
  ('Stop smoking', HabitType.quit, 'Health'),
  ('Avoid late-night snacking', HabitType.quit, 'Nutrition'),
  ('Reduce social media', HabitType.quit, 'Other'),
];

class HabitSetupScreen extends StatefulWidget {
  const HabitSetupScreen({super.key, required this.store});
  final HabitStore store;

  @override
  State<HabitSetupScreen> createState() => _HabitSetupScreenState();
}

class _HabitSetupScreenState extends State<HabitSetupScreen> {
  final Set<int> _selected = {};
  bool _saving = false;

  Future<void> _start() async {
    setState(() => _saving = true);
    await widget.store.addRoutine([
      for (final index in _selected)
        (
          name: _suggestions[index].$1,
          type: _suggestions[index].$2,
          category: _suggestions[index].$3,
          colorValue: habitColors[index % habitColors.length]
        ),
    ]);
    if (!mounted) return;
    if (widget.store.error != null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.store.error!)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Your daily habits'),
            automaticallyImplyLeading: false),
        body: SafeArea(
            child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Choose what you want to change',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'Choose once. These habits stay in your account and appear every day. You only need to check in.'),
            const SizedBox(height: 20),
            for (final type in HabitType.values) ...[
              Text(
                  type == HabitType.build
                      ? 'Habits to build'
                      : 'Habits to quit',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              for (var i = 0; i < _suggestions.length; i++)
                if (_suggestions[i].$2 == type)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_suggestions[i].$1),
                      value: _selected.contains(i),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                if (value == true) {
                                  _selected.add(i);
                                } else {
                                  _selected.remove(i);
                                }
                              })),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add my own habit'),
                onPressed: _saving
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                AddHabitScreen(store: widget.store)));
                        if (mounted) setState(() {});
                      }),
            ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) => Column(children: [
                      if (widget.store.habits.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                                'Already saved: ${widget.store.habits.map((h) => h.name).join(', ')}')),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ||
                                    (_selected.isEmpty &&
                                        widget.store.habits.isEmpty)
                                ? null
                                : _start,
                            child: Text(_saving
                                ? 'Saving...'
                                : 'Start my daily routine'),
                          )),
                    ])),
          ],
        )),
      );
}
