import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/ai_service.dart';
import '../services/habit_store.dart';
import '../theme.dart';
import '../utils/dates.dart';

/// Personalised tips from the AI service. Shown only to group B.
class AiTipsSection extends StatefulWidget {
  const AiTipsSection({super.key, required this.store});

  final HabitStore store;

  @override
  State<AiTipsSection> createState() => _AiTipsSectionState();
}

class _TipItem {
  const _TipItem(this.habit, this.tip);
  final Habit habit;
  final AiTip? tip;
}

class _AiTipsSectionState extends State<AiTipsSection> {
  final AiService _service = AiService();
  String _signature = '';
  bool _loading = false;
  List<_TipItem> _items = const [];

  /// Changes whenever a check-in is added/removed or the day changes.
  String _currentSignature() {
    final parts = widget.store.habits.map((h) {
      final keys = h.entries.keys.toList()..sort();
      final wins = h.entries.values.where((e) => e.success).length;
      return '${h.id}:${h.entries.length}:$wins:${keys.isEmpty ? '' : keys.last}';
    });
    return '${dateKey(DateTime.now())}|${parts.join(',')}';
  }

  Future<void> _refresh(String signature) async {
    _signature = signature;
    final habits = widget.store.habits.toList();
    if (habits.isEmpty) {
      if (mounted) {
        setState(() {
          _items = const [];
          _loading = false;
        });
      }
      return;
    }
    setState(() => _loading = true);
    final results = await Future.wait(
      habits.map((h) async => _TipItem(h, await _service.recommend(h))),
    );
    if (!mounted || signature != _signature) return;
    setState(() {
      _items = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final signature = _currentSignature();
        if (signature != _signature) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                signature == _currentSignature() &&
                signature != _signature) {
              _refresh(signature);
            }
          });
        }
        return _content();
      },
    );
  }

  Widget _content() {
    if (_loading && _items.isEmpty) {
      return const _TipShell(
        child: Row(children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('Preparing your tips…')),
        ]),
      );
    }
    final ready = _items.where((i) => i.tip?.ready == true).toList();
    if (ready.isEmpty) {
      final collecting =
          _items.where((i) => i.tip?.status == 'collecting').toList();
      if (collecting.isEmpty) return const SizedBox.shrink();
      return const _TipShell(
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFF8E6CEF)),
          SizedBox(width: 12),
          Expanded(
              child: Text(
                  'Personal tips will appear after 7 days of check-ins.')),
        ]),
      );
    }
    ready.sort((a, b) => (b.tip!.risk ?? 0).compareTo(a.tip!.risk ?? 0));
    final risky = ready.where((i) => i.tip!.level != 'low').take(2).toList();
    final shown = risky.isEmpty ? [ready.first] : risky;
    return Column(children: [
      for (final item in shown)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TipCard(item: item)),
    ]);
  }
}

class _TipShell extends StatelessWidget {
  const _TipShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: child,
      );
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.item});
  final _TipItem item;

  @override
  Widget build(BuildContext context) {
    final tip = item.tip!;
    final color = switch (tip.level) {
      'high' => lapseColor,
      'medium' => const Color(0xFFD98E04),
      _ => const Color(0xFF22B8A0),
    };
    final label = switch (tip.level) {
      'high' => 'Higher risk',
      'medium' => 'Keep an eye on it',
      _ => 'On track',
    };
    return _TipShell(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tint(color, 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(item.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tint(color, 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(tip.message!, style: const TextStyle(height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}
