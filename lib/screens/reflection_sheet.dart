import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../utils/dates.dart';

class ReflectionResult {
  const ReflectionResult({
    required this.success,
    required this.reasons,
    required this.note,
  });

  final bool success;
  final List<String> reasons;
  final String? note;
}

Future<ReflectionResult?> showReflection(
    BuildContext context, HabitStore store, Habit habit, DateTime day,
    {bool allowSuccess = false}) async {
  return showModalBottomSheet<ReflectionResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReflectionSheet(
      store: store,
      habit: habit,
      day: day,
      allowSuccess: allowSuccess,
    ),
  );
}

class _ReflectionSheet extends StatefulWidget {
  const _ReflectionSheet(
      {required this.store,
      required this.habit,
      required this.day,
      required this.allowSuccess});
  final HabitStore store;
  final Habit habit;
  final DateTime day;
  final bool allowSuccess;

  @override
  State<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends State<_ReflectionSheet> {
  final _note = TextEditingController();
  final Set<String> _reasons = {};
  bool _success = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.habit.entryOn(widget.day);
    _reasons.addAll(entry?.reasons ?? []);
    _note.text = entry?.note ?? '';
    _success = entry?.success ?? false;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.store.setEntry(
      widget.habit,
      widget.day,
      _success,
      reasons: _success ? [] : _reasons.toList(),
      note: _success || _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    if (widget.store.error == null) {
      Navigator.of(context).pop(ReflectionResult(
        success: _success,
        reasons: _success ? const [] : _reasons.toList(),
        note: _success || _note.text.trim().isEmpty ? null : _note.text.trim(),
      ));
    } else {
      setState(() {
        _saving = false;
        _error = widget.store.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
          24, 0, 24, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habit.name, style: Theme.of(context).textTheme.titleLarge),
          Text(formatLongDate(widget.day)),
          const SizedBox(height: 16),
          if (widget.allowSuccess) ...[
            const Text('How did this day go?'),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                    value: true,
                    label: Text(habit.isQuit ? 'Held on' : 'Done')),
                ButtonSegment(
                    value: false,
                    label: Text(habit.isQuit ? 'Slipped' : 'Missed')),
              ],
              selected: {_success},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _success = value.first),
            ),
            const SizedBox(height: 16),
          ],
          if (!_success) ...[
            Text(
                habit.isQuit
                    ? 'What contributed to the slip?'
                    : 'What made it difficult?',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'No judgement. Choose any factors, or save without a reason.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final reason in reflectionReasons.entries)
                FilterChip(
                    label: Text(reason.value),
                    selected: _reasons.contains(reason.key),
                    onSelected: _saving
                        ? null
                        : (selected) => setState(() {
                              if (selected) {
                                _reasons.add(reason.key);
                              } else {
                                _reasons.remove(reason.key);
                              }
                            })),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: _note,
                enabled: !_saving,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'What happened? (optional)',
                    hintText:
                        'For example: a busy day at work, friends were smoking...')),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save check-in'),
              )),
        ],
      )),
    ));
  }
}
