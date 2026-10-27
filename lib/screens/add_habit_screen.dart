import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/habit_store.dart';
import '../theme.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, required this.store});

  final HabitStore store;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final _name = TextEditingController();
  HabitType _type = HabitType.build;
  String _category = habitCategories.keys.first;
  int _color = habitColors.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.store.add(
      name: name,
      type: _type,
      category: _category,
      colorValue: _color,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (widget.store.error == null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.store.error!)));
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isQuit = _type == HabitType.quit;
    return Scaffold(
      appBar: AppBar(title: const Text('New habit')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _label('Name'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  isQuit ? 'e.g. Stop snacking at night' : 'e.g. Drink water',
            ),
          ),
          _label('Type'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<HabitType>(
              segments: const [
                ButtonSegment(
                  value: HabitType.build,
                  label: Text('Build'),
                  icon: Icon(Icons.add_task_rounded),
                ),
                ButtonSegment(
                  value: HabitType.quit,
                  label: Text('Quit'),
                  icon: Icon(Icons.block_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isQuit
                ? 'Success means avoiding it. Mark a lapse if it happens.'
                : 'Success means doing it. Mark it as done each day.',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          _label('Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in habitCategories.entries)
                ChoiceChip(
                  avatar: Icon(e.value, size: 18),
                  label: Text(e.key),
                  selected: _category == e.key,
                  onSelected: (_) => setState(() => _category = e.key),
                ),
            ],
          ),
          _label('Colour'),
          Row(
            children: [
              for (final c in habitColors)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              _color == c ? Colors.black87 : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Create habit', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
